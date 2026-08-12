import 'package:flutter/material.dart';
import 'dbqueries.dart';
import 'test_seams.dart';

class TrgovinaPage extends StatefulWidget {
  final AppRepository repository;
  final SessionStore sessionStore;

  const TrgovinaPage({
    super.key,
    AppRepository? repository,
    SessionStore? sessionStore,
  })  : repository = repository ?? const DbAppRepository(),
        sessionStore = sessionStore ?? const SharedPrefsSessionStore();

  @override
  State<TrgovinaPage> createState() => _TrgovinaPageState();
}


class _TrgovinaPageState extends State<TrgovinaPage> {
  bool _isLoading = true;
  String? _error;
  int? _userId;
  List<Map<String, dynamic>> _stavke = [];
  final Set<int> _busyItemIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadStavke();
  }

  Future<void> _loadStavke() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final loggedInEmail = (await widget.sessionStore.getLoggedInEmail() ?? '').trim().toLowerCase();

      if (loggedInEmail.isEmpty) {
        throw Exception('Nema prijavljenog korisnika.');
      }

      final userId = await widget.repository.getUserIdByMail(loggedInEmail);
      if (userId == null) { throw Exception('Korisnik nije pronađen.');  }
      final rows = await widget.repository.getStavkePopisaTrgovineForUser(userId);


      if (!mounted) return;
      setState(() {
        _userId = userId;
        _stavke = rows;
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
      await _loadStavke();
      if (_userId == null) return;
    }

    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddShoppingItemDialog(idKorisnik: _userId!),
    );

    if (added == true) {
      await _loadStavke();
    }
  }

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd.$mm.$yyyy';
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
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

  Future<DateTime?> _showPurchaseDialog(String sastojakIme) async {
    DateTime selectedDate = DateTime.now();

    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Potvrda kupnje'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jeste li sigurni da je kupljeno: $sastojakIme?'),
                    const SizedBox(height: 12),
                    const Text('Datum roka trajanja'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setLocalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_formatDate(selectedDate)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(selectedDate),
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markAsPurchased(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final idStavkaPopisa = _toInt(item['idStavkaPopisa']);
    final idSastojak = _toInt(item['sastojakId']);
    final kolicina = _toInt(item['kolicina']);
    final sastojakIme = (item['sastojakIme'] ?? '-').toString();

    if (idStavkaPopisa <= 0 || idSastojak <= 0 || kolicina <= 0) {
      print("Neispravni podaci stavke: idStavkaPopisa=$idStavkaPopisa, idSastojak=$idSastojak, kolicina=$kolicina");
      await _showErrorDialog('Neispravni podaci stavke.');
      return;
    }

    final datumRoka = await _showPurchaseDialog(sastojakIme);
    if (datumRoka == null) return;

    setState(() {
      _busyItemIds.add(idStavkaPopisa);
    });
    print("Pokušavam označiti kao kupljeno: idStavkaPopisa=$idStavkaPopisa, idSastojak=$idSastojak, kolicina=$kolicina, datumRoka=${_formatDate(datumRoka)}");
    try {
      await DbQueries.purchaseStavkaPopisaTrgovine(
        idKorisnik: _userId!,
        idStavkaPopisa: idStavkaPopisa,
        idSastojak: idSastojak,
        kupljenaKolicina: kolicina,
        datumRoka: datumRoka,
      );

      if (!mounted) return;
      await _loadStavke();
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(idStavkaPopisa);
        });
      }
    }
  }

  Future<void> _editStavkaKolicina(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final idStavkaPopisa = _toInt(item['idStavkaPopisa']);
    final trenutnaKolicina = _toInt(item['kolicina']);
    final oznakaVelicine = (item['oznakaVelicine'] ?? '').toString();

    if (idStavkaPopisa <= 0) {
      await _showErrorDialog('Neispravan ID stavke.');
      return;
    }

    print("Pokušavam urediti količinu: idStavkaPopisa=$idStavkaPopisa, trenutnaKolicina=$trenutnaKolicina, oznakaVelicine=$oznakaVelicine");
    final novaKolicina = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditKolicinaDialog(
        trenutnaKolicina: trenutnaKolicina,
        oznakaVelicine: oznakaVelicine,
      ),
    );

    if (novaKolicina == null) return;

    setState(() {
      _busyItemIds.add(idStavkaPopisa);
    });

    print("Pokušavam spremiti novu količinu: idStavkaPopisa=$idStavkaPopisa, novaKolicina=$novaKolicina");
    try {
      await DbQueries.updateStavkaPopisaTrgovineKolicina(
        idStavkaPopisa: idStavkaPopisa,
        idKorisnik: _userId!,
        novaKolicina: novaKolicina,
      );

      if (!mounted) return;
      await _loadStavke();
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(idStavkaPopisa);
        });
      }
    }
  }

  Future<void> _deleteStavka(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final idStavkaPopisa = _toInt(item['idStavkaPopisa']);
    final sastojakIme = (item['sastojakIme'] ?? '-').toString();

    if (idStavkaPopisa <= 0) {
      await _showErrorDialog('Neispravan ID stavke.');
      return;
    }


    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: Text('Jeste li sigurni da želite obrisati "$sastojakIme"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _busyItemIds.add(idStavkaPopisa);
    });

    print("Pokušavam obrisati stavku: idStavkaPopisa=$idStavkaPopisa, sastojakIme=$sastojakIme");
    try {
      await DbQueries.deleteStavkaPopisaTrgovineById(
        idStavkaPopisa: idStavkaPopisa,
        idKorisnik: _userId!,
      );

      if (!mounted) return;
      await _loadStavke();
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(idStavkaPopisa);
        });
      }
    }
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
                onPressed: _loadStavke,
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
              'Popis za trgovinu',
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
          child: _stavke.isEmpty
              ? const Center(
            child: Text(
              'Popis je prazan.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadStavke,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: _stavke.length,
              itemBuilder: (context, index) {
                final item = _stavke[index];
                final idStavkaPopisa = _toInt(item['idStavkaPopisa']);
                final isBusy = _busyItemIds.contains(idStavkaPopisa);

                final sastojakIme = (item['sastojakIme'] ?? '-').toString();
                final kategorijaIme =
                (item['kategorijaIme'] ?? '-').toString();
                final oznakaVelicine =
                (item['oznakaVelicine'] ?? '').toString();
                final kolicina = _toInt(item['kolicina']);

                return Card(
                  child: ListTile(
                    leading: isBusy
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : IconButton(
                      tooltip: 'Označi kao kupljeno',
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                      ),
                      onPressed: () => _markAsPurchased(item),
                    ),
                    title: Text(sastojakIme),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategorija: $kategorijaIme'),
                        Text('Potrebno: $kolicina $oznakaVelicine'),
                      ],
                    ),
                    trailing: isBusy
                        ? null
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Uredi',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editStavkaKolicina(item),
                        ),
                        IconButton(
                          tooltip: 'Obriši',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteStavka(item),
                        ),
                      ],
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
            child: FloatingActionButton.extended(
              onPressed: _openAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditKolicinaDialog extends StatefulWidget {
  final int trenutnaKolicina;
  final String oznakaVelicine;

  const _EditKolicinaDialog({
    required this.trenutnaKolicina,
    required this.oznakaVelicine,
  });

  @override
  State<_EditKolicinaDialog> createState() => _EditKolicinaDialogState();
}

class _EditKolicinaDialogState extends State<_EditKolicinaDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.trenutnaKolicina.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n <= 0) {
      setState(() {
        _errorText = 'Količina mora biti cijeli broj > 0.';
      });
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uredi količinu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova potrebna količina (${widget.oznakaVelicine})'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Unesi broj',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Spremi'),
        ),
      ],
    );
  }
}

