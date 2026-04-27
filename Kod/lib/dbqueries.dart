import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'sql_connection.dart';

class DbQueries {
  static final SqlConnectionService _sql = SqlConnectionService.instance;

  // Escapira string za SQL literal (' -> '')
  static String _sqlEscape(String value) => value.replaceAll("'", "''");

  static String hashPassword(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return sha256.convert(bytes).toString();
  }

  // Korisnik po mailu (case-insensitive)
  static Future<Map<String, dynamic>?> getUserByMail(String mail) async {
    final normalizedMail = mail.trim().toLowerCase();
    final safeMail = _sqlEscape(normalizedMail);

    final rows = await _sql.query('''
      SELECT TOP 1 email, lozinkaHash, ime, prezime
      FROM Korisnik
      WHERE LOWER(email) = '$safeMail'
     ''');

    if (rows.isEmpty) return null;

    final row = rows.first;
    return {
      'email': row['email']?.toString() ?? '',
      'lozinkaHash': row['lozinkaHash']?.toString() ?? '',
      'ime': row['ime']?.toString() ?? '',
      'prezime': row['prezime']?.toString() ?? '',
    };

  }

  static Future<bool> emailExists(String mail) async {
    final user = await getUserByMail(mail);
    return user != null;
  }

  static Future<bool> checkUserCredentials(
      String mail,
      String plainPassword,
      ) async {
    final user = await getUserByMail(mail);
    if (user == null) return false;

    final storedHash = (user['lozinkaHash'] ?? '').toString();
    final inputHash = hashPassword(plainPassword);
    print("Provjera lozinke: inputHash=$inputHash, storedHash=$storedHash");
    return storedHash == inputHash;
  }

  static Future<void> insertUser({
    required String ime,
    required String prezime,
    required String mail,
    required String plainPassword,
  }) async {
    final safeIme = _sqlEscape(ime.trim());
    final safePrezime = _sqlEscape(prezime.trim());
    final safeMail = _sqlEscape(mail.trim().toLowerCase());
    final passwordHash = hashPassword(plainPassword);

    await _sql.execute('''
      INSERT INTO Korisnik (email, lozinkaHash, ime, prezime)
      VALUES ('$safeMail', '$passwordHash', '$safeIme', '$safePrezime')
      ''');
  }

  static Future<void> deleteUserByMail(String mail) async {
    final safeMail = _sqlEscape(mail.trim().toLowerCase());

    await _sql.execute('''
    DELETE FROM Korisnik
    WHERE LOWER(CAST(email AS NVARCHAR(255))) = '$safeMail'
  ''');
  }

  static Future<void> changePassword({
    required String mail,
    required String newPlainPassword,
  }) async {
    final safeMail = _sqlEscape(mail.trim().toLowerCase());
    final newHash = hashPassword(newPlainPassword);

    await _sql.execute('''
    UPDATE Korisnik
    SET lozinkaHash = '$newHash'
    WHERE LOWER(email) = '$safeMail'
  ''');
  }

  static Future<int?> getUserIdByMail(String mail) async {
    final safeMail = _sqlEscape(mail.trim().toLowerCase());

    final rows = await _sql.query('''
    SELECT TOP 1 idKorisnik
    FROM Korisnik
    WHERE LOWER(email) = '$safeMail'
  ''');

    if (rows.isEmpty) return null;
    final raw = rows.first['idKorisnik'];
    print("Id korisnika za mail '$mail' je: $raw");
    return int.tryParse(raw?.toString() ?? '');
  }

  static Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async {
    final rows = await _sql.query('''
    SELECT
      z.idZaliha,
      z.idKorisnik,
      z.idSastojak,
      z.kolicina,
      z.datum,
      z.[min] AS minKolicina,
      s.ime AS sastojakIme,
      s.idKategorija,
      s.idVelicina,
      v.oznakaVelicine,
      k.imeKategorije AS kategorijaIme
    FROM Zaliha z
    INNER JOIN Sastojak s ON s.idSastojak = z.idSastojak
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    LEFT JOIN Kategorija k ON k.idKategorija = s.idKategorija
    WHERE z.idKorisnik = $idKorisnik
    ORDER BY z.datum ASC, s.ime ASC
  ''');

    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }


}
