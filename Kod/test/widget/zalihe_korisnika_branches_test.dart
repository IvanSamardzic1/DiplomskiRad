import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projekt_prvaverzija/test_seams.dart';
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

  List<Map<String, dynamic>> zalihe = <Map<String, dynamic>>[];
  Object? zaliheError;

  @override
  Future<int?> getUserIdByMail(String mail) async {
    if (userIdError != null) throw userIdError!;
    return userId;
  }

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async {
    if (zaliheError != null) throw zaliheError!;
    return zalihe;
  }

  // Unused in these tests.
  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => <Map<String, dynamic>>[];

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async => <int, bool>{};

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async =>
      <Map<String, dynamic>>[];
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> _pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
      int maxTicks = 80,
      Duration step = const Duration(milliseconds: 50),
    }) async {
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail('Uvjet nije zadovoljen unutar timeouta.');
}

Future<void> _waitUntilNotLoading(WidgetTester tester) async {
  await _pumpUntil(
    tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZalihaNamirnicePage branches', () {
    testWidgets('nema prijavljenog korisnika -> error state', (tester) async {
      final repo = _FakeRepo();

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore(null),
          ),
        ),
      );

      await _waitUntilNotLoading(tester);

      expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
      expect(find.text('Pokušaj ponovno'), findsOneWidget);
    });

    testWidgets('user nije pronaden -> error state', (tester) async {
      final repo = _FakeRepo()..userId = null;

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _waitUntilNotLoading(tester);

      expect(find.textContaining('Korisnik nije pronađen'), findsOneWidget);
    });

    testWidgets('empty state prikazuje poruku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _waitUntilNotLoading(tester);

      expect(find.text('Nema zaliha za ovog korisnika.'), findsOneWidget);
    });

    testWidgets('istekao rok prikazuje crveno upozorenje', (tester) async {
      final expired = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 1,
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
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _waitUntilNotLoading(tester);

      expect(find.text('Rok je istekao'), findsOneWidget);
    });

    testWidgets('rok za 3 dana prikazuje "uskoro istice"', (tester) async {
      final in3days = DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 2,
            'sastojakIme': 'Jogurt',
            'kolicina': 3,
            'minKolicina': 1,
            'kategorijaIme': 'Mlijecni',
            'oznakaVelicine': 'kom',
            'datum': in3days,
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

      await _waitUntilNotLoading(tester);

      expect(find.text('Rok trajanja uskoro ističe'), findsOneWidget);
    });

    testWidgets('rok za 4 dana ne prikazuje upozorenje', (tester) async {
      final in4days = DateTime.now().add(const Duration(days: 4)).toIso8601String();
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
            'datum': in4days,
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

      await _waitUntilNotLoading(tester);

      expect(find.text('Rok je istekao'), findsNothing);
      expect(find.text('Rok trajanja uskoro ističe'), findsNothing);
    });

    testWidgets('kolicina > min: inventory ikona i bez low-stock upozorenja', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 4,
            'sastojakIme': 'Brasno',
            'kolicina': 10,
            'minKolicina': 2,
            'kategorijaIme': 'Pekarstvo',
            'oznakaVelicine': 'g',
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

      await _waitUntilNotLoading(tester);

      expect(find.byIcon(Icons.inventory_2), findsOneWidget);
      expect(find.textContaining('Upozorenje: ispod minimalne količine'), findsNothing);
    });

    testWidgets('invalidan idZaliha: klik Obrisi ne otvara confirm dialog', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 0,
            'sastojakIme': 'Paprika',
            'kolicina': 2,
            'minKolicina': 1,
            'kategorijaIme': 'Povrce',
            'oznakaVelicine': 'kom',
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

      await _waitUntilNotLoading(tester);

      await tester.tap(find.byTooltip('Obriši'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Potvrda brisanja'), findsNothing);
    });
  });
}
