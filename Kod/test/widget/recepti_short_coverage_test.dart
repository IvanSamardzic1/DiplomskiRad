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
  int? userId = 1;
  List<Map<String, dynamic>> recepti = <Map<String, dynamic>>[];

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => recepti;

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async =>
      <int, bool>{};

  // Unused here.
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
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ReceptiPage: pretraga po autoru filtrira listu', (tester) async {
    final repo = _FakeRepo()
      ..recepti = <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Omlet',
          'autorIme': 'Ana',
          'autorKorisnikId': 1,
        },
        <String, dynamic>{
          'idRecept': 2,
          'naziv': 'Varivo',
          'autorIme': 'Ivan',
          'autorKorisnikId': 2,
        },
      ];

    await tester.pumpWidget(
      _host(
        ReceptiPage(
          repository: repo,
          sessionStore: _FakeSessionStore('ana@test.com'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ivan');
    await tester.pump();

    expect(find.text('Varivo'), findsOneWidget);
    expect(find.text('Omlet'), findsNothing);
  });

  testWidgets('ReceptDetaljiPage: bez currentUserId ne prikazuje sekciju Nedostaje', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceptDetaljiPage(
          idRecept: 5,
          currentUserId: null,
          loadReceptDetalji: (_) async => <String, dynamic>{
            'idRecept': 5,
            'naziv': 'Tost',
            'autorIme': 'Marko',
            'autorKorisnikId': 7,
            'vrijemePripreme': 5,
            'opis': 'Brzo',
          },
          loadReceptSastojci: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'sastojakIme': 'Kruh',
              'potrebnaKolicina': 2,
              'oznakaVelicine': 'kom',
            }
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nedostaje'), findsNothing);
    expect(find.text('Kruh'), findsOneWidget);
  });
}
