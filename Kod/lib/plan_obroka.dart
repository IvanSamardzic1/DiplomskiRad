import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'addobrok.dart';

class PlanObrokaPage extends StatefulWidget {
  @override
  _PlanObrokaPageState createState() => _PlanObrokaPageState();
}

class _PlanObrokaPageState extends State<PlanObrokaPage> {
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedObroci = {};
  Map<int, String> _namirniceNames = {};
  // Liste dana u tjednu i obroka
  final List<String> _daysOfWeek = ['Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak', 'Petak', 'Subota', 'Nedjelja'];
  final List<String> _meals = ['Dorucak', 'Dopodnevna uzina', 'Rucak', 'Popodnevna uzina', 'Vecera'];


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Učitavanje podataka iz baze za namirnice i obroke
  Future<void> _loadData() async {
    final namirniceNames = await DatabaseHelper.getNamirniceNames();
    final obrociData = await DatabaseHelper.getAllObroci();
    setState(() {
      _namirniceNames = namirniceNames;
      _groupedObroci = _groupByDayAndMeal(obrociData);
    });
  }

  // Grupiranje obroka po danima i obrocima
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupByDayAndMeal(List<Map<String, dynamic>> obroci) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> groupedData = {};
    for (var day in _daysOfWeek) {
      groupedData[day] = {};
      for (var meal in _meals) {
        groupedData[day]![meal] = [];
      }
    }
    for (var obrok in obroci) {
      final day = obrok['Dan'];
      final meal = obrok['Obrok'];
      groupedData[day]![meal]!.add(obrok);
    }
    return groupedData;
  }

  // Otvaranje dijaloga za dodavanje obroka
  Future<void> _openAddObrokDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddObrokDialog(),
    );
    _loadData(); // Učitavanje podataka nakon dodavanja obroka
  }

  //Vraćanje količine namirnica u bazu ako korisnik odustane od te namirnice u obroku
  Future<void> _returnKolicinaToNamirnice(int idNamirnice, int kolicina) async {
    final namirnica = await DatabaseHelper.getNamirnicaByName(_namirniceNames[idNamirnice]!);
    if (namirnica != null) {
      final updatedKolicina = namirnica['Kolicina'] + kolicina;
      await DatabaseHelper.updateNamirnica(idNamirnice, {'Kolicina': updatedKolicina});
    }
  }

  // Brisanje obroka iz baze
  Future<void> _deleteObrok(int id) async {
    await DatabaseHelper.deleteObrok(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plan obroka za ovaj tjedan'),
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
          ListView(
            // Prikaz obroka po danima i obrocima
            // Prikaz dana u tjednu
            children: _daysOfWeek.map((day) {
              return ExpansionTile(
                title: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                    color: Colors.blue,
                  ),
                ),
                // Prikaz svih obroka u danu
                children: _meals.map((meal) {
                  final obroci = _groupedObroci[day]?[meal] ?? [];
                  return ExpansionTile(
                    title: Text(
                      meal,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                        color: Colors.black,
                      ),
                    ),
                    // Prikaz namirnica za svaki obrok
                    // Ako nema isplanirano za taj obrok, prikazuje se poruka "Nema isplaniranih namirnica za ovaj obrok."
                    children: obroci.isEmpty
                        ? [ListTile(title: Text('Nema isplaniranih namirnica za ovaj obrok.'))]
                        : obroci.map((obrok) {
                      final namirnicaName = _namirniceNames[obrok['IdNamirnice']] ?? 'Nepoznata namirnica';
                      // Prikaz namirnica za obrok
                      return ListTile(
                        title: Text(namirnicaName),
                        subtitle: Text('Količina: ${obrok['Kolicina']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Undo i delete ikone
                            // Undo vraća namirnice(količinu) u popis namirnica
                            IconButton(
                              icon: Icon(Icons.undo, color: Colors.green),
                              onPressed: () async {
                                await _returnKolicinaToNamirnice(obrok['IdNamirnice'], obrok['Kolicina']);
                                await _deleteObrok(obrok['IdObrok']);
                                _loadData();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _deleteObrok(obrok['IdObrok']);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ],
      ),
      // Gumb za dodavanje obroka
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddObrokDialog,
        child: Icon(Icons.add),
      ),
    );
  }


}