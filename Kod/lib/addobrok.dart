import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddObrokDialog extends StatefulWidget {
  @override
  _AddObrokDialogState createState() => _AddObrokDialogState();
}

class _AddObrokDialogState extends State<AddObrokDialog> {
  final _formKey = GlobalKey<FormState>();
  String _dan = '';
  String _obrok = '';
  int? _selectedNamirnicaId;
  int _kolicina = 0;
  String _ime = '';
  List<Map<String, dynamic>> _namirniceList = [];
  final List<String> _daysOfWeek = ['Ponedjeljak', 'Utorak', 'Srijeda', 'Cetvrtak', 'Petak', 'Subota', 'Nedjelja'];
  final List<String> _meals = ['Dorucak', 'Dopodnevna uzina', 'Rucak', 'Popodnevna uzina', 'Vecera'];

  @override
  // Inicijalizacija stanja i učitavanje namirnica
  void initState() {
    super.initState();
    _loadNamirnice();
  }

  // Učitavanje namirnica iz baze podataka
  Future<void> _loadNamirnice() async {
    final data = await DatabaseHelper.getAllNamirnice();
    setState(() {
      _namirniceList = data.where((item) => item['Kolicina'] > 0).toList();
    });
  }

  // Dodavanje obroka u bazu podataka
  Future<void> _addObrok() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final selectedNamirnica = _namirniceList.firstWhere((item) => item['IdNamirnice'] == _selectedNamirnicaId);
      if (selectedNamirnica['Kolicina'] >= _kolicina) {
        final obrok = {
          'Dan': _dan,
          'Obrok': _obrok,
          'IdNamirnice': _selectedNamirnicaId,
          'Kolicina': _kolicina,
          'Ime': _ime
        };
        // Dodavanje obroka u bazu podataka
        await DatabaseHelper.insertObrok(obrok);
        // Ažuriranje količine namirnice jer je korištena za obrok
        await DatabaseHelper.updateNamirnica(_selectedNamirnicaId!, {
          'Kolicina': selectedNamirnica['Kolicina'] - _kolicina,
        });
        Navigator.of(context).pop();
      } else {
        // Prikaz obavijesti o nedovoljnoj količini namirnica za obrok
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nema dovoljno namirnica')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dodaj Obrok'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              // Prikaz padajućeg izbornika za odabir dana u tjednu
              decoration: InputDecoration(labelText: 'Dan'),
              value: _dan.isEmpty ? null : _dan,
              items: _daysOfWeek.map((day) {
                return DropdownMenuItem<String>(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _dan = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Odaberite dan';
                }
                return null;
              },
            ),
            // Prikaz padajućeg izbornika za odabir obroka
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Obrok'),
              value: _obrok.isEmpty ? null : _obrok,
              items: _meals.map((meal) {
                return DropdownMenuItem<String>(
                  value: meal,
                  child: Text(meal),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _obrok = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Odaberite obrok';
                }
                return null;
              },
            ),
            // Prikaz padajućeg izbornika za odabir namirnice(samo one koje su trenutno dostupne)
            DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: 'Namirnica'),
              value: _selectedNamirnicaId,
              items: _namirniceList.map((item) {
                return DropdownMenuItem<int>(
                  value: item['IdNamirnice'],
                  child: Text(item['Ime'].toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedNamirnicaId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Odaberite namirnicu';
                }
                return null;
              },
            ),
            // Prikaz polja za unos količine
            TextFormField(
              decoration: InputDecoration(labelText: 'Količina'),
              keyboardType: TextInputType.number,
              onSaved: (value) {
                _kolicina = int.parse(value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unesite količinu';
                }
                return null;
              },
            ),
            // Prikaz polja za unos opisa, odnosno imena obroka
            TextFormField(
              decoration: InputDecoration(labelText: 'Opis'),
              onSaved: (value) {
                _ime = value!;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unesite ime obroka';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        // Prikaz gumba za odustajanje i dodavanje obroka
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _addObrok,
          child: Text('Dodaj'),
        ),
      ],
    );
  }
}