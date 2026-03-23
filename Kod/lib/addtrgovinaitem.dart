import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddTrgovinaItemDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final bool isEditing;

  AddTrgovinaItemDialog({this.item, this.isEditing = false});

  @override
  _AddTrgovinaItemDialogState createState() => _AddTrgovinaItemDialogState();
}

class _AddTrgovinaItemDialogState extends State<AddTrgovinaItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String _ime = '';
  int _potrebnaKolicina = 0;
  int? _selectedVelicinaId;
  List<Map<String, dynamic>> _velicinaList = [];

  // Inicijalizacija podataka
  // Ako je uređivanje, postavi podatke
  @override
  void initState() {
    super.initState();
    _loadVelicina();
    if (widget.isEditing && widget.item != null) {
      _ime = widget.item!['Ime'];
      _potrebnaKolicina = widget.item!['PotrebnaKolicina'];
      _selectedVelicinaId = widget.item!['IdVelicina'];
    }
  }

  // Učitavanje veličina iz baze podataka
  Future<void> _loadVelicina() async {
    final data = await DatabaseHelper.getAllVelicina();
    setState(() {
      _velicinaList = data;
    });
  }

  // Dodavanje ili uređivanje artikla, ovisno o tome je li uređivanje
  // Ako je uređivanje, ažuriraj postojeći artikl
  // Ako nije uređivanje, dodaj novi artikl
  Future<void> _addTrgovinaItem() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final trgovinaItem = {
        'Ime': _ime,
        'PotrebnaKolicina': _potrebnaKolicina,
        'IdVelicina': _selectedVelicinaId,
      };
      if (widget.isEditing && widget.item != null) {
        trgovinaItem['IdPotrebnogArtikla'] = widget.item!['IdPotrebnogArtikla'];
        await DatabaseHelper.updateTrgovinaItem(trgovinaItem['IdPotrebnogArtikla'] as int, trgovinaItem);
      } else {
        await DatabaseHelper.insertTrgovinaItem(trgovinaItem);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Naslov ovisno o tome je li uređivanje ili dodavanje
      title: Text(widget.isEditing ? 'Uredi Artikl' : 'Dodaj Artikl'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              // Polje za unos ili ažuriranje imena
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
            TextFormField(
              // Polje za unos ili ažuriranje količine
              initialValue: _potrebnaKolicina.toString(),
              decoration: InputDecoration(labelText: 'Potrebna Količina'),
              keyboardType: TextInputType.number,
              onSaved: (value) {
                _potrebnaKolicina = int.parse(value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unesite količinu';
                }
                return null;
              },
            ),
            DropdownButtonFormField<int>(
              // Dropdown za odabir veličine
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
        // Gumbi za odustajanje i dodavanje/uređivanje
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _addTrgovinaItem,
          child: Text(widget.isEditing ? 'Uredi' : 'Dodaj'),
        ),
      ],
    );
  }
}