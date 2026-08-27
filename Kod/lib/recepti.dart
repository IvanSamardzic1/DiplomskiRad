import 'package:flutter/material.dart';
import 'dbqueries.dart';
import 'test_seams.dart';

/* Stranica za recepte.
Prikazuje sve recepte, omogućuje pretragu po imenu recepta ili po imenu autora.
Korisnik može dodati novi recept, a ako je on autor nekog recepta, može ga i
obrisati ili urediti.
Klikom na pojedini recept otvaraju se detalji recepta, gdje su prikazani svi sastojci
i vrijeme potrebno za pripremu jela.
Ako korisnik nema potrebne sastojke za recept, ime recepta je istaknuto crvenom bojom,
a kad korisnik uđe u detalje recepta, ispod svih sastojaka potrebnih za recept nalazi se popis
sastojaka koje korisniku nedostaju, zajedno s informacijom koliko mu
nedostaje svakog sastojka.
 */

class ReceptiPage extends StatefulWidget {
  final AppRepository repository;
  final SessionStore sessionStore;

  const ReceptiPage({
    super.key,
    AppRepository? repository,
    SessionStore? sessionStore,
  })  : repository = repository ?? const DbAppRepository(),
        sessionStore = sessionStore ?? const SharedPrefsSessionStore();

  @override
  State<ReceptiPage> createState() => _ReceptiPageState();
}


