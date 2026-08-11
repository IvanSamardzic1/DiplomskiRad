import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';

void main() {
  group('DbQueries.hashPassword', () {
    test('isti input daje isti hash duljine 64', () {
      final a = DbQueries.hashPassword('test123');
      final b = DbQueries.hashPassword('test123');

      expect(a, b);
      expect(a.length, 64);
    });

    test('razliciti input daje razliciti hash', () {
      final a = DbQueries.hashPassword('abc');
      final b = DbQueries.hashPassword('abcd');

      expect(a, isNot(b));
    });

    test('prazan string daje valjani hash duljine 64', () {
      final hash = DbQueries.hashPassword('');

      expect(hash.length, 64);
      expect(hash, DbQueries.hashPassword(''));
    });

    test('jako dugi string daje valjani hash duljine 64', () {
      final longInput = 'a' * 10000;
      final hash = DbQueries.hashPassword(longInput);

      expect(hash.length, 64);
      expect(hash, DbQueries.hashPassword(longInput));
    });

    test('Unicode/hrvatski znakovi daju konzistentan i ispravan hash', () {
      const password = 'lozinkaČćžšđ123!@#';
      final a = DbQueries.hashPassword(password);
      final b = DbQueries.hashPassword(password);

      expect(a, b);
      expect(a.length, 64);
      // Razlicit unicode string mora dati drugaciji hash.
      expect(a, isNot(DbQueries.hashPassword('lozinkaČćžšđ124!@#')));
    });
  });

  group('DbQueries validacije prije SQL poziva', () {
    test('upsertZalihaForUser baca gresku za dodatnaKolicina <= 0', () async {
      await expectLater(
        DbQueries.upsertZalihaForUser(
          idKorisnik: 1,
          idSastojak: 1,
          dodatnaKolicina: 0,
          datumRoka: DateTime(2026, 1, 1),
          minKolicina: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('upsertZalihaForUser baca gresku za minKolicina < 0', () async {
      await expectLater(
        DbQueries.upsertZalihaForUser(
          idKorisnik: 1,
          idSastojak: 1,
          dodatnaKolicina: 5,
          datumRoka: DateTime(2026, 1, 1),
          minKolicina: -1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateZalihaById baca gresku za kolicina <= 0', () async {
      await expectLater(
        DbQueries.updateZalihaById(
          idZaliha: 1,
          idKorisnik: 1,
          kolicina: 0,
          minKolicina: 0,
          datumRoka: DateTime(2026, 1, 1),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateZalihaById baca gresku za minKolicina < 0', () async {
      await expectLater(
        DbQueries.updateZalihaById(
          idZaliha: 1,
          idKorisnik: 1,
          kolicina: 2,
          minKolicina: -1,
          datumRoka: DateTime(2026, 1, 1),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertStavkaPopisaTrgovine baca gresku za kolicina <= 0', () async {
      await expectLater(
        DbQueries.insertStavkaPopisaTrgovine(
          idKorisnik: 1,
          idSastojak: 1,
          kolicina: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateStavkaPopisaTrgovineKolicina baca gresku za novaKolicina <= 0', () async {
      await expectLater(
        DbQueries.updateStavkaPopisaTrgovineKolicina(
          idStavkaPopisa: 1,
          idKorisnik: 1,
          novaKolicina: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('purchaseStavkaPopisaTrgovine baca gresku za kupljenaKolicina <= 0', () async {
      await expectLater(
        DbQueries.purchaseStavkaPopisaTrgovine(
          idKorisnik: 1,
          idStavkaPopisa: 1,
          idSastojak: 1,
          kupljenaKolicina: 0,
          datumRoka: DateTime(2026, 1, 1),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku kad je naziv prazan', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: '   ',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku kad je vrijeme <= 0', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 0,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku kad nema sastojaka', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku za idSastojak == null', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': null, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku za idSastojak <= 0', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 0, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku za potrebnaKolicina == null', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': null}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('insertReceptForAuthor baca gresku za potrebnaKolicina <= 0', () async {
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': 0}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku kad je naziv prazan', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: '   ',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku kad je vrijeme <= 0', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 0,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku kad nema sastojaka', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku za idSastojak == null', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': null, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku za idSastojak <= 0', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': -1, 'potrebnaKolicina': 1}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku za potrebnaKolicina == null', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': null}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor baca gresku za potrebnaKolicina <= 0', () async {
      await expectLater(
        DbQueries.updateReceptByAuthor(
          idRecept: 1,
          autorKorisnikId: 1,
          naziv: 'Test recept',
          opis: 'opis',
          vrijemePripremeMin: 10,
          sastojci: const [
            {'idSastojak': 1, 'potrebnaKolicina': -5}
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
