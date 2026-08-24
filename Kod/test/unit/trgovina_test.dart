import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:projekt_prvaverzija/trgovina.dart';

class _FakeSessionStore implements SessionStore {
  final String? email;
  const _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepository implements AppRepository {
  final int? userId;
  final List<Map<String, dynamic>> stavke;

  const _FakeRepository({required this.userId, required this.stavke});

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async => stavke;

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => <Map<String, dynamic>>[];

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async => <int, bool>{};

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async =>
      <Map<String, dynamic>>[];
}

class _SqlStub {
  final List<String> queriedSql = <String>[];
  final List<String> executedSql = <String>[];

  List<Map<String, Object?>> kategorije = <Map<String, Object?>>[];
  List<Map<String, Object?>> sastojci = <Map<String, Object?>>[];

  bool throwOnInsert = false;
  bool throwOnDelete = false;
  bool throwOnUpdate = false;
  bool throwOnPurchase = false;
  bool throwOnGetKategorije = false;

  Future<List<Map<String, Object?>>> query(String sql) async {
    queriedSql.add(sql);

    if (sql.contains('FROM Kategorija')) {
      if (throwOnGetKategorije) throw Exception('kategorije failed');
      return kategorije;
    }
    if (sql.contains('FROM Sastojak s')) {
      return sastojci;
    }

    return <Map<String, Object?>>[];
  }