class _ReceptiPageState extends State<ReceptiPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _recepti = [];
  int? _currentUserId;
  Map<int, bool> _missingByRecipe = {};
  String _searchQuery = '';


  @override
  void initState() {
    super.initState();
    _loadRecepti();
  }

  List<Map<String, dynamic>> _filteredRecepti() {
    final q = _searchQuery.trim().toLowerCase();

    if (q.isEmpty) return _recepti;

    return _recepti.where((r) {
      final naziv = _value(r['naziv'], fallback: '').toLowerCase();
      final autor = _value(r['autorIme'], fallback: '').toLowerCase();
      return naziv.contains(q) || autor.contains(q);
    }).toList();
  }


  Future<int?> _resolveCurrentUserId() async {
    final loggedInEmail = (await widget.sessionStore.getLoggedInEmail() ?? '').trim().toLowerCase();
    if (loggedInEmail.isEmpty) return null;
    return widget.repository.getUserIdByMail(loggedInEmail);
  }


  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  bool _toBool(dynamic value) {
    final v = value?.toString().trim().toLowerCase() ?? '';
    return v == '1' || v == 'true';
  }


  String _value(dynamic raw, {String fallback = '-'}) {
    final txt = raw?.toString().trim() ?? '';
    return txt.isEmpty ? fallback : txt;
  }

  Future<void> _loadRecepti() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _resolveCurrentUserId();
      final rows = await widget.repository.getReceptiList();

      Map<int, bool> missing = {};
      if (userId != null) {
        missing = await widget.repository.getReceptMissingStatusForUser(userId);
      }


      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        _recepti = rows;
        _missingByRecipe = missing;
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


  Future<void> _openAddRecipeDialog() async {
    if (_currentUserId == null) {
      _showErrorDialog('Nema prijavljenog korisnika.');
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceptFormDialog(
        title: 'Novi recept',
        submitLabel: 'Dodaj',
        onSubmit: (naziv, opis, vrijeme, jeDorucak, sastojci) async {
          await DbQueries.insertReceptForAuthor(
            autorKorisnikId: _currentUserId!,
            naziv: naziv,
            opis: opis,
            vrijemePripremeMin: vrijeme,
            jeDorucak: jeDorucak,
            sastojci: sastojci,
          );
        },
      ),
    );

    if (created == true) {
      await _loadRecepti();
    }
  }

  Future<void> _openEditRecipeDialog(Map<String, dynamic> recept) async {
    if (_currentUserId == null) return;

    final idRecept = _toInt(recept['idRecept']);
    final naziv = _value(recept['naziv'], fallback: '');
    if (idRecept <= 0 || naziv.isEmpty) return;

    try {
      final detalji = await DbQueries.getReceptDetaljiById(idRecept);
      if (detalji == null) {
        _showErrorDialog('Recept nije pronađen.');
        return;
      }

      final autorId = _toInt(detalji['autorKorisnikId']);
      if (autorId != _currentUserId) {
        _showErrorDialog('Možeš uređivati samo svoje recepte.');
        return;
      }

      final detaljiSastojci =
      await DbQueries.getReceptSastojciByReceptId(idRecept);

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReceptFormDialog(
          title: 'Uredi recept',
          submitLabel: 'Spremi',
          initialNaziv: _value(detalji['naziv'], fallback: ''),
          initialOpis: _value(detalji['opis'], fallback: ''),
          initialVrijeme: _toInt(detalji['vrijemePripreme']),
          initialJeDorucak: _toBool(detalji['jeDorucak']),
          initialSastojci: detaljiSastojci,
          onSubmit: (naziv, opis, vrijeme, jeDorucak, sastojci) async {
            await DbQueries.updateReceptByAuthor(
              idRecept: idRecept,
              autorKorisnikId: _currentUserId!,
              naziv: naziv,
              opis: opis,
              vrijemePripremeMin: vrijeme,
              jeDorucak: jeDorucak,
              sastojci: sastojci,
            );
          },
        ),
      );

      if (result == true) {
        await _loadRecepti();
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _confirmDeleteRecipe(Map<String, dynamic> recept) async {
    if (_currentUserId == null) return;

    final idRecept = _toInt(recept['idRecept']);
    if (idRecept <= 0) return;

    final naziv = _value(recept['naziv'], fallback: 'Ovaj recept');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: Text('Jesi siguran da želiš obrisati "$naziv"?'),
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
      await DbQueries.deleteReceptByAuthor(
        idRecept: idRecept,
        autorKorisnikId: _currentUserId!,
      );
      if (!mounted) return;
      await _loadRecepti();
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

  Future<void> _openDetails(int idRecept) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceptDetaljiPage(
          idRecept: idRecept,
          currentUserId: _currentUserId,
        ),
      ),
    );

    if (changed == true) {
      await _loadRecepti();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecepti();
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
                onPressed: _loadRecepti,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Svi recepti',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Pretraži po nazivu ili autoru',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 125),
          child: filtered.isEmpty
              ? const Center(
            child: Text(
              'Nema rezultata pretrage.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadRecepti,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final recept = filtered[index];
                final idRecept = _toInt(recept['idRecept']);
                final naziv = _value(recept['naziv'], fallback: 'Bez naziva');
                final autorIme = _value(recept['autorIme'], fallback: 'Nepoznato');
                final autorId = _toInt(recept['autorKorisnikId']);
                final jeDorucak = _toBool(recept['jeDorucak']);
                final isAuthor =
                    _currentUserId != null && _currentUserId == autorId;
                final hasMissing = _missingByRecipe[idRecept] ?? false;

                return Card(
                  child: ListTile(
                    title: Text(
                      naziv,
                      style: TextStyle(
                        color: hasMissing ? Colors.red : null,
                        fontWeight:
                        hasMissing ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      hasMissing
                          ? 'Autor: $autorIme • ${jeDorucak ? 'Doručak' : 'Ručak/Večera'} • Nedostaju sastojci'
                          : 'Autor: $autorIme • ${jeDorucak ? 'Doručak' : 'Ručak/Večera'}',
                      style: TextStyle(color: hasMissing ? Colors.red : null),
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        if (isAuthor)
                          IconButton(
                            tooltip: 'Uredi',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _openEditRecipeDialog(recept),
                          ),
                        if (isAuthor)
                          IconButton(
                            tooltip: 'Obriši',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteRecipe(recept),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: idRecept <= 0 ? null : () => _openDetails(idRecept),
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
              tooltip: 'Dodaj recept',
              onPressed: _currentUserId == null ? null : _openAddRecipeDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

class ReceptDetaljiPage extends StatefulWidget {
  final int idRecept;
  final int? currentUserId;
  final Future<Map<String, dynamic>?> Function(int idRecept)? loadReceptDetalji;
  final Future<List<Map<String, dynamic>>> Function(int idRecept)? loadReceptSastojci;
  final Future<List<Map<String, dynamic>>> Function({
  required int idRecept,
  required int idKorisnik,
  })? loadMissingSastojci;


  const ReceptDetaljiPage({
    super.key,
    required this.idRecept,
    required this.currentUserId,
    this.loadReceptDetalji,
    this.loadReceptSastojci,
    this.loadMissingSastojci,
  });

  @override
  State<ReceptDetaljiPage> createState() => _ReceptDetaljiPageState();
}

class _ReceptDetaljiPageState extends State<ReceptDetaljiPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recept;
  List<Map<String, dynamic>> _sastojci = [];
  List<Map<String, dynamic>> _missingSastojci = [];


  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  bool _toBool(dynamic value) {
    final v = value?.toString().trim().toLowerCase() ?? '';
    return v == '1' || v == 'true';
  }

  String _value(dynamic raw, {String fallback = '-'}) {
    final txt = raw?.toString().trim() ?? '';
    return txt.isEmpty ? fallback : txt;
  }

  bool get _isAuthor {
    final autorId = _toInt(_recept?['autorKorisnikId']);
    return widget.currentUserId != null && widget.currentUserId == autorId;
  }

  @override
  void initState() {
    super.initState();
    _loadDetalji();
  }

  Future<void> _loadDetalji() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recept = await (widget.loadReceptDetalji?.call(widget.idRecept) ??
          DbQueries.getReceptDetaljiById(widget.idRecept));
      if (recept == null) {
        throw Exception('Recept nije pronađen.');
      }

      final sastojci = await (widget.loadReceptSastojci?.call(widget.idRecept) ??
          DbQueries.getReceptSastojciByReceptId(widget.idRecept));

      List<Map<String, dynamic>> missing = [];
      if (widget.currentUserId != null) {
        missing = await (widget.loadMissingSastojci?.call(
          idRecept: widget.idRecept,
          idKorisnik: widget.currentUserId!,
        ) ??
            DbQueries.getMissingSastojciForReceptUser(
              idRecept: widget.idRecept,
              idKorisnik: widget.currentUserId!,
            ));
      }

      if (!mounted) return;
      setState(() {
        _recept = recept;
        _sastojci = sastojci;
        _missingSastojci = missing;
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


  Future<void> _editThisRecipe() async {
    if (!_isAuthor || _recept == null || widget.currentUserId == null) return;

    final idRecept = _toInt(_recept!['idRecept']);
    if (idRecept <= 0) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceptFormDialog(
        title: 'Uredi recept',
        submitLabel: 'Spremi',
        initialNaziv: _value(_recept!['naziv'], fallback: ''),
        initialOpis: _value(_recept!['opis'], fallback: ''),
        initialVrijeme: _toInt(_recept!['vrijemePripreme']),
        initialJeDorucak: _toBool(_recept!['jeDorucak']),
        initialSastojci: _sastojci,
        onSubmit: (naziv, opis, vrijeme, jeDorucak, sastojci) async {
          await DbQueries.updateReceptByAuthor(
            idRecept: idRecept,
            autorKorisnikId: widget.currentUserId!,
            naziv: naziv,
            opis: opis,
            vrijemePripremeMin: vrijeme,
            jeDorucak: jeDorucak,
            sastojci: sastojci,
          );
        },
      ),
    );

    if (result == true) {
      await _loadDetalji();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteThisRecipe() async {
    if (!_isAuthor || _recept == null || widget.currentUserId == null) return;

    final idRecept = _toInt(_recept!['idRecept']);
    if (idRecept <= 0) return;

    final naziv = _value(_recept!['naziv'], fallback: 'Ovaj recept');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: Text('Jesi siguran da želiš obrisati "$naziv"?'),
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
      await DbQueries.deleteReceptByAuthor(
        idRecept: idRecept,
        autorKorisnikId: widget.currentUserId!,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Detalji recepta'),
        actions: [
          if (_isAuthor)
            IconButton(
              tooltip: 'Uredi',
              icon: const Icon(Icons.edit),
              onPressed: _editThisRecipe,
            ),
          if (_isAuthor)
            IconButton(
              tooltip: 'Obriši',
              icon: const Icon(Icons.delete),
              onPressed: _deleteThisRecipe,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDetalji,
                child: const Text('Pokušaj ponovno'),
              ),
            ],
          ),
        ),
      )
          : Stack(
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
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _value(_recept?['naziv']),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Autor: ${_value(_recept?['autorIme'])}'),
                      const SizedBox(height: 4),
                      Text(
                        'Vrijeme pripreme: ${_value(_recept?['vrijemePripreme'])} min',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tip recepta: ${_toBool(_recept?['jeDorucak']) ? 'Doručak' : 'Ručak/Večera'}',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Opis',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(_value(_recept?['opis'])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sastojci',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
              if (_sastojci.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child:
                    Text('Nema unesenih sastojaka za ovaj recept.'),
                  ),
                )
              else
                ..._sastojci.map((s) {
                  final nazivSastojka = _value(s['sastojakIme']);
                  final kolicina = _value(s['potrebnaKolicina']);
                  final velicina =
                  _value(s['oznakaVelicine'], fallback: '');

                  return Card(
                    child: ListTile(
                      title: Text(nazivSastojka),
                      subtitle: Text(
                        velicina.isEmpty
                            ? 'Potrebno: $kolicina'
                            : 'Potrebno: $kolicina $velicina',
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 12),
              if (widget.currentUserId != null) ...[
                const Text(
                  'Nedostaje',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                if (_missingSastojci.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Imaš dovoljno svih sastojaka.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  )
                else
                  ..._missingSastojci.map((m) {
                    final naziv = _value(m['sastojakIme']);
                    final potrebno = _toInt(m['potrebno']);
                    final dostupno = _toInt(m['dostupno']);
                    final nedostaje = _toInt(m['nedostaje']);
                    final velicina = _value(m['oznakaVelicine'], fallback: '');

                    final unit = velicina.isEmpty ? '' : ' $velicina';

                    return Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(
                          naziv,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Nedostaje: $nedostaje$unit (dostupno: $dostupno$unit, potrebno: $potrebno$unit)',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceptFormDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String initialNaziv;
  final String initialOpis;
  final int? initialVrijeme;
  final bool initialJeDorucak;
  final List<Map<String, dynamic>> initialSastojci;
  final Future<void> Function(
      String naziv,
      String opis,
      int vrijeme,
      bool jeDorucak,
      List<Map<String, dynamic>> sastojci,
      )? onSubmit;

  const _ReceptFormDialog({
    required this.title,
    required this.submitLabel,
    this.initialNaziv = '',
    this.initialOpis = '',
    this.initialVrijeme,
    this.initialJeDorucak = false,
    this.initialSastojci = const [],
    this.onSubmit,
  });

  @override
  State<_ReceptFormDialog> createState() => _ReceptFormDialogState();
}

class _ReceptFormDialogState extends State<_ReceptFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nazivController;
  late final TextEditingController _opisController;
  late final TextEditingController _vrijemeController;
  final _sastojakKolicinaController = TextEditingController();

  late bool _jeDorucak;

  bool _submitting = false;
  bool _loadingSastojci = true;
  String? _error;

  List<Map<String, dynamic>> _allSastojci = [];
  int? _selectedSastojakId;
  late List<Map<String, dynamic>> _odabraniSastojci;

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _value(dynamic raw, {String fallback = '-'}) {
    final txt = raw?.toString().trim() ?? '';
    return txt.isEmpty ? fallback : txt;
  }

  @override
  void initState() {
    super.initState();
    _nazivController = TextEditingController(text: widget.initialNaziv);
    _opisController = TextEditingController(text: widget.initialOpis);
    _vrijemeController = TextEditingController(
      text:
      widget.initialVrijeme == null ? '' : widget.initialVrijeme.toString(),
    );
    _jeDorucak = widget.initialJeDorucak;

    _odabraniSastojci = widget.initialSastojci
        .map<Map<String, dynamic>>(
          (s) => <String, dynamic>{
        'idSastojak': _toInt(s['idSastojak']),
        'sastojakIme': _value(s['sastojakIme'], fallback: 'Sastojak'),
        'oznakaVelicine': _value(s['oznakaVelicine'], fallback: ''),
        'potrebnaKolicina': _toInt(s['potrebnaKolicina']),
      },
    )
        .where((s) =>
    (s['idSastojak'] as int) > 0 && (s['potrebnaKolicina'] as int) > 0)
        .toList(growable: true);

    _loadAllSastojci();
  }

  Future<void> _loadAllSastojci() async {
    setState(() {
      _loadingSastojci = true;
      _error = null;
    });

    try {
      final rows = await DbQueries.getAllSastojciForRecipeDropdown();
      if (!mounted) return;
      setState(() {
        _allSastojci = rows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSastojci = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nazivController.dispose();
    _opisController.dispose();
    _vrijemeController.dispose();
    _sastojakKolicinaController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<int>> _buildSastojakDropdownItems() {
    final items = <DropdownMenuItem<int>>[];
    String? lastKategorija;
    var headerValue = -1; // Negativne vrijednosti koristimo samo za disabled naslove.

    for (final s in _allSastojci) {
      final id = _toInt(s['idSastojak']);
      if (id <= 0) continue;

      final naziv = _value(s['sastojakIme'], fallback: 'Sastojak');
      final velicina = _value(s['oznakaVelicine'], fallback: '');
      final kategorija = _value(s['kategorijaIme'], fallback: 'Ostalo');

      if (kategorija != lastKategorija) {
        items.add(
          DropdownMenuItem<int>(
            value: headerValue,
            enabled: false,
            child: Text(
              kategorija.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
        );
        lastKategorija = kategorija;
        headerValue--;
      }

      final label = velicina.isEmpty ? naziv : '$naziv ($velicina)';
      items.add(
        DropdownMenuItem<int>(
          value: id,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(label),
          ),
        ),
      );
    }

    return items;
  }


  void _dodajSastojak() {
    final id = _selectedSastojakId;
    final kolicina = int.tryParse(_sastojakKolicinaController.text.trim());

    if (id == null) {
      setState(() => _error = 'Odaberi sastojak.');
      return;
    }
    if (kolicina == null || kolicina <= 0) {
      setState(() => _error = 'Unesi ispravnu količinu sastojka (>0).');
      return;
    }

    final selected = _allSastojci.firstWhere(
          (s) => _toInt(s['idSastojak']) == id,
      orElse: () => <String, dynamic>{},
    );
    if (selected.isEmpty) {
      setState(() => _error = 'Odabrani sastojak nije pronađen.');
      return;
    }

    final naziv = _value(selected['sastojakIme'], fallback: 'Sastojak');
    final velicina = _value(selected['oznakaVelicine'], fallback: '');

    final existingIndex =
    _odabraniSastojci.indexWhere((s) => _toInt(s['idSastojak']) == id);

    setState(() {
      _error = null;

      if (existingIndex >= 0) {
        final stara = _toInt(_odabraniSastojci[existingIndex]['potrebnaKolicina']);
        _odabraniSastojci[existingIndex]['potrebnaKolicina'] = stara + kolicina;
      } else {
        _odabraniSastojci.add(<String, dynamic>{
          'idSastojak': id,
          'sastojakIme': naziv,
          'oznakaVelicine': velicina,
          'potrebnaKolicina': kolicina,
        });
      }

      _selectedSastojakId = null;
      _sastojakKolicinaController.clear();
    });
  }

  void _obrisiDodaniSastojak(int index) {
    setState(() {
      _odabraniSastojci.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.onSubmit == null) return;
    if (_odabraniSastojci.isEmpty) {
      setState(() => _error = 'Dodaj barem jedan sastojak.');
      return;
    }

    final naziv = _nazivController.text.trim();
    final opis = _opisController.text.trim();
    final vrijeme = int.parse(_vrijemeController.text.trim());

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit!(naziv, opis, vrijeme,_jeDorucak, _odabraniSastojci);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nazivController,
                  decoration: const InputDecoration(labelText: 'Naziv recepta'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Naziv je obavezan';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ovo je recept za doručak'),
                  value: _jeDorucak,
                  onChanged: (v) {
                    setState(() {
                      _jeDorucak = v ?? false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vrijemeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Vrijeme pripreme (min)',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Unesi broj';
                    if (n <= 0) return 'Mora biti > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opisController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Opis'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sastojci recepta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingSastojci)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    value: _selectedSastojakId,
                    hint: const Text('Odaberi sastojak'),
                    menuMaxHeight: 320,
                    items: _buildSastojakDropdownItems(),
                    onChanged: (value) {
                      if (value == null || value <= 0) return; // Ignoriraj disabled naslove kategorija.
                      setState(() {
                        _selectedSastojakId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _sastojakKolicinaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Potrebna količina sastojka',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _dodajSastojak,
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj sastojak'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_odabraniSastojci.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nijedan sastojak još nije dodan.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_odabraniSastojci.length, (index) {
                      final s = _odabraniSastojci[index];
                      final naziv = _value(s['sastojakIme']);
                      final vel = _value(s['oznakaVelicine'], fallback: '');
                      final kol = _toInt(s['potrebnaKolicina']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(naziv),
                          subtitle: Text(
                            vel.isEmpty ? 'Količina: $kol' : 'Količina: $kol $vel',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _obrisiDodaniSastojak(index),
                          ),
                        ),
                      );
                    }),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
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
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
