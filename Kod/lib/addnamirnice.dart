import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddNamirnicaDialog extends StatefulWidget {

  final Map<String, dynamic>? namirnica;
  AddNamirnicaDialog({this.namirnica});


  @override
  _AddNamirnicaDialogState createState() => _AddNamirnicaDialogState();
}

class _AddNamirnicaDialogState extends State<AddNamirnicaDialog> {
  final _formKey = GlobalKey<FormState>();
  String _ime = '';
  int _kolicina = 0;
  int? _selectedVelicinaId;
  List<Map<String, dynamic>> _velicinaList = [];
////a
  @override
  // Učitava podatke o namirnici u dijalogu za uređivanje ako je
  // widget.namirnica postavljen, odnosno ako je korisnik otvorio
  // dijalog za uređivanje postojeće namirnice
  void initState() {
    super.initState();
    _loadVelicina();
    if (widget.namirnica != null) {
      _ime = widget.namirnica!['Ime'];
      _kolicina = widget.namirnica!['Kolicina'];
      _selectedVelicinaId = widget.namirnica!['IdVelicina'];
    }
  }

  // Učitava listu veličina iz baze podataka
  Future<void> _loadVelicina() async {
    final data = await DatabaseHelper.getAllVelicina();
    setState(() {
      _velicinaList = data;
    });
  }

  // Dodaje ili ažurira namirnicu u bazi podataka, ovisno o tome
  // je li widget.namirnica postavljen, odnosno je li korisnik
  // otvorio dijalog za uređivanje postojeće namirnice ili dodavanje nove
  Future<void> _addNamirnica() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final namirnica = {
        'Ime': _ime,
        'Kolicina': _kolicina,
        'idVelicina': _selectedVelicinaId,
      };
      if (widget.namirnica != null) {
        await DatabaseHelper.updateNamirnica(widget.namirnica!['IdNamirnice'], namirnica);
      } else {
        await DatabaseHelper.insertNamirnica(namirnica);
      }
      Navigator.of(context).pop();
    }
  }

  // Prikazuje dijalog za dodavanje ili uređivanje namirnice
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.namirnica != null ? 'Uredi Namirnicu' : 'Dodaj Namirnicu'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Polje za unos imena
            TextFormField(
              initialValue: _ime,
              decoration: InputDecoration(labelText: 'Ime'),
              onSaved: (value) {
                _ime = value!;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unesite ime';
                }
                return null;
              },
            ),
            // Polje za unos količine
            TextFormField(
              initialValue: _kolicina.toString(),
              decoration: InputDecoration(labelText: 'Količina'),
              keyboardType: TextInputType.number,
              onSaved: (value) {
                _kolicina = int.parse(value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unesite kolicinu';
                }
                return null;
              },
            ),
            // Dropdown za odabir veličine
            DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: 'Mjera'),
              value: _selectedVelicinaId,
              items: _velicinaList.map((item) {
                return DropdownMenuItem<int>(
                  value: item['IdVelicina'],
                  child: Text(item['VrstaVelicine'].toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVelicinaId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Odaberite mjeru';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        // Dva gumba za odustajanje i dodavanje/uređivanje namirnice
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _addNamirnica,
          child: Text(widget.namirnica != null ? 'Uredi' : 'Dodaj'),
        ),
      ],
    );
  }
}