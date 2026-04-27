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
      final loggedInEmail = (prefs.getString('loggedInEmail') ?? '').trim().toLowerCase();

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
        _zalihe.isEmpty
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
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: _zalihe.length,
            itemBuilder: (context, index) {
              final item = _zalihe[index];
              final kolicina = _toInt(item['kolicina']);
              final minKolicina = _toInt(item['minKolicina']);
              final isBelowMin = kolicina < minKolicina;

              final sastojakIme = (item['sastojakIme'] ?? '').toString();
              final kategorijaIme = (item['kategorijaIme'] ?? '-').toString();
              final oznakaVelicine = (item['oznakaVelicine'] ?? '').toString();
              final datumRoka = _formatDate(item['datum']);

              return Card(
                child: ListTile(
                  leading: Icon(
                    isBelowMin ? Icons.warning_amber_rounded : Icons.inventory_2,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
