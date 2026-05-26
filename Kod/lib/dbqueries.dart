import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'sql_connection.dart';

/*
Klasa za sve SQL upite prema bazi. Svi upiti su async i vraćaju Future.
Metode su organizirane po funkcionalnosti (korisnici, zalihe, recepti, itd.).
 */

class DbQueries {
  static final SqlConnectionService _sql = SqlConnectionService.instance;

  // Escapira string za SQL literal (' -> '')
  static String _sqlEscape(String value) => value.replaceAll("'", "''");

  static String hashPassword(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return sha256.convert(bytes).toString();
  }

  // Dohvaćanje korisnika po mailu.
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

  // Provjera postoji li korisnik s danim mailom.
  static Future<bool> emailExists(String mail) async {
    final user = await getUserByMail(mail);
    return user != null;
  }

  // Provjera korisničkih kredencijala (mail + plain password).
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

  // Umetanje novog korisnika u bazu.
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

  // Brisanje korisnika po mailu.
  static Future<void> deleteUserByMail(String mail) async {
    final safeMail = _sqlEscape(mail.trim().toLowerCase());

    await _sql.execute('''
    DELETE FROM Korisnik
    WHERE LOWER(CAST(email AS NVARCHAR(255))) = '$safeMail'
  ''');
  }

  // Promjena lozinke korisnika.
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

  // Dohvaćanje ID-a korisnika po mailu.
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

  // Dohvaćanje svih zaliha za određenog korisnika, uključujući i kategoriju i veličinu.
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

