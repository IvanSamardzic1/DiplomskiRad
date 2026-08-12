import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:projekt_prvaverzija/trgovina.dart';

class _FakeSessionStore implements SessionStore {
  final String? email;
  _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepo implements AppRepository {
  int? userId;
  List<Map<String, dynamic>> stavke = <Map<String, dynamic>>[];

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async => stavke;

  // Ne koriste se u ovim testovima, ali su dio sučelja.
  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => <Map<String, dynamic>>[];

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async => <int, bool>{};

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async => <Map<String, dynamic>>[];
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceptDetaljiPage', () {
    testWidgets('success: prikazuje naziv, autora, sastojke i "imas dovoljno"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 1,
            currentUserId: 7,
            loadReceptDetalji: (_) async => {
              'idRecept': 1,
              'naziv': 'Tjestenine',
              'autorIme': 'Ivan',
              'autorKorisnikId': 7,
              'vrijemePripreme': 25,
              'opis': 'Brzi recept',
            },
            loadReceptSastojci: (_) async => [
              {'sastojakIme': 'Tjestenina', 'potrebnaKolicina': 200, 'oznakaVelicine': 'g'},
            ],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Detalji recepta'), findsOneWidget);
      expect(find.text('Tjestenina'), findsOneWidget);
      expect(find.textContaining('Autor: Ivan'), findsOneWidget);
      expect(find.textContaining('Imaš dovoljno svih sastojaka.'), findsOneWidget);
    });

    testWidgets('error -> retry -> success', (tester) async {
      var calls = 0;

      Future<Map<String, dynamic>?> loader(int id) async {
        calls++;
        if (calls == 1) throw Exception('privremena greska');
        return {
          'idRecept': 2,
          'naziv': 'Omlet',
          'autorIme': 'Ana',
          'autorKorisnikId': 99,
          'vrijemePripreme': 10,
          'opis': 'Opis',
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 2,
            currentUserId: 1,
            loadReceptDetalji: loader,
            loadReceptSastojci: (_) async => [],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('privremena greska'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pumpAndSettle();

      expect(find.text('Omlet'), findsOneWidget);
    });

    testWidgets('prikazuje sekciju nedostajucih sastojaka', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 3,
            currentUserId: 5,
            loadReceptDetalji: (_) async => {
              'idRecept': 3,
              'naziv': 'Rizoto',
              'autorIme': 'Pero',
              'autorKorisnikId': 10,
              'vrijemePripreme': 35,
              'opis': 'Opis',
            },
            loadReceptSastojci: (_) async => [
              {'sastojakIme': 'Riza', 'potrebnaKolicina': 150, 'oznakaVelicine': 'g'},
            ],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [
              {
                'sastojakIme': 'Riza',
                'potrebno': 150,
                'dostupno': 20,
                'nedostaje': 130,
                'oznakaVelicine': 'g',
              }
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nedostaje'), findsOneWidget);
      expect(find.textContaining('Nedostaje: 130 g'), findsOneWidget);
    });

    testWidgets('author kontrola: Uredi/Obrisi vidljivo samo autoru', (tester) async {
      Future<Map<String, dynamic>?> detailLoader(int _) async => {
        'idRecept': 4,
        'naziv': 'Salata',
        'autorIme': 'Maja',
        'autorKorisnikId': 42,
        'vrijemePripreme': 8,
        'opis': 'Opis',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 4,
            currentUserId: 42,
            loadReceptDetalji: detailLoader,
            loadReceptSastojci: (_) async => [],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Uredi'), findsOneWidget);
      expect(find.byTooltip('Obriši'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: ReceptDetaljiPage(
            idRecept: 4,
            currentUserId: 7,
            loadReceptDetalji: detailLoader,
            loadReceptSastojci: (_) async => [],
            loadMissingSastojci: ({required idRecept, required idKorisnik}) async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Uredi'), findsNothing);
      expect(find.byTooltip('Obriši'), findsNothing);
    });
  });

  group('TrgovinaPage akcije bez SQL poziva', () {
    testWidgets('kupnja s neispravnim podacima prikazuje gresku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 11,
            'sastojakId': 0, // invalid
            'kolicina': 2,
            'sastojakIme': 'Mlijeko',
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('test@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Označi kao kupljeno'));
      await tester.pumpAndSettle();

      expect(find.text('Greška'), findsOneWidget);
      expect(find.textContaining('Neispravni podaci stavke.'), findsOneWidget);
    });

    testWidgets('uredi s neispravnim ID-om prikazuje gresku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 0, // invalid
            'sastojakId': 10,
            'kolicina': 2,
            'sastojakIme': 'Jabuka',
            'kategorijaIme': 'Voce',
            'oznakaVelicine': 'kom',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('test@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uredi'));
      await tester.pumpAndSettle();

      expect(find.text('Greška'), findsOneWidget);
      expect(find.textContaining('Neispravan ID stavke.'), findsOneWidget);
    });

    testWidgets('obrisi s neispravnim ID-om prikazuje gresku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 0, // invalid
            'sastojakId': 10,
            'kolicina': 1,
            'sastojakIme': 'Sir',
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'g',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('test@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Obriši'));
      await tester.pumpAndSettle();

      expect(find.text('Greška'), findsOneWidget);
      expect(find.textContaining('Neispravan ID stavke.'), findsOneWidget);
    });

    testWidgets('nema korisnika -> error ekran', (tester) async {
      final repo = _FakeRepo();

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore(null),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });
  });
}
