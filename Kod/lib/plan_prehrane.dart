import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dbqueries.dart';

class PlanPrehranePage extends StatefulWidget {
  const PlanPrehranePage({super.key});

  @override
  State<PlanPrehranePage> createState() => _PlanPrehranePageState();
}

class _PlanPrehranePageState extends State<PlanPrehranePage> {
  bool _loading = true;
  int? _idKorisnik;

  List<Map<String, dynamic>> _vrsteObroka = [];
  List<Map<String, dynamic>> _planRows = [];
  List<Map<String, dynamic>> _recepti = [];

  int _selectedDayIndex = 0; // 0 danas, 1 sutra, 2 preksutra

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<DateTime> get _days => [
    _today,
    _today.add(const Duration(days: 1)),
    _today.add(const Duration(days: 2)),
  ];

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  bool _isDoneValue(dynamic raw) {
    if (raw is bool) return raw;
    final s = (raw ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true';
  }

  Future<void> _openAddMealDialogForSelectedDay() async {
    if (_idKorisnik == null) return;
    final selectedDay = _days[_selectedDayIndex];

    int? selectedTipId;
    int? selectedReceptId;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Dodaj obrok (${_dayLabel(_selectedDayIndex).toLowerCase()})'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedTipId,
                      decoration: const InputDecoration(
                        labelText: 'Tip obroka',
                        border: OutlineInputBorder(),
                      ),
                      items: _vrsteObroka.map((tip) {
                        final id = int.tryParse(tip['idVrstaObroka']?.toString() ?? '') ?? 0;
                        final ime = (tip['ime'] ?? '').toString();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(ime.isEmpty ? 'Obrok' : ime),
                        );
                      }).toList(),
                      onChanged: (v) => setLocal(() => selectedTipId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedReceptId,
                      decoration: const InputDecoration(
                        labelText: 'Recept',
                        border: OutlineInputBorder(),
                      ),
                      items: _recepti.map((r) {
                        final id = int.tryParse(r['idRecept']?.toString() ?? '') ?? 0;
                        final naziv = (r['naziv'] ?? '').toString();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(naziv.isEmpty ? 'Bez naziva' : naziv),
                        );
                      }).toList(),
                      onChanged: (v) => setLocal(() => selectedReceptId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTipId == null || selectedReceptId == null) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || selectedTipId == null || selectedReceptId == null) return;

