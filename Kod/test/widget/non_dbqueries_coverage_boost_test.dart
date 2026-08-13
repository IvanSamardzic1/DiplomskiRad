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

  List<String> seenMails = <String>[];

  List<Map<String, dynamic>> recepti = <Map<String, dynamic>>[];
  Object? receptiError;

  Map<int, bool> missingByRecipe = <int, bool>{};
  Object? missingError;
  int missingCalls = 0;

  List<Map<String, dynamic>> stavke = <Map<String, dynamic>>[];
  Object? stavkeError;

  List<Map<String, dynamic>> zalihe = <Map<String, dynamic>>[];
  Object? zaliheError;

  @override
  Future<int?> getUserIdByMail(String mail) async {
    seenMails.add(mail);
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
    missingCalls++;
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

  // Unused in this test file.
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
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

Future<void> _pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
      int maxTicks = 120,
      Duration step = const Duration(milliseconds: 50),
    }) async {
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail('Uvjet nije zadovoljen unutar timeouta.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceptiPage non-db branches', () {
    testWidgets('normalizira email prije getUserIdByMail', (tester) async {
      final repo = _FakeRepo()
        ..userId = 1
        ..recepti = [
          {'idRecept': 1, 'naziv': 'Juha', 'autorIme': 'Ana', 'autorKorisnikId': 1}
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('  Ana@Test.COM  '),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Svi recepti').evaluate().isNotEmpty);

      expect(repo.seenMails, isNotEmpty);
      expect(repo.seenMails.first, 'ana@test.com');
      expect(find.text('Juha'), findsOneWidget);
    });

    testWidgets('bez prijavljenog korisnika ne zove missing status i FAB je disabled', (tester) async {
      final repo = _FakeRepo()
        ..recepti = [
          {'idRecept': 2, 'naziv': 'Omlet', 'autorIme': 'Marko', 'autorKorisnikId': 99}
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore(null),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Svi recepti').evaluate().isNotEmpty);

      expect(repo.missingCalls, 0);

      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull);
    });

    testWidgets('fallback za prazan naziv i autora', (tester) async {
      final repo = _FakeRepo()
        ..userId = 5
        ..recepti = [
          {'idRecept': 3, 'naziv': '   ', 'autorIme': '', 'autorKorisnikId': 5}
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Svi recepti').evaluate().isNotEmpty);

      expect(find.text('Bez naziva'), findsOneWidget);
      expect(find.textContaining('Autor: Nepoznato'), findsOneWidget);
    });

    testWidgets('pretraga po autoru radi case-insensitive i trim', (tester) async {
      final repo = _FakeRepo()
        ..userId = 5
        ..recepti = [
          {'idRecept': 11, 'naziv': 'Varivo', 'autorIme': 'IvAnA', 'autorKorisnikId': 7}
        ];

      await tester.pumpWidget(
        _host(
          ReceptiPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Svi recepti').evaluate().isNotEmpty);

      await tester.enterText(find.byType(TextField), '  ivana ');
      await tester.pump();

      expect(find.text('Varivo'), findsOneWidget);
      expect(find.text('Nema rezultata pretrage.'), findsNothing);
    });
  });

  group('TrgovinaPage non-db branches', () {
    testWidgets('normalizira email prije getUserIdByMail i prikazuje stavku', (tester) async {
      final repo = _FakeRepo()
        ..userId = 9
        ..stavke = [
          {
            'idStavkaPopisa': 1,
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
            sessionStore: _FakeSessionStore('  USER@MAIL.COM '),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Popis za trgovinu').evaluate().isNotEmpty);

      expect(repo.seenMails, isNotEmpty);
      expect(repo.seenMails.first, 'user@mail.com');
      expect(find.text('Mlijeko'), findsOneWidget);
    });

    testWidgets('retry nakon stavkeError vraca listu', (tester) async {
      final repo = _FakeRepo()
        ..userId = 9
        ..stavkeError = Exception('stavke fail');

      await tester.pumpWidget(
        _host(
          TrgovinaPage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Pokušaj ponovno').evaluate().isNotEmpty);
      expect(find.textContaining('stavke fail'), findsOneWidget);

      repo
        ..stavkeError = null
        ..stavke = [
          {
            'idStavkaPopisa': 2,
            'sastojakId': 8,
            'sastojakIme': 'Jabuka',
            'kolicina': 3,
            'kategorijaIme': 'Voce',
            'oznakaVelicine': 'kom',
          }
        ];

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pump();

      await _pumpUntil(tester, () => find.text('Jabuka').evaluate().isNotEmpty);
      expect(find.text('Jabuka'), findsOneWidget);
    });
  });

  group('ZalihaNamirnicePage non-db branches', () {
    testWidgets('normalizira email prije getUserIdByMail i prikazuje stavku', (tester) async {
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
            'datum': DateTime(2026, 9, 5).toIso8601String(),
          }
        ];

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('  X@Y.COM '),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Moje zalihe namirnica').evaluate().isNotEmpty);

      expect(repo.seenMails, isNotEmpty);
      expect(repo.seenMails.first, 'x@y.com');
      expect(find.text('Sir'), findsOneWidget);
    });

    testWidgets('retry nakon zaliheError vraca listu', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zaliheError = Exception('zalihe fail');

      await tester.pumpWidget(
        _host(
          ZalihaNamirnicePage(
            repository: repo,
            sessionStore: _FakeSessionStore('x@y.com'),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('Pokušaj ponovno').evaluate().isNotEmpty);
      expect(find.textContaining('zalihe fail'), findsOneWidget);

      repo
        ..zaliheError = null
        ..zalihe = [
          {
            'idZaliha': 5,
            'sastojakIme': 'Jaja',
            'kolicina': 6,
            'minKolicina': 2,
            'kategorijaIme': 'Proteini',
            'oznakaVelicine': 'kom',
            'datum': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          }
        ];

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pump();

      await _pumpUntil(tester, () => find.text('Jaja').evaluate().isNotEmpty);
      expect(find.text('Jaja'), findsOneWidget);
    });

    testWidgets('neparsabilna kolicina i minKolicina fallbackaju na 0 i pokazu warning', (tester) async {
      final repo = _FakeRepo()
        ..userId = 11
        ..zalihe = [
          {
            'idZaliha': 9,
            'sastojakIme': 'Riza',
            'kolicina': 'nije-broj',
            'minKolicina': 'takoder-ne-broj',
            'kategorijaIme': 'Ugljikohidrati',
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

      await _pumpUntil(tester, () => find.text('Moje zalihe namirnica').evaluate().isNotEmpty);

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('Upozorenje: ispod minimalne količine'), findsOneWidget);
    });
  });
}
