import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/test_seams.dart';

class _FakeSessionStore implements SessionStore {
  final String? email;
  _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepo implements AppRepository {
  int? userId;
  Object? userIdError;

  List<Map<String, dynamic>> recepti = <Map<String, dynamic>>[];
  Object? receptiError;

  Map<int, bool> missingByRecipe = <int, bool>{};
  Object? missingError;

  @override
  Future<int?> getUserIdByMail(String mail) async {
    if (userIdError != null) throw userIdError!;
    return userId;
  }

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async {
    if (receptiError != null) throw receptiError!;
    return recepti;
  }

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async {
    if (missingError != null) throw missingError!;
    return missingByRecipe;
  }

  // Unused in these tests.
  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async =>
      <Map<String, dynamic>>[];
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceptiPage edge cases', () {
    testWidgets('greska kod missing status ide u error state', (tester) async {
      final repo = _FakeRepo()
        ..userId = 5
        ..recepti = [
          {
            'idRecept': 10,
            'naziv': 'MegaRizoto',
            'autorIme': 'Ana',
            'autorKorisnikId': 5,
          }
        ]
        ..missingError = Exception('missing fail');

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('ana@test.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('missing fail'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('pretraga po autoru vraca recept', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..recepti = [
          {
            'idRecept': 1,
            'naziv': 'Juha',
            'autorIme': 'Marko',
            'autorKorisnikId': 2,
          }
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'marko');
      await tester.pump();

      expect(find.text('Juha'), findsOneWidget);
      expect(find.text('Nema rezultata pretrage.'), findsNothing);
    });

    testWidgets('idRecept <= 0 daje disabled tap na listi', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..recepti = [
          {
            'idRecept': 0,
            'naziv': 'Neotvoriv recept',
            'autorIme': 'Ivo',
            'autorKorisnikId': 1,
          }
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(tile.onTap, isNull);
    });
  });

  group('ReceptDetaljiPage edge cases', () {
    testWidgets('null detalji -> prikazuje "Recept nije pronađen" i retry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 999,
            currentUserId: 1,
            loadReceptDetalji: (_) async => null,
            loadReceptSastojci: (_) async => <Map<String, dynamic>>[],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async =>
            <Map<String, dynamic>>[],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Recept nije pronađen'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('kad nema prijavljenog korisnika ne prikazuje sekciju "Nedostaje"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 2,
            currentUserId: null,
            loadReceptDetalji: (_) async => {
              'idRecept': 2,
              'naziv': 'OmletX',
              'autorIme': 'Ana',
              'autorKorisnikId': 4,
              'vrijemePripreme': 10,
              'opis': 'Opis',
            },
            loadReceptSastojci: (_) async => [
              {'sastojakIme': 'Jaja', 'potrebnaKolicina': 2, 'oznakaVelicine': 'kom'}
            ],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async =>
            <Map<String, dynamic>>[],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nedostaje'), findsNothing);
      expect(find.text('Imaš dovoljno svih sastojaka.'), findsNothing);
    });

    testWidgets('prazan popis sastojaka prikazuje poruku', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 3,
            currentUserId: 1,
            loadReceptDetalji: (_) async => {
              'idRecept': 3,
              'naziv': 'BezSastojaka',
              'autorIme': 'Iva',
              'autorKorisnikId': 9,
              'vrijemePripreme': 15,
              'opis': 'Opis',
            },
            loadReceptSastojci: (_) async => <Map<String, dynamic>>[],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async =>
            <Map<String, dynamic>>[],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nema unesenih sastojaka za ovaj recept.'), findsOneWidget);
    });

    testWidgets('nedostajuci sastojak bez jedinice prikazuje tekst bez suffixa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 4,
            currentUserId: 7,
            loadReceptDetalji: (_) async => {
              'idRecept': 4,
              'naziv': 'TestRecept',
              'autorIme': 'Autor',
              'autorKorisnikId': 99,
              'vrijemePripreme': 20,
              'opis': 'Opis',
            },
            loadReceptSastojci: (_) async => [
              {'sastojakIme': 'Sol', 'potrebnaKolicina': 3, 'oznakaVelicine': ''}
            ],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [
              {
                'sastojakIme': 'Sol',
                'potrebno': 3,
                'dostupno': 1,
                'nedostaje': 2,
                'oznakaVelicine': '',
              }
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Nedostaje: 2 (dostupno: 1, potrebno: 3)'), findsOneWidget);
    });
  });
}