    try {
      await DbQueries.upsertPlanObroka(
        idKorisnik: _idKorisnik!,
        idRecept: selectedReceptId!,
        datumObrok: selectedDay,
        tipObrokaId: selectedTipId!,
      );
      await _refreshPlanOnly();
    } catch (e) {
      _showError('Neuspješno dodavanje obroka: $e');
    }
  }


  Future<void> _initLoad() async {
    try {
      setState(() => _loading = true);

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email') ??
          prefs.getString('loggedInEmail') ??
          prefs.getString('userEmail');

      if (email == null || email.trim().isEmpty) {
        throw Exception('Nije pronaden prijavljeni korisnik (email).');
      }

      final idKorisnik = await DbQueries.getUserIdByMail(email);
      if (idKorisnik == null) {
        throw Exception('Nije pronaden id prijavljenog korisnika.');
      }

      final vrste = await DbQueries.getVrsteObroka();
      final plan = await DbQueries.getPlanObrokaZaPeriod(
        idKorisnik: idKorisnik,
        od: _days.first,
        doDatuma: _days.last,
      );
      final recepti = await DbQueries.getReceptiList();

      if (!mounted) return;
      setState(() {
        _idKorisnik = idKorisnik;
        _vrsteObroka = vrste;
        _planRows = plan;
        _recepti = recepti;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Greška pri učitavanju plana: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';

  String _dayLabel(int index) {
    if (index == 0) return 'Danas';
    if (index == 1) return 'Sutra';
    return 'Prekosutra';
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, dynamic>? _findPlanItem({
    required DateTime day,
    required int tipObrokaId,
  }) {
    for (final row in _planRows) {
      final raw = row['datumObrok'];
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      if (parsed == null) continue;

      final tip = int.tryParse(row['tipObroka']?.toString() ?? '');
      if (tip == null) continue;

      if (_sameDate(parsed, day) && tip == tipObrokaId) {
        return row;
      }
    }
    return null;
  }

  Future<void> _confirmAndDeleteMeal(Map<String, dynamic> planItem) async {
    if (_idKorisnik == null) return;

    final idPlanObroka = int.tryParse(planItem['idPlanObroka']?.toString() ?? '');
    if (idPlanObroka == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obriši recept iz obroka'),
        content: const Text(
          'Jeste li sigurni da želite obrisati recept iz ovog obroka?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DbQueries.deletePlanObrokaById(
        idPlanObroka: idPlanObroka,
        idKorisnik: _idKorisnik!,
      );
      await _refreshPlanOnly();
    } catch (e) {
      _showError('Neuspješno brisanje obroka: $e');
    }
  }


  Future<void> _pickAndAssignRecipe({
    required DateTime day,
    required int tipObrokaId,
  }) async {
    final selectedId = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int? chosen;
        return AlertDialog(
          title: const Text('Odaberi recept'),
          content: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return DropdownButtonFormField<int>(
                  value: chosen,
                  decoration: const InputDecoration(
                    labelText: 'Recept',
                    border: OutlineInputBorder(),
                  ),
                  items: _recepti.map((r) {
                    final id = int.tryParse(r['idRecept']?.toString() ?? '') ?? 0;
                    final naziv = (r['naziv'] ?? '').toString();
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(naziv.isEmpty ? 'Bez naziva' : naziv),
                    );
                  }).toList(),
                  onChanged: (v) => setLocal(() => chosen = v),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, chosen),
              child: const Text('Spremi'),
            ),
          ],
        );
      },
    );

    if (selectedId == null || selectedId <= 0 || _idKorisnik == null) return;

    try {
      await DbQueries.upsertPlanObroka(
        idKorisnik: _idKorisnik!,
        idRecept: selectedId,
        datumObrok: day,
        tipObrokaId: tipObrokaId,
      );
      await _refreshPlanOnly();
    } catch (e) {
      _showError('Neuspješno spremanje obroka: $e');
    }
  }

  Future<void> _refreshPlanOnly() async {
    if (_idKorisnik == null) return;
    final plan = await DbQueries.getPlanObrokaZaPeriod(
      idKorisnik: _idKorisnik!,
      od: _days.first,
      doDatuma: _days.last,
    );
    if (!mounted) return;
    setState(() => _planRows = plan);
  }

  Future<void> _openDetaljiRecepta(int idRecept) async {
    try {
      final detalji = await DbQueries.getReceptDetaljiById(idRecept);
      final sastojci = await DbQueries.getReceptSastojciByReceptId(idRecept);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(detalji?['naziv']?.toString() ?? 'Recept'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Opis: ${detalji?['opis'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Vrijeme pripreme: ${detalji?['vrijemePripreme'] ?? '-'} min'),
                    const SizedBox(height: 12),
                    const Text('Sastojci:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...sastojci.map((s) {
                      final ime = (s['sastojakIme'] ?? '').toString();
                      final kol = (s['potrebnaKolicina'] ?? '').toString();
                      final vel = (s['oznakaVelicine'] ?? '').toString();
                      return Text('- $ime: $kol ${vel.isEmpty ? '' : vel}');
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showError('Ne mogu otvoriti detalje recepta: $e');
    }
  }

  Future<void> _confirmAndMarkDone(Map<String, dynamic> planItem) async {
    if (_isDoneValue(planItem['izvrsen'])) {
      _showError('Ovaj obrok je već označen kao napravljen.');
      return;
    }

    final idPlanObroka = int.tryParse(planItem['idPlanObroka']?.toString() ?? '');
    if (idPlanObroka == null || _idKorisnik == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Označi obrok kao napravljen'),
        content: const Text(
          'Potvrdom će se sastojci recepta odmah skinuti iz zaliha. Nastaviti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DbQueries.oznaciObrokKaoNapravljen(
        idPlanObroka: idPlanObroka,
        idKorisnik: _idKorisnik!,
      );
      await _refreshPlanOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obrok je označen i zalihe su ažurirane.')),
      );
    } catch (e) {
      _showError('Neuspjelo označavanje obroka: $e');
    }
  }


  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Greška'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _days[_selectedDayIndex];

    return Stack(
      children: [
        Opacity(
          opacity: 0.4,
          child: Image.asset(
            'assets/slike/logo.png',
            fit: BoxFit.fitWidth,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Text(
              'Plan prehrane',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade900,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 56),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _initLoad,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                Text(
                  'Plan za sljedeća 3 dana',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: List.generate(_days.length, (i) {
                    return ChoiceChip(
                      label: Text('${_dayLabel(i)} (${_formatDate(_days[i])})'),
                      selected: _selectedDayIndex == i,
                      onSelected: (_) => setState(() => _selectedDayIndex = i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                ..._vrsteObroka.map((tip) {
                  final tipId =
                      int.tryParse(tip['idVrstaObroka']?.toString() ?? '') ?? 0;
                  final tipIme = (tip['ime'] ?? '').toString();
                  final item = _findPlanItem(day: day, tipObrokaId: tipId);

                  final receptNaziv = (item?['receptNaziv'] ?? '').toString();
                  final isDone = _isDoneValue(item?['izvrsen']);

                  final blokBoja = isDone ? Colors.green.shade100 : Colors.white;
                  final rubBoja =
                  isDone ? Colors.green.shade600 : Colors.grey.shade300;

                  return Card(
                    color: blokBoja,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: rubBoja,
                        width: isDone ? 1.6 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tipIme.isEmpty ? 'Obrok' : tipIme.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                              isDone ? Colors.green.shade900 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            receptNaziv.isEmpty
                                ? 'Nije odabran recept'
                                : receptNaziv,
                            style: TextStyle(
                              color: isDone
                                  ? Colors.green.shade900
                                  : (receptNaziv.isEmpty
                                  ? Colors.black54
                                  : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _pickAndAssignRecipe(
                                      day: day,
                                      tipObrokaId: tipId,
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: Text(
                                      item == null
                                          ? 'Dodaj recept'
                                          : 'Promijeni recept',
                                    ),
                                  ),
                                  if (item != null &&
                                      int.tryParse(
                                          item['idRecept']?.toString() ?? '') !=
                                          null)
                                    OutlinedButton.icon(
                                      onPressed: () => _openDetaljiRecepta(
                                        int.parse(item['idRecept'].toString()),
                                      ),
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('Detalji'),
                                    ),
                                  if (item != null && !isDone)
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmAndDeleteMeal(item),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Obriši recept'),
                                    ),
                                ],
                              ),
                              if (item != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Napravljeno',
                                        style: TextStyle(
                                          color: isDone
                                              ? Colors.green.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                      Checkbox(
                                        value: isDone,
                                        onChanged: isDone
                                            ? null
                                            : (_) => _confirmAndMarkDone(item),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton(
              onPressed: _openAddMealDialogForSelectedDay,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }




}
