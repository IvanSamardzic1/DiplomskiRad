import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'addnamirnice.dart';

class NamirnicePage extends StatefulWidget {
  @override
  _NamirnicePageState createState() => _NamirnicePageState();
}

class _NamirnicePageState extends State<NamirnicePage> {
  // Lista namirnica i veličina
  List<Map<String, dynamic>> _namirniceList = [];
  List<Map<String, dynamic>> _velicinaList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Dohvaćanje podataka iz baze
  Future<void> _loadData() async {
    final namirniceData = await DatabaseHelper.getAllNamirnice();
    final velicinaData = await DatabaseHelper.getAllVelicina();
    setState(() {
      _namirniceList = namirniceData;
      _velicinaList = velicinaData;
    });
  }

  // Otvaranje dijaloga za dodavanje namirnice
  Future<void> _openAddNamirnicaDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddNamirnicaDialog(),
    );
    _loadData();
  }

  // Brisanje namirnice
  Future<void> _deleteNamirnica(int id) async {
    await DatabaseHelper.deleteNamirnica(id);
    _loadData();
  }

  // Otvaranje dijaloga za uređivanje namirnice, s predanim podacima
  Future<void> _openEditNamirnicaDialog(Map<String, dynamic> namirnica) async {
    await showDialog(
      context: context,
      builder: (context) => AddNamirnicaDialog(namirnica: namirnica),
    );
    _loadData();
  }

  // Dohvaćanje naziva veličine prema ID-u
  String _getVelicinaName(int idVelicina) {
    final velicina = _velicinaList.firstWhere((element) => element['IdVelicina'] == idVelicina);
    return velicina['VrstaVelicine'];
  }

  @override
  // Prikaz liste namirnica
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Moje namirnice'),
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
            child: _namirniceList.isEmpty
                ? Text(
              //Ako nema namirnica, treba biti prikazana poruka "Zasad nema namirnica."
              'Zasad nema namirnica.',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            )
                : ListView.builder(
              itemCount: _namirniceList.length,
              itemBuilder: (context, index) {
                final item = _namirniceList[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListTile(
                    leading: Icon(Icons.circle, size: 10.0, color: Colors.blue),
                    title: Text(item['Ime'].toString()),
                    //Ako je količina 0, poruka "Nema više, kupi! treba biti prikazana
                    subtitle: item['Kolicina'] == 0
                        ? Text(
                      'Nema više, kupi!',
                      style: TextStyle(color: Colors.red),
                    )
                        : Text('Količina: ${item['Kolicina']} ${_getVelicinaName(item['IdVelicina'])}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        //Gumbi za uređivanje i brisanje namirnice
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _openEditNamirnicaDialog(item),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNamirnica(item['IdNamirnice']),
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
      //Gumb za dodavanje namirnice
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddNamirnicaDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}