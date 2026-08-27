import 'package:flutter/material.dart';
import 'ml_scoring.dart';
import 'dbqueries.dart';
import 'heuristika.dart';
import 'test_seams.dart';

class PlanPrehranePage extends StatefulWidget {
  final AppRepository repository;
  final SessionStore sessionStore;

  const PlanPrehranePage({
    super.key,
    AppRepository? repository,
    SessionStore? sessionStore,
  })  : repository = repository ?? const DbAppRepository(),
        sessionStore = sessionStore ?? const SharedPrefsSessionStore();

  @override
  State<PlanPrehranePage> createState() => _PlanPrehranePageState();
}


class _PlanPrehranePageState extends State<PlanPrehranePage> {
  bool _loading = true;
  int? _idKorisnik;

  final MlScoring _ml = MlScoring();
  bool _mlReady = false;

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
    _initMlAndLoad();
  }

  Future<void> _initMlAndLoad() async {
    try {
      await _ml.loadFromAsset('assets/weights.json');
      _mlReady = true;
    } catch (_) {
      _mlReady = false;
    }
    _initLoad();
  }

  bool _isDoneValue(dynamic raw) {
    if (raw is bool) return raw;
    final s = (raw ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true';
  }

  bool _toBool(dynamic value) {
    final v = value?.toString().trim().toLowerCase() ?? '';
    return v == '1' || v == 'true';
  }

  bool _isRecipeAllowedForTip(Map<String, dynamic> recept, int tipObrokaId) {
    final jeDorucak = _toBool(recept['jeDorucak']);
    if (tipObrokaId == TipObroka.dorucak) return jeDorucak;
    return !jeDorucak;
  }


  Future<void> _openAddMealDialogForSelectedDay() async {
    if (_idKorisnik == null) return;
    final selectedDay = _days[_selectedDayIndex];

    int? selectedTipId;
    int? selectedReceptId;
    List<int> topMlIds = [];
    bool loadingTopMl = false;
    List<int> topHeuristicIds = [];
    bool loadingTopHeuristic = false;


    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final filteredRecepti = (selectedTipId == null)
                ? <Map<String, dynamic>>[]
                : _recepti
                .where((r) => _isRecipeAllowedForTip(r, selectedTipId!))
                .toList();
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
                      onChanged: (v) async {
                        setLocal(() {
                          selectedTipId = v;
                          selectedReceptId = null;
                          topMlIds = [];
                          topHeuristicIds = [];
                          loadingTopMl = v != null;
                          loadingTopHeuristic = v != null;
                        });

                        if (v == null) return;

                        try {
                          final mlIds = await _getTopMlRecommendedRecipeIds(v);
                          final heuristicIds = await _getTopHeuristicRecommendedRecipeIds(v);

                          if (!ctx.mounted) return;

                          setLocal(() {
                            topMlIds = mlIds;
                            topHeuristicIds = heuristicIds;
                            loadingTopMl = false;
                            loadingTopHeuristic = false;
                          });
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setLocal(() {
                            loadingTopMl = false;
                            loadingTopHeuristic = false;
                          });
                          _showError('Greška pri preporukama: $e');
                        }
                      },

                    ),
                    if (selectedTipId != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ML preporučeno (Top 3):',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (loadingTopMl)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (topMlIds.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Nema ML preporuka za odabrani tip obroka.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topMlIds.map((id) {
                            final rec = _recepti.firstWhere(
                              (r) => int.tryParse(r['idRecept']?.toString() ?? '') == id,
                              orElse: () => <String, dynamic>{},
                            );
                            final naziv = (rec['naziv'] ?? 'Recept #$id').toString();
                            return ActionChip(
                              label: Text(naziv),
                              onPressed: () => setLocal(() => selectedReceptId = id),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Heuristika preporučeno (Top 3):',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (loadingTopHeuristic)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (topHeuristicIds.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Nema heurističkih preporuka za odabrani tip obroka.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topHeuristicIds.map((id) {
                            final rec = _recepti.firstWhere(
                                  (r) => int.tryParse(r['idRecept']?.toString() ?? '') == id,
                              orElse: () => <String, dynamic>{},
                            );
                            final naziv = (rec['naziv'] ?? 'Recept #$id').toString();
                            return ActionChip(
                              label: Text(naziv),
                              onPressed: () => setLocal(() => selectedReceptId = id),
                            );
                          }).toList(),
                        ),

                    ],

                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedReceptId,
                      decoration: const InputDecoration(
                        labelText: 'Recept',
                        border: OutlineInputBorder(),
                      ),
                      items: filteredRecepti.map((r) {
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

      final email = await widget.sessionStore.getLoggedInEmail();

      if (email == null || email.trim().isEmpty) {
        throw Exception('Nije pronaden prijavljeni korisnik (email).');
      }

      final idKorisnik = await widget.repository.getUserIdByMail(email);
      if (idKorisnik == null) {
        throw Exception('Nije pronaden id prijavljenog korisnika.');
      }

      final vrste = await widget.repository.getVrsteObroka();
      final plan = await widget.repository.getPlanObrokaZaPeriod(
        idKorisnik: idKorisnik,
        od: _days.first,
        doDatuma: _days.last,
      );
      final recepti = await widget.repository.getReceptiList();


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

  Future<List<int>> _getTopMlRecommendedRecipeIds(int tipObrokaId) async {
    if (_idKorisnik == null || !_mlReady) return [];

    final rows = await DbQueries.getMlFeaturesForUserTip(
      idKorisnik: _idKorisnik!,
      tipObrokaId: tipObrokaId,
    );

    final scored = rows.map((r) {
      final score = _ml.predictProbability({
        'vrijemePripremeMin': r['vrijemePripremeMin'],
        'pokrivenostZaliha': r['pokrivenostZaliha'],
        'fifoSignal': r['fifoSignal'],
        'userOdabranCount': r['userOdabranCount'],
        'userIzvrsenCount': r['userIzvrsenCount'],
        'trazeniTipObrokaId': r['trazeniTipObrokaId'],
      });
      return {
        'idRecept': int.tryParse(r['idRecept'].toString()) ?? 0,
        'score': score,
      };
    }).toList();

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scored.take(3).map((e) => e['idRecept'] as int).where((id) => id > 0).toList();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<List<int>> _getTopHeuristicRecommendedRecipeIds(int tipObrokaId) async {
    if (_idKorisnik == null) return [];

    final rows = await DbQueries.getHeuristicCandidatesForUser(
      idKorisnik: _idKorisnik!,
      tipObrokaId: tipObrokaId
    );

    final candidates = rows.map((r) {
      return HeuristikaKandidat(
        receptId: _toInt(r['idRecept']),
        vrijemePripremeMin: _toInt(r['vrijemePripremeMin']),
        pokrivenostZaliha: _toDouble(r['pokrivenostZaliha']),
        fifoSignal: _toDouble(r['fifoSignal']),
        userOdabranCount: _toInt(r['userOdabranCount']),
        userIzvrsenCount: _toInt(r['userIzvrsenCount']),
      );
    }).toList();

    return Heuristika.topRecipeIds(
      candidates: candidates,
      trazeniTipObrokaId: tipObrokaId,
      limit: 3,
    );
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
                  final isSelected = _isDoneValue(item?['odabran']);
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
                                  /*ElevatedButton.icon(
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
                                  ),*/
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
                                        onChanged: (!isSelected || isDone)
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