  // Dohvaćanje svih mogućih kategorija sastojaka.
  static Future<List<Map<String, dynamic>>> getKategorije() async {
    final rows = await _sql.query('''
    SELECT idKategorija, imeKategorije
    FROM Kategorija
    ORDER BY imeKategorije ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Dohvaćanje svih sastojaka unutar određene kategorije, uključujući i veličinu.
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

  // Dodavanje nove zalihe ili ažuriranje postojeće za određenog korisnika i sastojak.
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

  // Dohvaćanje zalihe za određenog korisnika i sastojak (ako postoji).
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

  // Ažuriranje zalihe po ID.
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

  // Dohvaćanje svih stavki popisa trgovine za određenog korisnika.
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

  // Dodavanje nove stavke u popis trgovine za određenog korisnika.
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

  // Brisanje stavke popisa trgovine po ID i korisniku.
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


  // Ažuriranje količine stavke popisa trgovine po ID i korisniku.
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

  // Simuliranje kupnje stavke i dodavanje u zalihe i zatim brisanje iz popisa trgovine.
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

  // Dohvaćanje svih recepata s imenom autora za prikaz u listi recepata.
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

  // Dodavanje novog recepta s pripadajućim sastojcima.
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

  // Ažuriranje recepta i njegovih sastojaka.
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


  // Brisanje recepta i njegovih sastojaka.
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

  // Dohvaćanje detalja recepta po ID, uključujući ime autora.
  static Future<Map<String, dynamic>?> getReceptDetaljiById(int idRecept) async {
    final rows = await _sql.query('''
    SELECT TOP 1
      r.idRecept,
      r.naziv,
      CAST(r.opis AS NVARCHAR(4000)) AS opis,
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

  // Dohvaćanje svih sastojaka s kategorijom i veličinom za prikaz u dropdownu pri dodavanju sastojaka u recept.
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


  // Dohvaćanje svih sastojaka s imenom i veličinom za određeni recept, za prikaz u detaljima recepta.
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

  // Dohvaćanje informacija o tome koji recepti imaju nedostajuće sastojke za određenog korisnika, vraća mapu idRecept -> bool (true ako nedostaje, false ako ne nedostaje).
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

  // Dohvaćanje nedostajućih sastojaka za određeni recept. 
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

  static String _dateOnlySql(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  // Vraca tipove obroka iz tablice VrstaObroka (dorucak, rucak, vecera)
  static Future<List<Map<String, dynamic>>> getVrsteObroka() async {
    final rows = await _sql.query('''
    SELECT idVrstaObroka, ime
    FROM VrstaObroka
    ORDER BY idVrstaObroka ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }


  /// Dohvat plana obroka za period [od, do], ukljucujuci recept i naziv tipa obroka.
  static Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async {
    final odSql = _dateOnlySql(od);
    final doSql = _dateOnlySql(doDatuma);

    final rows = await _sql.query('''
      SELECT
        p.idPlanObroka,
        p.idKorisnik,
        p.idRecept,
        p.datumObrok,
        p.tipObroka,
        ISNULL(p.odabran, 0) as odabran,
        ISNULL(p.izvrsen, 0) AS izvrsen,
        v.ime AS tipObrokaIme,
        r.naziv AS receptNaziv,
        r.opis AS receptOpis,
        r.vrijemePripreme
      FROM PlanObroka p
      INNER JOIN VrstaObroka v ON v.idVrstaObroka = p.tipObroka
      LEFT JOIN Recept r ON r.idRecept = p.idRecept
      WHERE p.idKorisnik = $idKorisnik
        AND CAST(p.datumObrok AS DATE) BETWEEN '$odSql' AND '$doSql'
      ORDER BY p.datumObrok ASC, p.tipObroka ASC
    ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Upsert plana: za [idKorisnik + datum + tipObroka] postavi recept.
  static Future<void> upsertPlanObroka({
    required int idKorisnik,
    required int idRecept,
    required DateTime datumObrok,
    required int tipObrokaId,
  }) async {
    final datumSql = _dateOnlySql(datumObrok);

    await _sql.execute('''
      IF EXISTS (
        SELECT 1
        FROM PlanObroka
        WHERE idKorisnik = $idKorisnik
          AND CAST(datumObrok AS DATE) = '$datumSql'
          AND tipObroka = $tipObrokaId
      )
      BEGIN
        UPDATE PlanObroka
        SET
          idRecept = $idRecept,
          odabran = 1,
          izvrsen = 0
        WHERE idKorisnik = $idKorisnik
          AND CAST(datumObrok AS DATE) = '$datumSql'
          AND tipObroka = $tipObrokaId;
      END
      ELSE
      BEGIN
        INSERT INTO PlanObroka (idKorisnik, idRecept, datumObrok, tipObroka, odabran, izvrsen)
        VALUES ($idKorisnik, $idRecept, '$datumSql', $tipObrokaId, 1, 0);
      END
    ''');
  }

  /// Oznaci obrok kao napravljen i transakcijski smanji zalihe prema receptu.
  /// Ako nema dovoljno zaliha, baca gresku i NISTA ne mijenja.
  static Future<void> oznaciObrokKaoNapravljen({
    required int idPlanObroka,
    required int idKorisnik,
  }) async {
    await _sql.execute('''
      BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @idRecept INT;
        DECLARE @alreadyDone BIT;
        DECLARE @isSelected BIT;

        SELECT TOP 1
          @idRecept = idRecept,
          @alreadyDone = ISNULL(izvrsen, 0),
          @isSelected = ISNULL(odabran, 0)
        FROM PlanObroka
        WHERE idPlanObroka = $idPlanObroka
          AND idKorisnik = $idKorisnik;

        IF @idRecept IS NULL
          THROW 51010, 'Plan obroka ne postoji za ovog korisnika.', 1;

        IF @alreadyDone = 1
          THROW 51011, 'Obrok je vec oznacen kao napravljen.', 1;
        
        IF @isSelected = 0
          THROW 51013, 'Obrok nije odabran, ne moze se oznaciti kao napravljen.', 1;

        -- Provjera da nijedna stavka ne ode ispod nule
        IF EXISTS (
          SELECT 1
          FROM ReceptSastojak rs
          LEFT JOIN Zaliha z
            ON z.idKorisnik = $idKorisnik
           AND z.idSastojak = rs.idSastojak
          WHERE rs.idRecept = @idRecept
            AND ISNULL(z.kolicina, 0) < ISNULL(rs.potrebnaKolicina, 0)
        )
        BEGIN
          THROW 51012, 'Nema dovoljno zaliha za pripremu ovog obroka.', 1;
        END

        -- Smanji zalihe
        UPDATE z
        SET z.kolicina = z.kolicina - rs.potrebnaKolicina
        FROM Zaliha z
        INNER JOIN ReceptSastojak rs
          ON rs.idSastojak = z.idSastojak
        WHERE z.idKorisnik = $idKorisnik
          AND rs.idRecept = @idRecept;

        -- Oznaci plan kao izvrsen
        UPDATE PlanObroka
        SET
          izvrsen = 1
        WHERE idPlanObroka = $idPlanObroka
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

  /// Brisanje obroka iz plana po id-u (da korisnik može dodati drugi recept).
  static Future<void> deletePlanObrokaById({
    required int idPlanObroka,
    required int idKorisnik,
  }) async {
    await _sql.execute('''
    DELETE FROM PlanObroka
    WHERE idPlanObroka = $idPlanObroka
      AND idKorisnik = $idKorisnik
  ''');
  }

  static Future<List<Map<String, dynamic>>> getMlFeaturesForUserTip({
    required int idKorisnik,
    required int tipObrokaId,
  }) async {
    final rows = await _sql.query('''
    SELECT
      r.idRecept,
      $tipObrokaId AS tipObroka,
      ISNULL(r.vrijemePripreme, 0) AS vrijemePripremeMin,
      ISNULL(uo.userOdabranBefore, 0) AS userOdabranBefore,
      ISNULL(ui.userIzvrsenBefore, 0) AS userIzvrsenBefore,
      ISNULL(ge.globalnoIzvrsenBefore, 0) AS globalnoIzvrsenBefore
    FROM Recept r
    LEFT JOIN (
      SELECT idRecept, COUNT(*) AS userOdabranBefore
      FROM PlanObroka
      WHERE idKorisnik = $idKorisnik AND ISNULL(odabran, 0) = 1
      GROUP BY idRecept
    ) uo ON uo.idRecept = r.idRecept
    LEFT JOIN (
      SELECT idRecept, COUNT(*) AS userIzvrsenBefore
      FROM PlanObroka
      WHERE idKorisnik = $idKorisnik AND ISNULL(izvrsen, 0) = 1
      GROUP BY idRecept
    ) ui ON ui.idRecept = r.idRecept
    LEFT JOIN (
      SELECT idRecept, COUNT(*) AS globalnoIzvrsenBefore
      FROM PlanObroka
      WHERE ISNULL(izvrsen, 0) = 1
      GROUP BY idRecept
    ) ge ON ge.idRecept = r.idRecept
    ORDER BY r.naziv ASC
  ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }








}
