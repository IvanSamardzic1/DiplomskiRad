import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projekt_prvaverzija/plan_prehrane.dart';
import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:projekt_prvaverzija/trgovina.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';

class FakeSessionStore implements SessionStore {
  final String? email;

  FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class FakeAppRepository implements AppRepository {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget _host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ReceptiPage states', () {
    testWidgets('prikazuje listu i autora', (tester) async {
      final repo = FakeAppRepository()
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
            sessionStore: FakeSessionStore('ivan@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Svi recepti'), findsOneWidget);
      expect(find.text('Piletina'), findsOneWidget);
      expect(find.textContaining('Autor: Ivan'), findsOneWidget);
    });

    testWidgets('pretraga bez rezultata prikazuje poruku', (tester) async {
      final repo = FakeAppRepository()
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
            sessionStore: FakeSessionStore('ivan@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'xyz-ne-postoji');
      await tester.pump();

      expect(find.text('Nema rezultata pretrage.'), findsOneWidget);
    });

    testWidgets('greska iz repozitorija prikazuje retry', (tester) async {
      final repo = FakeAppRepository()..receptiError = Exception('boom');

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: FakeSessionStore('ivan@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('prikazuje nedostajuce sastojke kada repository vrati missing status', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 1
        ..recepti = [
          {
            'idRecept': 5,
            'naziv': 'Varivo',
            'autorIme': 'Ivana',
            'autorKorisnikId': 2,
          }
        ]
        ..missingByRecipe = {5: true};

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: FakeSessionStore('ivan@mail.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Nedostaju sastojci'), findsOneWidget);
    });

    testWidgets('bez prijavljenog korisnika FAB za dodavanje je disabled', (tester) async {
      final repo = FakeAppRepository()
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
            sessionStore: FakeSessionStore(null),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull);
    });
  });

  group('TrgovinaPage states', () {
    testWidgets('nema prijavljenog korisnika -> error state', (tester) async {
      final repo = FakeAppRepository();

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: FakeSessionStore(null),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 7
        ..stavke = [];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: FakeSessionStore('a@b.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Popis je prazan.'), findsOneWidget);
    });

    testWidgets('prikazuje jednu stavku', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 7
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
            sessionStore: FakeSessionStore('a@b.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mlijeko'), findsOneWidget);
      expect(find.textContaining('Kategorija: Mlijecni'), findsOneWidget);
    });

    testWidgets('prikazuje gresku ako korisnik nije pronaden', (tester) async {
      final repo = FakeAppRepository()
        ..userId = null
        ..stavke = [];

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Korisnik nije pronađen'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('prikazuje gresku kada repository baca exception na dohvat stavki', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 7
        ..stavkeError = Exception('stavke fail');

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('stavke fail'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });
  });

  group('ZalihaNamirnicePage states', () {
    testWidgets('nema prijavljenog korisnika -> error state', (tester) async {
      final repo = FakeAppRepository();

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore(null),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 11
        ..zalihe = [];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nema zaliha za ovog korisnika.'), findsOneWidget);
    });

    testWidgets('prikazuje stavku zalihe', (tester) async {
      final repo = FakeAppRepository()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 1,
            'sastojakIme': 'Jaja',
            'kolicina': 3,
            'minKolicina': 5,
            'kategorijaIme': 'Proteini',
            'oznakaVelicine': 'kom',
            'datum': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Jaja'), findsOneWidget);
      expect(find.textContaining('Upozorenje: ispod minimalne količine'), findsOneWidget);
    });

    testWidgets('prikazuje gresku ako korisnik nije pronaden', (tester) async {
      final repo = FakeAppRepository()
        ..userId = null
        ..zalihe = [];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Korisnik nije pronađen'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('prikazuje upozorenje kad je rok istekao', (tester) async {
      final expired = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final repo = FakeAppRepository()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 2,
            'sastojakIme': 'Sir',
            'kolicina': 2,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'g',
            'datum': expired,
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rok je istekao'), findsOneWidget);
    });

    testWidgets('prikazuje upozorenje kad rok uskoro istice', (tester) async {
      final soon = DateTime.now().add(const Duration(days: 2)).toIso8601String();
      final repo = FakeAppRepository()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 3,
            'sastojakIme': 'Jogurt',
            'kolicina': 3,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'kom',
            'datum': soon,
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rok trajanja uskoro ističe'), findsOneWidget);
    });
  });

  group('PlanPrehranePage states', () {
    testWidgets('prikazuje naslov i osnovne chipove dana', (tester) async {
      final now = DateTime.now();
      final repo = FakeAppRepository()
        ..userId = 3
        ..vrsteObroka = [
          {'idVrstaObroka': 1, 'ime': 'dorucak'}
        ]
        ..recepti = [
          {'idRecept': 12, 'naziv': 'Omlet'}
        ]
        ..planRows = [
          {
            'idPlanObroka': 1,
            'idKorisnik': 3,
            'idRecept': 12,
            'datumObrok': DateTime(now.year, now.month, now.day).toIso8601String(),
            'tipObroka': 1,
            'odabran': 1,
            'izvrsen': 0,
            'receptNaziv': 'Omlet',
          }
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanPrehranePage(
              repository: repo,
              sessionStore: FakeSessionStore('plan@test.com'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Plan prehrane'), findsOneWidget);
      expect(find.text('Plan za sljedeća 3 dana'), findsOneWidget);
      expect(find.textContaining('Danas'), findsOneWidget);
      expect(find.textContaining('Sutra'), findsOneWidget);
      expect(find.textContaining('Prekosutra'), findsOneWidget);
      expect(find.text('Omlet'), findsOneWidget);
    });
  });
}
