import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'addtrgovinaitem.dart';

class TrgovinaPage extends StatefulWidget {
  @override
  _TrgovinaPageState createState() => _TrgovinaPageState();
}

class _TrgovinaPageState extends State<TrgovinaPage> {
  List<Map<String, dynamic>> _trgovinaList = [];

  @override
  // Inicijalizacija podataka
  void initState() {
    super.initState();
    _loadTrgovina();
  }

  // Učitavanje podataka iz baze
  Future<void> _loadTrgovina() async {
    final data = await DatabaseHelper.getAllTrgovina();
    setState(() {
      _trgovinaList = data;
    });
  }

  // Otvaranje dijaloga za dodavanje artikla
  Future<void> _openAddArtiklDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddTrgovinaItemDialog(),
    );
    _loadTrgovina();
  }

  // Brisanje artikla iz popisa za trgovinu
  Future<void> _deleteTrgovinaItem(int id) async {
    await DatabaseHelper.deleteTrgovinaItem(id);
    _loadTrgovina();
  }

  // Uređivanje artikla iz popisa za trgovinu, odnosno pozivanje
  // dijaloga za uređivanje
  Future<void> _editTrgovinaItem(Map<String, dynamic> item) async {
    await showDialog(
      context: context,
      builder: (context) => AddTrgovinaItemDialog(
        item: item,
        isEditing: true,
      ),
    );
    _loadTrgovina();
  }


  // Dodavanje artikla nakon kupnje u popis namirnica
  Future<void> _addToNamirnice(Map<String, dynamic> item) async {
    final existingNamirnica = await DatabaseHelper.getNamirnicaByName(item['Ime']);
    // Ako postoji artikl u popisu namirnica, ažuriraj količinu namirnice
    if (existingNamirnica != null) {
      await DatabaseHelper.updateNamirnica(existingNamirnica['IdNamirnice'], {
        'Kolicina': existingNamirnica['Kolicina'] + item['PotrebnaKolicina'],
      });
    // Ako ne postoji artikl u popisu namirnica, dodaj tu namirnicu
    } else {
      await DatabaseHelper.insertNamirnica({
        'Ime': item['Ime'],
        'Kolicina': item['PotrebnaKolicina'],
        'IdVelicina': item['IdVelicina'],
      });
    }
    await _deleteTrgovinaItem(item['IdPotrebnogArtikla']);
  }

  @override
  Widget build(BuildContext context) {
    // Prikaz popisa za trgovinu
    return Scaffold(
      appBar: AppBar(
        title: Text('Moj popis za trgovinu'),
      ),
      body: Stack(
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
          Center(
            // Prikaz poruke "Nema artikala" ako nema predviđenih artikala za kupnju
            child: _trgovinaList.isEmpty
                ? Text('Nema artikala',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                  color: Colors.red
              ),
            )
                : ListView.builder(
              itemCount: _trgovinaList.length,
              itemBuilder: (context, index) {
                final item = _trgovinaList[index];
                return Card(
                  // Popis artikala
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListTile(
                    title: Text(item['Ime'].toString()),
                    subtitle: Text('Količina: ${item['PotrebnaKolicina']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gumb za uređivanje artikla
                        IconButton(
                          icon: Icon(Icons.edit,color:Colors.green,),
                          onPressed: () => _editTrgovinaItem(item),
                        ),
                        // Gumb za brisanje artikla
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red,),
                          onPressed: () => _deleteTrgovinaItem(item['IdPotrebnogArtikla']),
                        ),
                        Checkbox(
                          // Checkbox za označavanje kupljenih artikala
                          value: false,
                          onChanged: (bool? value) async {
                            if (value == true) {
                              final confirmed = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Potvrda'),
                                  // Potvrda kupnje artikla
                                  content: Text('Jeste li sigurno kupili ovaj artikl?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Ne'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Da'),
                                    ),
                                  ],
                                ),
                              );
                              // Dodavanje artikla u popis namirnica ako je odgovor potvrdan
                              if (confirmed == true) {
                                await _addToNamirnice(item);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Gumb za dodavanje novog artikla
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddArtiklDialog,
        child: Icon(Icons.add),
      ),
    );
  }


}