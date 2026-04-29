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

  static Future<List<Map<String, dynamic>>> getKategorije() async {
    final rows = await _sql.query('''
    SELECT idKategorija, imeKategorije
    FROM Kategorija
    ORDER BY imeKategorije ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<List<Map<String, dynamic>>> getSastojciByKategorija(int idKategorija) async {
    final rows = await _sql.query('''
    SELECT
      s.idSastojak,
      s.ime AS sastojakIme,
      s.idVelicina,
      v.oznakaVelicine
    FROM Sastojak s
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    WHERE s.idKategorija = $idKategorija
    ORDER BY s.ime ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<void> upsertZalihaForUser({
    required int idKorisnik,
    required int idSastojak,
    required int dodatnaKolicina,
    required DateTime datumRoka,
    required int minKolicina,
  }) async {
    if (dodatnaKolicina <= 0) {
      throw Exception('Količina mora biti veća od 0.');
    }
    if (minKolicina < 0) {
      throw Exception('Minimalna količina ne može biti negativna.');
    }

    final y = datumRoka.year.toString().padLeft(4, '0');
    final m = datumRoka.month.toString().padLeft(2, '0');
    final d = datumRoka.day.toString().padLeft(2, '0');
    final safeDatum = '$y-$m-$d';

    await _sql.execute('''
    IF EXISTS (
      SELECT 1
      FROM Zaliha
      WHERE idKorisnik = $idKorisnik
        AND idSastojak = $idSastojak
    )
    BEGIN
      UPDATE Zaliha
      SET
        kolicina = ISNULL(kolicina, 0) + $dodatnaKolicina,
        datum = '$safeDatum',
        [min] = $minKolicina
      WHERE idKorisnik = $idKorisnik
        AND idSastojak = $idSastojak;
    END
    ELSE
    BEGIN
      INSERT INTO Zaliha (idKorisnik, idSastojak, kolicina, datum, [min])
      VALUES ($idKorisnik, $idSastojak, $dodatnaKolicina, '$safeDatum', $minKolicina);
    END
  ''');
  }

  static Future<Map<String, dynamic>?> getZalihaItemForUserSastojak({
    required int idKorisnik,
    required int idSastojak,
  }) async {
    final rows = await _sql.query('''
    SELECT TOP 1
      idZaliha,
      idKorisnik,
      idSastojak,
      kolicina,
      datum,
      [min] AS minKolicina
    FROM Zaliha
    WHERE idKorisnik = $idKorisnik
      AND idSastojak = $idSastojak
  ''');

    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  static Future<void> updateZalihaById({
    required int idZaliha,
    required int idKorisnik,
    required int kolicina,
    required int minKolicina,
    required DateTime datumRoka,
  }) async {
    if (kolicina <= 0) {
      throw Exception('Količina mora biti veća od 0.');
    }
    if (minKolicina < 0) {
      throw Exception('Minimalna količina ne može biti negativna.');
    }

    final y = datumRoka.year.toString().padLeft(4, '0');
    final m = datumRoka.month.toString().padLeft(2, '0');
    final d = datumRoka.day.toString().padLeft(2, '0');
    final safeDatum = '$y-$m-$d';

    await _sql.execute('''
    UPDATE Zaliha
    SET
      kolicina = $kolicina,
      datum = '$safeDatum',
      [min] = $minKolicina
    WHERE idZaliha = $idZaliha
      AND idKorisnik = $idKorisnik
  ''');
  }

  static Future<void> deleteZalihaById({
    required int idZaliha,
    required int idKorisnik,
  }) async {
    await _sql.execute('''
    DELETE FROM Zaliha
    WHERE idZaliha = $idZaliha
      AND idKorisnik = $idKorisnik
  ''');
  }

  static Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(
      int idKorisnik,
      ) async {
    final rows = await _sql.query('''
    SELECT
      st.idStavkaPopisa,
      st.idKorisnik,
      st.sastojakId,
      st.kolicina,
      s.ime AS sastojakIme,
      s.idKategorija,
      s.idVelicina,
      k.imeKategorije AS kategorijaIme,
      v.oznakaVelicine
    FROM StavkaPopisaTrgovina st
    INNER JOIN Sastojak s ON s.idSastojak = st.sastojakId
    LEFT JOIN Kategorija k ON k.idKategorija = s.idKategorija
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    WHERE st.idKorisnik = $idKorisnik
    ORDER BY s.ime ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<void> insertStavkaPopisaTrgovine({
    required int idKorisnik,
    required int idSastojak,
    required int kolicina,
  }) async {
    if (kolicina <= 0) {
      throw Exception('Količina mora biti veća od 0.');
    }

    await _sql.execute('''
    INSERT INTO StavkaPopisaTrgovina (idKorisnik, sastojakId, kolicina)
    VALUES ($idKorisnik, $idSastojak, $kolicina)
  ''');
  }

  static Future<void> deleteStavkaPopisaTrgovineById({
    required int idStavkaPopisa,
    required int idKorisnik,
  }) async {
    print("Brisanje StavkaPopisaTrgovina: idStavkaPopisa=$idStavkaPopisa, idKorisnik=$idKorisnik");
    await _sql.execute('''
    DELETE FROM StavkaPopisaTrgovina
    WHERE idStavkaPopisa = $idStavkaPopisa
      AND idKorisnik = $idKorisnik
  ''');
  }


  static Future<void> updateStavkaPopisaTrgovineKolicina({
    required int idStavkaPopisa,
    required int idKorisnik,
    required int novaKolicina,
  }) async {
    if (novaKolicina <= 0) {
      throw Exception('Količina mora biti veća od 0.');
    }
    print("Update kolicine za StavkaPopisaTrgovina: idStavkaPopisa=$idStavkaPopisa, idKorisnik=$idKorisnik, novaKolicina=$novaKolicina");
    await _sql.execute('''
    UPDATE StavkaPopisaTrgovina
    SET kolicina = $novaKolicina
    WHERE idStavkaPopisa = $idStavkaPopisa
      AND idKorisnik = $idKorisnik
  ''');
  }

  static Future<void> purchaseStavkaPopisaTrgovine({
    required int idKorisnik,
    required int idStavkaPopisa,
    required int idSastojak,
    required int kupljenaKolicina,
    required DateTime datumRoka,
  }) async {
    if (kupljenaKolicina <= 0) {
      throw Exception('Količina mora biti veća od 0.');
    }

    final y = datumRoka.year.toString().padLeft(4, '0');
    final m = datumRoka.month.toString().padLeft(2, '0');
    final d = datumRoka.day.toString().padLeft(2, '0');
    final safeDatum = '$y-$m-$d';

    print("Prebacivanje iz StavkaPopisaTrgovina u Zaliha: idKorisnik=$idKorisnik, idSastojak=$idSastojak, kupljenaKolicina=$kupljenaKolicina, datumRoka=$safeDatum");
    await _sql.execute('''
    BEGIN TRY
      BEGIN TRANSACTION;

      IF EXISTS (
        SELECT 1
        FROM Zaliha
        WHERE idKorisnik = $idKorisnik
          AND idSastojak = $idSastojak
      )
      BEGIN
        UPDATE Zaliha
        SET
          kolicina = ISNULL(kolicina, 0) + $kupljenaKolicina,
          datum = CASE
                    WHEN datum IS NULL THEN '$safeDatum'
                    WHEN '$safeDatum' < datum THEN '$safeDatum'
                    ELSE datum
                  END
        WHERE idKorisnik = $idKorisnik
          AND idSastojak = $idSastojak;
      END
      ELSE
      BEGIN
        INSERT INTO Zaliha (idKorisnik, idSastojak, kolicina, datum, [min])
        VALUES ($idKorisnik, $idSastojak, $kupljenaKolicina, '$safeDatum', 0);
      END

      DELETE FROM StavkaPopisaTrgovina
      WHERE idStavkaPopisa = $idStavkaPopisa
        AND idKorisnik = $idKorisnik;

      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      THROW;
    END CATCH
  ''');
  }




}
