import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dbqueries.dart';

class ZalihaNamirnicePage extends StatefulWidget {
  const ZalihaNamirnicePage({super.key});

  @override
  State<ZalihaNamirnicePage> createState() => _ZalihaNamirnicePageState();
}

class _ZalihaNamirnicePageState extends State<ZalihaNamirnicePage> {
  bool _isLoading = true;
  String? _error;
  int? _userId;
  List<Map<String, dynamic>> _zalihe = [];

  @override
  void initState() {
    super.initState();
    _loadZalihe();
  }

  Future<void> _loadZalihe() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedInEmail =
      (prefs.getString('loggedInEmail') ?? '').trim().toLowerCase();

      if (loggedInEmail.isEmpty) {
        throw Exception('Nema prijavljenog korisnika.');
      }

      final userId = await DbQueries.getUserIdByMail(loggedInEmail);
      if (userId == null) {
        throw Exception('Korisnik nije pronađen.');
      }

      final rows = await DbQueries.getZaliheForUser(userId);

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _zalihe = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddDialog() async {
    if (_userId == null) {
      await _loadZalihe();
      if (_userId == null) return;
    }

    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddZalihaDialog(idKorisnik: _userId!),
    );

    if (added == true) {
      await _loadZalihe();
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditZalihaDialog(
        idKorisnik: _userId!,
        item: item,
      ),
    );

