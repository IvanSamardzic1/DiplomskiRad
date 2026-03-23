import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = "projektnabaza.db";
  static const String _databasePath = "assets/projektnabaza.db";

  // Funkcija koja vraća instancu baze
  static Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!; // Ako već postoji baza, vrati je
    } else {
      _database = await _initDatabase();  // Inicijaliziraj bazu
      return _database!;
    }
  }

  // Funkcija za inicijalizaciju baze
  static Future<Database> _initDatabase() async {
    // Dohvaćanje putanje do lokalnog direktorija aplikacije
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = "${directory.path}/$_databaseName";

    // Ako baza već postoji, samo je otvori
    if (await File(dbPath).exists()) {
      return await openDatabase(dbPath);
    } else {
      // Ako baza ne postoji, kopiraj je iz assets u lokalni direktorij
      await _copyDatabaseFromAssets(dbPath);
      return await openDatabase(dbPath);
    }
  }

  // Funkcija koja kopira bazu iz assets u lokalni direktorij
  static Future<void> _copyDatabaseFromAssets(String dbPath) async {
    // Uzmi bazu iz assets mape
    final ByteData data = await rootBundle.load(_databasePath);
    final List<int> bytes = data.buffer.asUint8List();

    // Kreiraj mapu i upiši podatke iz assets
    final File file = File(dbPath);
    await file.writeAsBytes(bytes);
    print("Database copied to: $dbPath");
  }

  // Funkcija koja vraća sve podatke iz tablice "Velicina"
  static Future<List<Map<String, dynamic>>> getAllVelicina() async {
    final db = await getDatabase();
    return await db.query('Velicina');
  }

  // Funkcija koja vraća sve podatke iz tablice "Namirnice"
  static Future<List<Map<String, dynamic>>> getAllNamirnice() async {
    final db = await getDatabase();
    return await db.query('Namirnice');
  }

  // Funkcija za dodavanje nove namirnice u bazu u tablicu "Namirnice"
  static Future<void> insertNamirnica(Map<String, dynamic> namirnica) async {
    final db = await getDatabase();
    print(namirnica);
    await db.insert('Namirnice', namirnica);
  }

  // Funkcija za brisanje namirnice iz baze
  static Future<void> deleteNamirnica(int id) async {
    final db = await getDatabase();
    await db.delete('Namirnice', where: 'IdNamirnice = ?' , whereArgs: [id]);
  }

  // Funkcija za ažuriranje podataka o namirnici
  static Future<void> updateNamirnica(int id, Map<String, dynamic> namirnica) async {
    final db = await getDatabase();
    await db.update('Namirnice', namirnica, where: 'IdNamirnice = ?', whereArgs: [id]);
  }

  // Funkcija za dodavanje novog obroka u bazu
  static Future<void> insertObrok(Map<String, dynamic> obrok) async {
    final db = await getDatabase();
    await db.insert('PlanObroka', obrok);
  }

  // Funkcija za dohvaćanje svih obroka iz baze
  static Future<List<Map<String, dynamic>>> getAllObroci() async {
    final db = await getDatabase();
    return await db.query('PlanObroka');
  }

  // Funkcija koja vraća imena svih namirnica iz baze
  static Future<Map<int, String>> getNamirniceNames() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.query('Namirnice', columns: ['IdNamirnice', 'Ime']);
    return {for (var item in result) item['IdNamirnice']: item['Ime']};
  }

  // Funkcija za brisanje obroka iz baze
  static Future<void> deleteObrok(int id) async {
    final db = await getDatabase();
    await db.delete('PlanObroka', where: 'IdObrok = ?', whereArgs: [id]);
  }

  // Funkcija za dodavanje novog artikla u trgovinu u bazu
  static Future<void> insertTrgovinaItem(Map<String, dynamic> item) async {
    final db = await getDatabase();
    await db.insert('Trgovina', item);
  }

  // Funkcija koja vraća sve artikle iz trgovine iz baze
  static Future<List<Map<String, dynamic>>> getAllTrgovina() async {
    final db = await getDatabase();
    return await db.query('Trgovina');
  }

  // Funkcija za brisanje artikla iz trgovine iz baze
  static Future<void> deleteTrgovinaItem(int id) async {
    print(id);
    final db = await getDatabase();
    await db.delete('Trgovina', where: 'IdPotrebnogArtikla = ?', whereArgs: [id]);
  }

  // Funkcija koja vraća namirnicu po imenu iz baze,
  // Koristi se pri checkiranju kupnje namirnice
  static Future<Map<String, dynamic>?> getNamirnicaByName(String ime) async {
    final db = await getDatabase();
    final result = await db.query(
      'Namirnice',
      where: 'LOWER(Ime) = ?',
      whereArgs: [ime.toLowerCase()],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Funkcija za ažuriranje podataka o artiklu u trgovini
  static Future<void> updateTrgovinaItem(int id, Map<String, dynamic> item) async {
    final db = await getDatabase();
    await db.update('Trgovina', item, where: 'IdPotrebnogArtikla = ?', whereArgs: [id]);
  }
}
