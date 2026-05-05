import 'package:flutter/material.dart';
import 'dbqueries.dart';

class ReceptiPage extends StatefulWidget {
  const ReceptiPage({super.key});

  @override
  State<ReceptiPage> createState() => _ReceptiPageState();
}

class _ReceptiPageState extends State<ReceptiPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _recepti = [];

  @override
  void initState() {
    super.initState();
    _loadRecepti();
  }

  Future<void> _loadRecepti() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = await DbQueries.getReceptiList();
      if (!mounted) return;

      setState(() {
        _recepti = rows;
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

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

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
            child: Text(
              'Svi recepti',
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
          child: _recepti.isEmpty
              ? const Center(
            child: Text(
              'Trenutno nema dostupnih recepata.',
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _recepti.length,
              itemBuilder: (context, index) {
                final recept = _recepti[index];
                final idRecept = _toInt(recept['idRecept']);
                final naziv = (recept['naziv'] ?? 'Bez naziva').toString();

                return Card(
                  child: ListTile(
                    title: Text(naziv),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: idRecept <= 0
                        ? null
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceptDetaljiPage(idRecept: idRecept),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ReceptDetaljiPage extends StatefulWidget {
  final int idRecept;

  const ReceptDetaljiPage({super.key, required this.idRecept});

  @override
  State<ReceptDetaljiPage> createState() => _ReceptDetaljiPageState();
}

class _ReceptDetaljiPageState extends State<ReceptDetaljiPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recept;
  List<Map<String, dynamic>> _sastojci = [];

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
      final recept = await DbQueries.getReceptDetaljiById(widget.idRecept);
      if (recept == null) {
        throw Exception('Recept nije pronađen.');
      }

      final sastojci =
      await DbQueries.getReceptSastojciByReceptId(widget.idRecept);

      if (!mounted) return;
      setState(() {
        _recept = recept;
        _sastojci = sastojci;
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

  String _value(dynamic raw, {String fallback = '-'}) {
    final txt = raw?.toString().trim() ?? '';
    return txt.isEmpty ? fallback : txt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Detalji recepta'),
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
                        'Vrijeme pripreme: ${_value(_recept?['vrijemePripreme'])}',
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
                    child: Text('Nema unesenih sastojaka za ovaj recept.'),
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
            ],
          ),
        ],
      ),
    );
  }
}