  Future<void> execute(String sql) async {
    if (throwOnInsert && sql.contains('INSERT INTO StavkaPopisaTrgovina')) {
      throw Exception('insert failed');
    }
    if (throwOnDelete && sql.contains('DELETE FROM StavkaPopisaTrgovina')) {
      throw Exception('delete failed');
    }
    if (throwOnUpdate && sql.contains('UPDATE StavkaPopisaTrgovina')) {
      throw Exception('update failed');
    }
    if (throwOnPurchase && sql.contains('BEGIN TRANSACTION')) {
      throw Exception('purchase failed');
    }

    executedSql.add(sql);
  }
}

Widget _buildPage({required AppRepository repo, required SessionStore session}) {
  return MaterialApp(
    home: Scaffold(
      body: TrgovinaPage(repository: repo, sessionStore: session),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester, {int ticks = 18}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SqlStub sql;

  setUp(() {
    sql = _SqlStub();
    final Uint8List logoBytes = File('assets/slike/logo.png').readAsBytesSync();

    DbQueries.setSqlExecutorsForTesting(query: sql.query, execute: sql.execute);

    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        if (message == null) return null;
        final requested = utf8.decode(message.buffer.asUint8List());

        if (requested == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(
            <String, List<Map<String, Object?>>>{
              'assets/slike/logo.png': <Map<String, Object?>>[
                <String, Object?>{'asset': 'assets/slike/logo.png', 'dpr': 1.0},
              ],
            },
          );
        }

        if (requested == 'AssetManifest.json') {
          final bytes = Uint8List.fromList(
            utf8.encode('{"assets/slike/logo.png":["assets/slike/logo.png"]}'),
          );
          return ByteData.view(bytes.buffer);
        }

        if (requested.endsWith('.png')) {
          return ByteData.view(logoBytes.buffer);
        }

        return null;
      },
    );
  });

  tearDown(() {
    DbQueries.resetSqlExecutorsForTesting();
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('renders shopping list items and actions', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 11,
          'idKorisnik': 7,
          'sastojakId': 2,
          'kolicina': 3,
          'sastojakIme': 'Mlijeko',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Popis za trgovinu'), findsOneWidget);
    expect(find.text('Mlijeko'), findsOneWidget);
    expect(find.textContaining('Kategorija: Mliječno'), findsOneWidget);
    expect(find.byTooltip('Označi kao kupljeno'), findsOneWidget);
    expect(find.byTooltip('Uredi'), findsOneWidget);
    expect(find.byTooltip('Obriši'), findsOneWidget);
  });

  testWidgets('shows error state when session user is missing', (tester) async {
    final repo = _FakeRepository(userId: null, stavke: const <Map<String, dynamic>>[]);

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('')));
    await _pumpUi(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pokušaj ponovno'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no shopping items', (tester) async {
    final repo = _FakeRepository(userId: 7, stavke: const <Map<String, dynamic>>[]);

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Popis je prazan.'), findsOneWidget);
  });

  testWidgets('markAsPurchased with invalid item data shows error', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 0,
          'idKorisnik': 7,
          'sastojakId': 0,
          'kolicina': 0,
          'sastojakIme': 'Neispravno',
          'kategorijaIme': 'Test',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Označi kao kupljeno'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('Neispravni podaci stavke'), findsOneWidget);
  });

  testWidgets('markAsPurchased can be cancelled in purchase dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 12,
          'idKorisnik': 7,
          'sastojakId': 2,
          'kolicina': 3,
          'sastojakIme': 'Mlijeko',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Označi kao kupljeno'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Potvrda kupnje'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpUi(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('BEGIN TRANSACTION')), isFalse);
  });

  testWidgets('markAsPurchased success executes purchase SQL', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 13,
          'idKorisnik': 7,
          'sastojakId': 3,
          'kolicina': 2,
          'sastojakIme': 'Sir',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Označi kao kupljeno'));
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('BEGIN TRANSACTION')), isTrue);
  });

  testWidgets('markAsPurchased failure shows error dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 14,
          'idKorisnik': 7,
          'sastojakId': 3,
          'kolicina': 2,
          'sastojakIme': 'Sir',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );
    sql.throwOnPurchase = true;

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Označi kao kupljeno'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('purchase failed'), findsOneWidget);
  });

  testWidgets('edit with invalid id shows error', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 0,
          'idKorisnik': 7,
          'sastojakId': 1,
          'kolicina': 2,
          'sastojakIme': 'Jabuka',
          'kategorijaIme': 'Voće',
          'oznakaVelicine': 'kg',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('Neispravan ID stavke'), findsOneWidget);
  });

  testWidgets('edit quantity dialog validates and updates', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 21,
          'idKorisnik': 7,
          'sastojakId': 1,
          'kolicina': 2,
          'sastojakIme': 'Jabuka',
          'kategorijaIme': 'Voće',
          'oznakaVelicine': 'kg',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 8);

    expect(find.textContaining('Količina mora biti cijeli broj > 0.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('UPDATE StavkaPopisaTrgovina')), isTrue);
  });

  testWidgets('edit update failure shows error dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 22,
          'idKorisnik': 7,
          'sastojakId': 1,
          'kolicina': 2,
          'sastojakIme': 'Jabuka',
          'kategorijaIme': 'Voće',
          'oznakaVelicine': 'kg',
        },
      ],
    );
    sql.throwOnUpdate = true;

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('update failed'), findsOneWidget);
  });

  testWidgets('delete with invalid id shows error', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 0,
          'idKorisnik': 7,
          'sastojakId': 8,
          'sastojakIme': 'Maslac',
          'kolicina': 2,
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('Neispravan ID stavke'), findsOneWidget);
  });

  testWidgets('delete cancel does not call SQL delete', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 31,
          'idKorisnik': 7,
          'sastojakId': 8,
          'sastojakIme': 'Maslac',
          'kolicina': 2,
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpUi(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM StavkaPopisaTrgovina')), isFalse);
  });

  testWidgets('delete success and failure paths', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      stavke: <Map<String, dynamic>>[
        <String, dynamic>{
          'idStavkaPopisa': 32,
          'idKorisnik': 7,
          'sastojakId': 8,
          'sastojakIme': 'Maslac',
          'kolicina': 2,
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Obriši'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM StavkaPopisaTrgovina')), isTrue);
  });

  testWidgets('add dialog load and submit flows', (tester) async {
    final repo = _FakeRepository(userId: 7, stavke: const <Map<String, dynamic>>[]);

    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 9,
        'sastojakIme': 'Banana',
        'idVelicina': 1,
        'oznakaVelicine': 'kg',
      },
    ];

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Dodaj'));
    await _pumpUi(tester, ticks: 8);

    // Validation without selections.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dodaj'));
    await _pumpUi(tester, ticks: 8);
    expect(find.text('Odaberi kategoriju'), findsWidgets);

    // Select category + ingredient, invalid quantity.
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Banana').last);
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.widgetWithText(TextFormField, 'Potrebna količina (kg)'), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dodaj'));
    await _pumpUi(tester, ticks: 8);
    expect(find.text('Mora biti > 0'), findsOneWidget);

    // Successful insert.
    await tester.enterText(find.widgetWithText(TextFormField, 'Potrebna količina (kg)'), '4');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dodaj'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('INSERT INTO StavkaPopisaTrgovina')), isTrue);
  });

  testWidgets('add dialog handles kategorije load failure and insert failure', (tester) async {
    final repo = _FakeRepository(userId: 7, stavke: const <Map<String, dynamic>>[]);

    sql.throwOnGetKategorije = true;
    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Dodaj'));
    await _pumpUi(tester, ticks: 8);
    expect(find.textContaining('kategorije failed'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpUi(tester, ticks: 8);

    sql.throwOnGetKategorije = false;
    sql.throwOnInsert = true;
    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 9,
        'sastojakIme': 'Banana',
        'idVelicina': 1,
        'oznakaVelicine': 'kg',
      },
    ];

    await tester.tap(find.text('Dodaj'));
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Banana').last);
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.widgetWithText(TextFormField, 'Potrebna količina (kg)'), '2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dodaj'));
    await _pumpUi(tester, ticks: 10);

    expect(find.textContaining('insert failed'), findsOneWidget);
  });
}