    if (updated == true) {
      await _loadZalihe();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final idZaliha = _toInt(item['idZaliha']);
    if (idZaliha <= 0) return;

    final sastojakIme = (item['sastojakIme'] ?? 'Ova namirnica').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content:
        Text('Jesi siguran da želiš obrisati "$sastojakIme" iz zalihe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DbQueries.deleteZalihaById(
        idZaliha: idZaliha,
        idKorisnik: _userId!,
      );
      if (!mounted) return;
      await _loadZalihe();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Greška'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatDate(dynamic rawValue) {
    if (rawValue == null) return '-';
    final raw = rawValue.toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd.$mm.$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadZalihe,
                child: const Text('Pokušaj ponovno'),
              ),
            ],
          ),
        ),
      );
    }

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
              'Moje zalihe namirnica',
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
          child: _zalihe.isEmpty
              ? const Center(
            child: Text(
              'Nema zaliha za ovog korisnika.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadZalihe,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: _zalihe.length,
              itemBuilder: (context, index) {
                final item = _zalihe[index];
                final kolicina = _toInt(item['kolicina']);
                final minKolicina = _toInt(item['minKolicina']);
                final isBelowMin = kolicina < minKolicina;

                final sastojakIme = (item['sastojakIme'] ?? '').toString();
                final kategorijaIme =
                (item['kategorijaIme'] ?? '-').toString();
                final oznakaVelicine =
                (item['oznakaVelicine'] ?? '').toString();
                final datumRoka = _formatDate(item['datum']);

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isBelowMin
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2,
                      color: isBelowMin ? Colors.orange : Colors.blue,
                    ),
                    title: Text(sastojakIme),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategorija: $kategorijaIme'),
                        Text('Količina: $kolicina $oznakaVelicine'),
                        Text('Rok trajanja: $datumRoka'),
                        if (isBelowMin)
                          Text(
                            'Upozorenje: ispod minimalne količine ($minKolicina)',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Uredi',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _openEditDialog(item),
                          ),
                          IconButton(
                            tooltip: 'Obriši',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(item),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton(
              onPressed: _openAddDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

}

class _AddZalihaDialog extends StatefulWidget {
  final int idKorisnik;

  const _AddZalihaDialog({required this.idKorisnik});

  @override
  State<_AddZalihaDialog> createState() => _AddZalihaDialogState();
}

class _AddZalihaDialogState extends State<_AddZalihaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kolicinaController = TextEditingController();
  final _minController = TextEditingController();
  final _datumController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _loadingPostojeca = false;
  String? _errorText;

  List<Map<String, dynamic>> _kategorije = [];
  List<Map<String, dynamic>> _sastojci = [];

  int? _selectedKategorijaId;
  int? _selectedSastojakId;
  DateTime? _selectedDatum;
  String _selectedVelicina = '-';

  Map<String, dynamic>? _postojecaZaliha;

  @override
  void initState() {
    super.initState();
    _loadKategorije();
  }

  @override
  void dispose() {
    _kolicinaController.dispose();
    _minController.dispose();
    _datumController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatDate(dynamic rawValue) {
    if (rawValue == null) return '-';
    final dt = DateTime.tryParse(rawValue.toString());
    if (dt == null) return rawValue.toString();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd.$mm.${dt.year}';
  }

  DateTime? _parseDbDate(dynamic rawValue) {
    if (rawValue == null) return null;
    return DateTime.tryParse(rawValue.toString());
  }

  Future<void> _loadKategorije() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final kategorije = await DbQueries.getKategorije();

      setState(() {
        _kategorije = kategorije;
        _selectedKategorijaId = null;
        _sastojci = [];
        _selectedSastojakId = null;
        _selectedVelicina = '-';
        _postojecaZaliha = null;
      });
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSastojciForKategorija(int idKategorija) async {
    final sastojci = await DbQueries.getSastojciByKategorija(idKategorija);

    setState(() {
      _sastojci = sastojci;
      _selectedSastojakId = null;
      _selectedVelicina = '-';
      _postojecaZaliha = null;
      _datumController.clear();
      _minController.clear();
      _selectedDatum = null;
    });
  }

  Future<void> _loadPostojecaZaliha(int idSastojak) async {
    setState(() {
      _loadingPostojeca = true;
      _postojecaZaliha = null;
    });

    try {
      final row = await DbQueries.getZalihaItemForUserSastojak(
        idKorisnik: widget.idKorisnik,
        idSastojak: idSastojak,
      );

      if (!mounted) return;
      setState(() {
        _postojecaZaliha = row;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPostojeca = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDatum ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 20),
    );

    if (picked != null) {
      final dd = picked.day.toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final yyyy = picked.year.toString();
      setState(() {
        _selectedDatum = picked;
        _datumController.text = '$dd.$mm.$yyyy';
      });
    }
  }

  Future<void> _onSastojakChanged(int? newId) async {
    if (newId == null) return;

    final selected = _sastojci.firstWhere(
          (s) => int.tryParse(s['idSastojak'].toString()) == newId,
      orElse: () => <String, dynamic>{},
    );

    setState(() {
      _selectedSastojakId = newId;
      _selectedVelicina = (selected['oznakaVelicine'] ?? '-').toString();
      _errorText = null;
      _postojecaZaliha = null;
      _datumController.clear();
      _minController.clear();
      _selectedDatum = null;
    });

    await _loadPostojecaZaliha(newId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKategorijaId == null) {
      setState(() => _errorText = 'Odaberite kategoriju.');
      return;
    }

    if (_selectedSastojakId == null) {
      setState(() => _errorText = 'Odaberite sastojak.');
      return;
    }

    final kolicina = int.parse(_kolicinaController.text.trim());

    final minTxt = _minController.text.trim();
    final int? minInput = minTxt.isEmpty ? null : int.parse(minTxt);

    DateTime? datumInput = _selectedDatum;

    int finalMinKolicina;
    DateTime finalDatumRoka;

    if (_postojecaZaliha != null) {
      final postojeceMin = _toInt(_postojecaZaliha!['minKolicina']);
      final postojeciDatum = _parseDbDate(_postojecaZaliha!['datum']);

      finalMinKolicina = minInput ?? postojeceMin;
      finalDatumRoka = datumInput ?? postojeciDatum ?? DateTime.now();
    } else {
      if (minInput == null || datumInput == null) {
        setState(() {
          _errorText = 'Unesite minimalnu kolicinu i datum roka trajanja.';
        });
        return;
      }
      finalMinKolicina = minInput;
      finalDatumRoka = datumInput;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await DbQueries.upsertZalihaForUser(
        idKorisnik: widget.idKorisnik,
        idSastojak: _selectedSastojakId!,
        dodatnaKolicina: kolicina,
        datumRoka: finalDatumRoka,
        minKolicina: finalMinKolicina,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodaj namirnicu u zalihu'),
      content: _loading
          ? const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      )
          : SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedKategorijaId,
                  hint: const Text('Odaberi kategoriju'),
                  decoration: const InputDecoration(labelText: 'Kategorija'),
                  items: _kategorije
                      .map(
                        (k) => DropdownMenuItem<int>(
                      value: int.tryParse(k['idKategorija'].toString()),
                      child: Text((k['imeKategorije'] ?? '').toString()),
                    ),
                  )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() {
                      _selectedKategorijaId = value;
                      _selectedSastojakId = null;
                      _sastojci = [];
                      _selectedVelicina = '-';
                      _postojecaZaliha = null;
                    });
                    await _loadSastojciForKategorija(value);
                  },
                  validator: (v) => v == null ? 'Odaberi kategoriju' : null,
                ),
                if (_selectedKategorijaId != null) ...[
                  const SizedBox(height: 12),
                  if (_sastojci.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _selectedSastojakId,
                      hint: const Text('Odaberi sastojak'),
                      decoration:
                      const InputDecoration(labelText: 'Sastojak'),
                      items: _sastojci
                          .map(
                            (s) => DropdownMenuItem<int>(
                          value: int.tryParse(s['idSastojak'].toString()),
                          child:
                          Text((s['sastojakIme'] ?? '').toString()),
                        ),
                      )
                          .toList(),
                      onChanged: (v) async => _onSastojakChanged(v),
                      validator: (v) => v == null ? 'Odaberi sastojak' : null,
                    )
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Nema sastojaka za odabranu kategoriju.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Veličina: $_selectedVelicina',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _kolicinaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Količina'),
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null) return 'Unesi broj';
                      if (value <= 0) return 'Mora biti > 0';
                      return null;
                    },
                  ),
                  if (_loadingPostojeca)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (_postojecaZaliha != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Dosadašnja količina: ${_toInt(_postojecaZaliha!['kolicina'])}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration:
                    const InputDecoration(labelText: 'Minimalna količina'),
                    validator: (v) {
                      final txt = (v ?? '').trim();

                      if (txt.isEmpty) {
                        if (_postojecaZaliha != null) return null;
                        return 'Unesi broj';
                      }

                      final value = int.tryParse(txt);
                      if (value == null) return 'Unesi broj';
                      if (value < 0) return 'Ne može biti negativno';
                      return null;
                    },
                  ),
                  if (_postojecaZaliha != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Dosadašnja minimalna količina: ${_toInt(_postojecaZaliha!['minKolicina'])}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _datumController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Datum roka trajanja',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _pickDate,
                    validator: (v) {
                      final txt = (v ?? '').trim();
                      if (txt.isEmpty) {
                        if (_postojecaZaliha != null) return null;
                        return 'Odaberi datum';
                      }
                      return null;
                    },
                  ),
                  if (_postojecaZaliha != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Dosadašnji rok trajanja: ${_formatDate(_postojecaZaliha!['datum'])}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (_postojecaZaliha != null)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Ako ne uneseš novu minimalnu količinu ili datum, ostaju postojeći.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Spremi'),
        ),
      ],
    );
  }
}