class _AddShoppingItemDialog extends StatefulWidget {
  final int idKorisnik;

  const _AddShoppingItemDialog({required this.idKorisnik});

  @override
  State<_AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<_AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kolicinaController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _errorText;

  List<Map<String, dynamic>> _kategorije = [];
  List<Map<String, dynamic>> _sastojci = [];

  int? _selectedKategorijaId;
  int? _selectedSastojakId;
  String _selectedVelicina = '-';

  @override
  void initState() {
    super.initState();
    _loadKategorije();
  }

  @override
  void dispose() {
    _kolicinaController.dispose();
    super.dispose();
  }

  Future<void> _loadKategorije() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final kategorije = await DbQueries.getKategorije();
      if (!mounted) return;

      setState(() {
        _kategorije = kategorije;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSastojciForKategorija(int idKategorija) async {
    final sastojci = await DbQueries.getSastojciByKategorija(idKategorija);

    if (!mounted) return;
    setState(() {
      _sastojci = sastojci;
      _selectedSastojakId = null;
      _selectedVelicina = '-';
    });
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
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKategorijaId == null) {
      setState(() => _errorText = 'Odaberi kategoriju.');
      return;
    }

    if (_selectedSastojakId == null) {
      setState(() => _errorText = 'Odaberi sastojak.');
      return;
    }

    final kolicina = int.parse(_kolicinaController.text.trim());

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await DbQueries.insertStavkaPopisaTrgovine(
        idKorisnik: widget.idKorisnik,
        idSastojak: _selectedSastojakId!,
        kolicina: kolicina,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodaj na popis za trgovinu'),
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
                      _sastojci = [];
                      _selectedSastojakId = null;
                      _selectedVelicina = '-';
                    });
                    await _loadSastojciForKategorija(value);
                  },
                  validator: (v) => v == null ? 'Odaberi kategoriju' : null,
                ),
                if (_selectedKategorijaId != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedSastojakId,
                    hint: const Text('Odaberi sastojak'),
                    decoration: const InputDecoration(labelText: 'Sastojak'),
                    items: _sastojci
                        .map(
                          (s) => DropdownMenuItem<int>(
                        value: int.tryParse(s['idSastojak'].toString()),
                        child: Text((s['sastojakIme'] ?? '').toString()),
                      ),
                    )
                        .toList(),
                    onChanged: (v) async => _onSastojakChanged(v),
                    validator: (v) => v == null ? 'Odaberi sastojak' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _kolicinaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Potrebna količina ($_selectedVelicina)',
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Unesi broj';
                      if (n <= 0) return 'Mora biti > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
              : const Text('Dodaj'),
        ),
      ],
    );
  }
}
