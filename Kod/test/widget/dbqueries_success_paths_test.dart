import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:projekt_prvaverzija/trgovina.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';

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

  List<Map<String, dynamic>> stavke = <Map<String, dynamic>>[];
  Object? stavkeError;

  List<Map<String, dynamic>> zalihe = <Map<String, dynamic>>[];
  Object? zaliheError;

  List<Map<String, dynamic>> vrsteObroka = <Map<String, dynamic>>[];
  Object? vrsteError;

  List<Map<String, dynamic>> planRows = <Map<String, dynamic>>[];
  Object? planError;

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

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async {
    if (stavkeError != null) throw stavkeError!;
    return stavke;
  }

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async {
    if (zaliheError != null) throw zaliheError!;
    return zalihe;
  }

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async {
    if (vrsteError != null) throw vrsteError!;
    return vrsteObroka;
  }

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async {
    if (planError != null) throw planError!;
    return planRows;
  }
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceptiPage extra branches', () {
    testWidgets('autor vidi Uredi i Obrisi tipke', (tester) async {
      final repo = _FakeRepo()
        ..userId = 7
        ..recepti = [
          {
            'idRecept': 11,
            'naziv': 'Grah',
            'autorIme': 'Ivan',
            'autorKorisnikId': 7,
          }
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('ivan@test.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Uredi'), findsOneWidget);
      expect(find.byTooltip('Obriši'), findsOneWidget);
    });

    testWidgets('ne-autor ne vidi Uredi i Obrisi tipke', (tester) async {
      final repo = _FakeRepo()
        ..userId = 7
        ..recepti = [
          {
            'idRecept': 11,
            'naziv': 'Grah',
            'autorIme': 'Ivan',
            'autorKorisnikId': 9,
          }
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('ivan@test.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Uredi'), findsNothing);
      expect(find.byTooltip('Obriši'), findsNothing);
    });

    testWidgets('clear search vraca listu nakon praznog rezultata', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..recepti = [
          {
            'idRecept': 1,
            'naziv': 'Piletina',
            'autorIme': 'Ivan',
            'autorKorisnikId': 1,
          }
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('ivan@test.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ne-postoji');
      await tester.pump();
      expect(find.text('Nema rezultata pretrage.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('Piletina'), findsOneWidget);
      expect(find.text('Nema rezultata pretrage.'), findsNothing);
    });

    testWidgets('retry nakon greske ponovno ucitava listu', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..receptiError = Exception('privremena greska');

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('ivan@test.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('privremena greska'), findsOneWidget);

      repo
        ..receptiError = null
        ..recepti = [
          {
            'idRecept': 2,
            'naziv': 'Omlet',
            'autorIme': 'Ana',
            'autorKorisnikId': 2,
          }
        ];

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pumpAndSettle();

      expect(find.text('Omlet'), findsOneWidget);
    });
  });

  group('TrgovinaPage extra branches', () {
    testWidgets('tap na Uredi otvara dialog i Odustani ga zatvara', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 10,
            'sastojakId': 5,
            'sastojakIme': 'Mlijeko',
            'kolicina': 2,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uredi'));
      await tester.pumpAndSettle();

      expect(find.text('Uredi količinu'), findsOneWidget);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Uredi količinu'), findsNothing);
    });

    testWidgets('tap na Obrisi otvara confirm dialog i Odustani ga zatvara', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 10,
            'sastojakId': 5,
            'sastojakIme': 'Mlijeko',
            'kolicina': 2,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Obriši'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda brisanja'), findsOneWidget);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda brisanja'), findsNothing);
    });

    testWidgets('tap na Oznaci kao kupljeno otvara purchase dialog i Odustani ga zatvara', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 10,
            'sastojakId': 5,
            'sastojakIme': 'Mlijeko',
            'kolicina': 2,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Označi kao kupljeno'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda kupnje'), findsOneWidget);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda kupnje'), findsNothing);
    });

    testWidgets('Uredi kolicinu: neispravan unos prikazuje validacijsku poruku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..stavke = [
          {
            'idStavkaPopisa': 10,
            'sastojakId': 5,
            'sastojakIme': 'Mlijeko',
            'kolicina': 2,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
          }
        ];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uredi'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Spremi'));
      await tester.pump();

      expect(find.text('Količina mora biti cijeli broj > 0.'), findsOneWidget);
    });
  });

  group('ZalihaNamirnicePage extra branches', () {

    testWidgets('retry nakon greske ponovno ucitava zalihe', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zaliheError = Exception('privremena greska');

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('privremena greska'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);

      repo
        ..zaliheError = null
        ..zalihe = [
          {
            'idZaliha': 22,
            'sastojakIme': 'Meso',
            'kolicina': 4,
            'minKolicina': 1,
            'kategorijaIme': 'Proteini',
            'oznakaVelicine': 'g',
            'datum': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          }
        ];

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pumpAndSettle();

      expect(find.text('Meso'), findsOneWidget);
    });

    testWidgets('invalidan idZaliha ne otvara dialog za brisanje', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 0, // early return grana
            'sastojakIme': 'Paprika',
            'kolicina': 2,
            'minKolicina': 1,
            'kategorijaIme': 'Povrce',
            'oznakaVelicine': 'kom',
            'datum': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Obriši'));
      await tester.pump();

      expect(find.text('Potvrda brisanja'), findsNothing);
    });

    testWidgets('neparsabilan datum prikazuje se kao raw string', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 30,
            'sastojakIme': 'Brasno',
            'kolicina': 5,
            'minKolicina': 1,
            'kategorijaIme': 'Ugljikohidrati',
            'oznakaVelicine': 'g',
            'datum': 'nije-datum',
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rok trajanja: nije-datum'), findsOneWidget);
      expect(find.text('Rok je istekao'), findsNothing);
      expect(find.text('Rok trajanja uskoro ističe'), findsNothing);
    });

    testWidgets('null datum prikazuje crtu', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 31,
            'sastojakIme': 'Sol',
            'kolicina': 1,
            'minKolicina': 0,
            'kategorijaIme': 'Zacini',
            'oznakaVelicine': 'g',
            'datum': null,
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rok trajanja: -'), findsOneWidget);
    });

    testWidgets('kolicina jednaka minimalnoj prikazuje upozorenje i warning ikonu', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 32,
            'sastojakIme': 'Jaja',
            'kolicina': 2,
            'minKolicina': 2, // <= min grana
            'kategorijaIme': 'Proteini',
            'oznakaVelicine': 'kom',
            'datum': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('Upozorenje: ispod minimalne količine (2)'), findsOneWidget);
    });

    testWidgets('Uredi dialog validacija: kolicina mora biti > 0', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 40,
            'sastojakIme': 'Mlijeko',
            'kolicina': 3,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'L',
            'datum': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uredi'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '0'); // Količina
      await tester.tap(find.text('Spremi'));
      await tester.pump();

      expect(find.text('Mora biti više od 0'), findsOneWidget);
    });

    testWidgets('Uredi dialog validacija: minimalna kolicina ne moze biti negativna', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 41,
            'sastojakIme': 'Jogurt',
            'kolicina': 3,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'kom',
            'datum': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uredi'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '3');   // Količina validna
      await tester.enterText(fields.at(1), '-1');  // Minimalna količina invalidna
      await tester.tap(find.text('Spremi'));
      await tester.pump();

      expect(find.text('Ne može biti negativno'), findsOneWidget);
    });

    testWidgets('validan item otvara delete confirm i Odustani ga zatvara', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 2,
            'sastojakIme': 'Sir',
            'kolicina': 2,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'g',
            'datum': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Obriši'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda brisanja'), findsOneWidget);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrda brisanja'), findsNothing);
    });

    testWidgets('za daleki buduci datum nema upozorenja o roku', (tester) async {
      final farFuture = DateTime.now().add(const Duration(days: 30)).toIso8601String();
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 3,
            'sastojakIme': 'Tjestenina',
            'kolicina': 5,
            'minKolicina': 1,
            'kategorijaIme': 'Ugljikohidrati',
            'oznakaVelicine': 'g',
            'datum': farFuture,
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rok je istekao'), findsNothing);
      expect(find.text('Rok trajanja uskoro ističe'), findsNothing);
    });
  });
}