class _EditZalihaDialog extends StatefulWidget {
  final int idKorisnik;
  final Map<String, dynamic> item;

  const _EditZalihaDialog({
    required this.idKorisnik,
    required this.item,
  });

  @override
  State<_EditZalihaDialog> createState() => _EditZalihaDialogState();
}

class _EditZalihaDialogState extends State<_EditZalihaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kolicinaController = TextEditingController();
  final _minController = TextEditingController();
  final _datumController = TextEditingController();

  bool _submitting = false;
  DateTime? _selectedDatum;

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();

    _kolicinaController.text = _toInt(widget.item['kolicina']).toString();
    _minController.text = _toInt(widget.item['minKolicina']).toString();

    final rawDate = widget.item['datum']?.toString();
    final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);
    _selectedDatum = parsed;

    if (parsed != null) {
      final dd = parsed.day.toString().padLeft(2, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final yyyy = parsed.year.toString();
      _datumController.text = '$dd.$mm.$yyyy';
    }
  }

  @override
  void dispose() {
    _kolicinaController.dispose();
    _minController.dispose();
    _datumController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDatum ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 20),
    );

    if (picked == null) return;

    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final yyyy = picked.year.toString();

    setState(() {
      _selectedDatum = picked;
      _datumController.text = '$dd.$mm.$yyyy';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDatum == null) return;

    final idZaliha = _toInt(widget.item['idZaliha']);
    if (idZaliha <= 0) return;

    final kolicina = int.parse(_kolicinaController.text.trim());
    final minKolicina = int.parse(_minController.text.trim());

    setState(() => _submitting = true);

    try {
      await DbQueries.updateZalihaById(
        idZaliha: idZaliha,
        idKorisnik: widget.idKorisnik,
        kolicina: kolicina,
        minKolicina: minKolicina,
        datumRoka: _selectedDatum!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Greška'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sastojakIme = (widget.item['sastojakIme'] ?? '').toString();

    return AlertDialog(
      title: Text('Uredi zalihu: $sastojakIme'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _kolicinaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Količina'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Unesi broj';
                    if (n <= 0) return 'Mora biti više od 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimalna količina'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Unesi broj';
                    if (n < 0) return 'Ne može biti negativno';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _datumController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Datum roka trajanja',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _pickDate,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Odaberi datum' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Spremi'),
        ),
      ],
    );
  }
}
