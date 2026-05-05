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

  static Future<List<Map<String, dynamic>>> getReceptiList() async {
    final rows = await _sql.query('''
    SELECT
      r.idRecept,
      r.naziv,
      r.autorKorisnikId,
      COALESCE(
        NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(k.ime, ''), ' ', ISNULL(k.prezime, '')))), ''),
        k.email,
        'Nepoznato'
      ) AS autorIme
    FROM Recept r
    LEFT JOIN Korisnik k ON k.idKorisnik = r.autorKorisnikId
    ORDER BY r.naziv ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<int> insertReceptForAuthor({
    required int autorKorisnikId,
    required String naziv,
    required String opis,
    required int vrijemePripremeMin,
    required List<Map<String, dynamic>> sastojci,
  }) async {
    final safeNaziv = _sqlEscape(naziv.trim());
    final safeOpis = _sqlEscape(opis.trim());

    if (safeNaziv.isEmpty) {
      throw Exception('Naziv recepta je obavezan.');
    }
    if (vrijemePripremeMin <= 0) {
      throw Exception('Vrijeme pripreme mora biti veće od 0.');
    }
    if (sastojci.isEmpty) {
      throw Exception('Dodaj barem jedan sastojak.');
    }

    final insertSastojciSql = StringBuffer();
    for (final s in sastojci) {
      final idSastojak = int.tryParse(s['idSastojak']?.toString() ?? '');
      final potrebnaKolicina = int.tryParse(s['potrebnaKolicina']?.toString() ?? '');

      if (idSastojak == null || idSastojak <= 0) {
        throw Exception('Neispravan sastojak.');
      }
      if (potrebnaKolicina == null || potrebnaKolicina <= 0) {
        throw Exception('Količina sastojka mora biti > 0.');
      }

      insertSastojciSql.writeln('''
      INSERT INTO ReceptSastojak (idRecept, idSastojak, potrebnaKolicina)
      VALUES (@newId, $idSastojak, $potrebnaKolicina);
    ''');
    }

    final rows = await _sql.query('''
    BEGIN TRY
      BEGIN TRANSACTION;

      INSERT INTO Recept (naziv, opis, vrijemePripreme, autorKorisnikId)
      VALUES ('$safeNaziv', '$safeOpis', $vrijemePripremeMin, $autorKorisnikId);

      DECLARE @newId INT = CAST(SCOPE_IDENTITY() AS INT);

      ${insertSastojciSql.toString()}

      COMMIT TRANSACTION;
      SELECT @newId AS idRecept;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      THROW;
    END CATCH
  ''');

    if (rows.isEmpty) {
      throw Exception('Neuspješno dodavanje recepta.');
    }

    final id = int.tryParse(rows.first['idRecept']?.toString() ?? '');
    if (id == null || id <= 0) {
      throw Exception('Neuspješno dohvaćanje ID-a novog recepta.');
    }

    return id;
  }


  static Future<void> updateReceptByAuthor({
    required int idRecept,
    required int autorKorisnikId,
    required String naziv,
    required String opis,
    required int vrijemePripremeMin,
    required List<Map<String, dynamic>> sastojci,
  }) async {
    final safeNaziv = _sqlEscape(naziv.trim());
    final safeOpis = _sqlEscape(opis.trim());

    if (safeNaziv.isEmpty) {
      throw Exception('Naziv recepta je obavezan.');
    }
    if (vrijemePripremeMin <= 0) {
      throw Exception('Vrijeme pripreme mora biti veće od 0.');
    }
    if (sastojci.isEmpty) {
      throw Exception('Dodaj barem jedan sastojak.');
    }

    final insertSastojciSql = StringBuffer();
    for (final s in sastojci) {
      final idSastojak = int.tryParse(s['idSastojak']?.toString() ?? '');
      final potrebnaKolicina = int.tryParse(s['potrebnaKolicina']?.toString() ?? '');

      if (idSastojak == null || idSastojak <= 0) {
        throw Exception('Neispravan sastojak.');
      }
      if (potrebnaKolicina == null || potrebnaKolicina <= 0) {
        throw Exception('Količina sastojka mora biti > 0.');
      }

      insertSastojciSql.writeln('''
      INSERT INTO ReceptSastojak (idRecept, idSastojak, potrebnaKolicina)
      VALUES ($idRecept, $idSastojak, $potrebnaKolicina);
    ''');
    }

    await _sql.execute('''
    BEGIN TRY
      BEGIN TRANSACTION;

      UPDATE Recept
      SET
        naziv = '$safeNaziv',
        opis = '$safeOpis',
        vrijemePripreme = $vrijemePripremeMin
      WHERE idRecept = $idRecept
        AND autorKorisnikId = $autorKorisnikId;

      IF @@ROWCOUNT = 0
        THROW 51000, 'Nemaš ovlasti za uređivanje ovog recepta ili recept ne postoji.', 1;

      DELETE FROM ReceptSastojak
      WHERE idRecept = $idRecept;

      ${insertSastojciSql.toString()}

      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      THROW;
    END CATCH
  ''');
  }


  static Future<void> deleteReceptByAuthor({
    required int idRecept,
    required int autorKorisnikId,
  }) async {
    await _sql.execute('''
    BEGIN TRY
      BEGIN TRANSACTION;

      IF NOT EXISTS (
        SELECT 1
        FROM Recept
        WHERE idRecept = $idRecept
          AND autorKorisnikId = $autorKorisnikId
      )
      BEGIN
        THROW 51000, 'Nemaš ovlasti za brisanje ovog recepta ili recept ne postoji.', 1;
      END

      DELETE FROM ReceptSastojak
      WHERE idRecept = $idRecept;

      DELETE FROM Recept
      WHERE idRecept = $idRecept
        AND autorKorisnikId = $autorKorisnikId;

      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      THROW;
    END CATCH
  ''');
  }

  static Future<Map<String, dynamic>?> getReceptDetaljiById(int idRecept) async {
    final rows = await _sql.query('''
    SELECT TOP 1
      r.idRecept,
      r.naziv,
      r.opis,
      r.vrijemePripreme,
      r.autorKorisnikId,
      COALESCE(
        NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(k.ime, ''), ' ', ISNULL(k.prezime, '')))), ''),
        k.email,
        'Nepoznato'
      ) AS autorIme
    FROM Recept r
    LEFT JOIN Korisnik k ON k.idKorisnik = r.autorKorisnikId
    WHERE r.idRecept = $idRecept
  ''');

    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  static Future<List<Map<String, dynamic>>> getAllSastojciForRecipeDropdown() async {
    final rows = await _sql.query('''
    SELECT
      s.idSastojak,
      s.ime AS sastojakIme,
      v.oznakaVelicine,
      k.imeKategorije AS kategorijaIme
    FROM Sastojak s
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    LEFT JOIN Kategorija k ON k.idKategorija = s.idKategorija
    ORDER BY
      ISNULL(k.imeKategorije, 'Ostalo') ASC,
      s.ime ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }


  static Future<List<Map<String, dynamic>>> getReceptSastojciByReceptId(
      int idRecept,
      ) async {
    final rows = await _sql.query('''
    SELECT
      rs.idReceptSastojak,
      rs.idRecept,
      rs.idSastojak,
      rs.potrebnaKolicina,
      s.ime AS sastojakIme,
      v.oznakaVelicine
    FROM ReceptSastojak rs
    INNER JOIN Sastojak s ON s.idSastojak = rs.idSastojak
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    WHERE rs.idRecept = $idRecept
    ORDER BY s.ime ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async {
    final rows = await _sql.query('''
    SELECT
      rs.idRecept,
      MAX(CASE
            WHEN ISNULL(z.kolicina, 0) < ISNULL(rs.potrebnaKolicina, 0) THEN 1
            ELSE 0
          END) AS hasMissing
    FROM ReceptSastojak rs
    LEFT JOIN Zaliha z
      ON z.idSastojak = rs.idSastojak
     AND z.idKorisnik = $idKorisnik
    GROUP BY rs.idRecept
  ''');

    final result = <int, bool>{};
    for (final row in rows) {
      final idRecept = int.tryParse(row['idRecept']?.toString() ?? '');
      final hasMissingRaw = int.tryParse(row['hasMissing']?.toString() ?? '0') ?? 0;
      if (idRecept != null && idRecept > 0) {
        result[idRecept] = hasMissingRaw == 1;
      }
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> getMissingSastojciForReceptUser({
    required int idRecept,
    required int idKorisnik,
  }) async {
    final rows = await _sql.query('''
    SELECT
      rs.idSastojak,
      s.ime AS sastojakIme,
      ISNULL(rs.potrebnaKolicina, 0) AS potrebno,
      ISNULL(z.kolicina, 0) AS dostupno,
      (ISNULL(rs.potrebnaKolicina, 0) - ISNULL(z.kolicina, 0)) AS nedostaje,
      v.oznakaVelicine
    FROM ReceptSastojak rs
    INNER JOIN Sastojak s ON s.idSastojak = rs.idSastojak
    LEFT JOIN Velicina v ON v.idVelicina = s.idVelicina
    LEFT JOIN Zaliha z
      ON z.idSastojak = rs.idSastojak
     AND z.idKorisnik = $idKorisnik
    WHERE rs.idRecept = $idRecept
      AND ISNULL(z.kolicina, 0) < ISNULL(rs.potrebnaKolicina, 0)
    ORDER BY s.ime ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }






}
