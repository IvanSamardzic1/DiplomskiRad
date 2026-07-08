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
  });
}
