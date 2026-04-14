import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  static Database? _databaseSecond;
  static const String _databaseName = "bazadrugaverzija.db";
  static const String _databasePath = "assets/bazadrugaverzija.db";

  // Funkcija koja vraća instancu baze
  static Future<Database> getDatabase() async {
    if (_databaseSecond != null) {
      return _databaseSecond!; // Ako već postoji baza, vrati je
    } else {
      _databaseSecond = await _initDatabase();  // Inicijaliziraj bazu
      return _databaseSecond!;
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

  // SHA-256 hash lozinke .
  static String hashPassword(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return sha256.convert(bytes).toString();
  }

  // Funkcija za dohvaćanje korisnika po emailu
  static Future<Map<String, dynamic>?> getUserByMail(String mail) async {
    final db = await getDatabase();
    // Koristimo LOWER() funkciju u SQL upitu kako bismo osigurali da je pretraga neosjetljiva na velika i mala slova
    final result = await db.query(
      "Korisnik",
      where: 'LOWER(email) = ?',
      whereArgs: [mail.toLowerCase().trim()],
      limit: 1,
    );
    if (result.isEmpty) return null;
    print("Pronađeni korisnik: ${result.first}");
    return result.first;
  }

  static Future<bool> emailExists(String mail) async {
    final user = await getUserByMail(mail);
    return user != null;
  }

  static Future<bool> checkUserCredentials(String mail, String plainPassword) async {
    final user = await getUserByMail(mail);
    if (user == null) return false;

    final String storedHash = (user['lozinkaHash'] ?? '').toString();
    final String inputHash = hashPassword(plainPassword);
    return storedHash == inputHash;
  }

  static Future<void> insertUser({
    required String ime,
    required String prezime,
    required String mail,
    required String plainPassword,
  }) async {
    final db = await getDatabase();

    await db.insert("Korisnik", {
      'email': mail.trim().toLowerCase(),
      'lozinkaHash': hashPassword(plainPassword),
      'ime': ime.trim(),
      'prezime': prezime.trim(),
    });
    print("Dodao korisnika, argumenti: ime=$ime, prezime=$prezime, mail=$mail");
  }
}
