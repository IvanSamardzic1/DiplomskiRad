import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';

class _FakeSessionStore implements SessionStore {
  final String? email;
  const _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepository implements AppRepository {
  final int? userId;
  final List<Map<String, dynamic>> zalihe;

  const _FakeRepository({required this.userId, required this.zalihe});

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async => zalihe;

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => <Map<String, dynamic>>[];

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async =>
      <int, bool>{};

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

class _SqlStub {
  final List<String> queriedSql = <String>[];
  final List<String> executedSql = <String>[];

  List<Map<String, Object?>> kategorije = <Map<String, Object?>>[];
  List<Map<String, Object?>> sastojci = <Map<String, Object?>>[];
  Map<String, Object?>? postojecaZaliha;
  bool throwOnDelete = false;
  bool throwOnGetKategorije = false;
  bool throwOnUpsert = false;
  bool throwOnUpdate = false;

  Future<List<Map<String, Object?>>> query(String sql) async {
    queriedSql.add(sql);

    if (sql.contains('FROM Kategorija')) {
      if (throwOnGetKategorije) throw Exception('kategorije failed');
      return kategorije;
    }

    if (sql.contains('FROM Sastojak s')) {
      return sastojci;
    }

    if (sql.contains('SELECT TOP 1') && sql.contains('FROM Zaliha')) {
      if (postojecaZaliha == null) return <Map<String, Object?>>[];
      return <Map<String, Object?>>[postojecaZaliha!];
    }

    return <Map<String, Object?>>[];
  }

  Future<void> execute(String sql) async {
    if (throwOnDelete && sql.contains('DELETE FROM Zaliha')) {
      throw Exception('delete failed');
    }
    if (throwOnUpsert && sql.contains('IF EXISTS (') && sql.contains('FROM Zaliha')) {
      throw Exception('upsert failed');
    }
    if (throwOnUpdate && sql.contains('UPDATE Zaliha')) {
      throw Exception('update failed');
    }
    executedSql.add(sql);
  }
}

Widget _buildPage({required AppRepository repo, required SessionStore session}) {
  return MaterialApp(
    home: Scaffold(
      body: ZalihaNamirnicePage(repository: repo, sessionStore: session),
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
  late DateTime today;

  setUp(() {
    sql = _SqlStub();
    final Uint8List logoBytes = File('assets/slike/logo.png').readAsBytesSync();
    today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

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

  testWidgets('renders list with warning texts when below minimum and near expiry',
      (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 11,
          'idKorisnik': 7,
          'idSastojak': 2,
          'kolicina': 1,
          'minKolicina': 2,
          'sastojakIme': 'Mlijeko',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
          'datum': today.add(const Duration(days: 1)).toIso8601String(),
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Moje zalihe namirnica'), findsOneWidget);
    expect(find.text('Mlijeko'), findsOneWidget);
    expect(find.textContaining('Rok trajanja uskoro ističe'), findsOneWidget);
    expect(find.textContaining('ispod minimalne količine'), findsOneWidget);
    expect(find.byTooltip('Uredi'), findsOneWidget);
    expect(find.byTooltip('Obriši'), findsOneWidget);
  });

  testWidgets('renders expired warning when expiry date already passed', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 12,
          'idKorisnik': 7,
          'idSastojak': 3,
          'kolicina': 5,
          'minKolicina': 2,
          'sastojakIme': 'Sir',
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
          'datum': today.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Rok je istekao'), findsOneWidget);
  });

  testWidgets('shows error state and retry button when user is missing', (tester) async {
    final repo = _FakeRepository(userId: null, zalihe: const <Map<String, dynamic>>[]);

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('')));
    await _pumpUi(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pokušaj ponovno'), findsOneWidget);
  });

  testWidgets('shows empty state when user has no items', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Nema zaliha za ovog korisnika.'), findsOneWidget);
  });

  testWidgets('add dialog shows no-sastojci message for empty category', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);

    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[];

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Dodaj namirnicu u zalihu'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Nema sastojaka za odabranu kategoriju.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpUi(tester, ticks: 6);
  });

  testWidgets('add dialog submits with existing zaliha fallback values', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);

    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 5,
        'sastojakIme': 'Jabuka',
        'idVelicina': 1,
        'oznakaVelicine': 'kg',
      },
    ];
    sql.postojecaZaliha = <String, Object?>{
      'idZaliha': 31,
      'idKorisnik': 7,
      'idSastojak': 5,
      'kolicina': 10,
      'minKolicina': 2,
      'datum': today.toIso8601String(),
    };

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Jabuka').last);
    await _pumpUi(tester, ticks: 10);

    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '3');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.isNotEmpty, isTrue);
    expect(sql.executedSql.first.contains('Zaliha'), isTrue);
  });

  testWidgets('edit dialog updates zaliha', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 21,
          'idKorisnik': 7,
          'idSastojak': 5,
          'sastojakIme': 'Jabuka',
          'kolicina': 4,
          'minKolicina': 1,
          'datum': today.toIso8601String(),
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

    expect(find.textContaining('Uredi zalihu'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minimalna količina'), '2');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('UPDATE Zaliha')), isTrue);
  });

  testWidgets('delete confirms and removes zaliha', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 41,
          'idKorisnik': 7,
          'idSastojak': 8,
          'sastojakIme': 'Maslac',
          'kolicina': 2,
          'minKolicina': 1,
          'datum': today.toIso8601String(),
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

    expect(find.text('Potvrda brisanja'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Obriši'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Zaliha')), isTrue);
  });

  testWidgets('delete with invalid id returns early without dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 0,
          'idKorisnik': 7,
          'idSastojak': 1,
          'sastojakIme': 'Neispravno',
          'kolicina': 1,
          'minKolicina': 1,
          'datum': today.toIso8601String(),
          'kategorijaIme': 'Test',
          'oznakaVelicine': 'kom',
        },
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 6);

    expect(find.text('Potvrda brisanja'), findsNothing);
    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Zaliha')), isFalse);
  });

  testWidgets('delete cancel keeps zaliha unchanged', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 42,
          'idKorisnik': 7,
          'idSastojak': 8,
          'sastojakIme': 'Maslac',
          'kolicina': 2,
          'minKolicina': 1,
          'datum': today.toIso8601String(),
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

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Zaliha')), isFalse);
    expect(find.text('Maslac'), findsOneWidget);
  });

  testWidgets('delete failure shows error dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 43,
          'idKorisnik': 7,
          'idSastojak': 9,
          'sastojakIme': 'Jogurt',
          'kolicina': 2,
          'minKolicina': 1,
          'datum': today.toIso8601String(),
          'kategorijaIme': 'Mliječno',
          'oznakaVelicine': 'kom',
        },
      ],
    );
    sql.throwOnDelete = true;

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Obriši'));
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('delete failed'), findsOneWidget);
  });

  testWidgets('add dialog requires min/date when no existing zaliha', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);

    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 5,
        'sastojakIme': 'Jabuka',
        'idVelicina': 1,
        'oznakaVelicine': 'kg',
      },
    ];
    sql.postojecaZaliha = null;

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Jabuka').last);
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '3');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Unesi broj'), findsOneWidget);
    expect(find.text('Odaberi datum'), findsOneWidget);
  });

  testWidgets('add dialog shows load error when kategorije query fails', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);
    sql.throwOnGetKategorije = true;

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 10);

    expect(find.textContaining('kategorije failed'), findsOneWidget);
  });

  testWidgets('add dialog shows submit error when upsert fails', (tester) async {
    final repo = _FakeRepository(userId: 7, zalihe: const <Map<String, dynamic>>[]);
    sql.throwOnUpsert = true;

    sql.kategorije = <Map<String, Object?>>[
      <String, Object?>{'idKategorija': 1, 'imeKategorije': 'Voće'},
    ];
    sql.sastojci = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 5,
        'sastojakIme': 'Jabuka',
        'idVelicina': 1,
        'oznakaVelicine': 'kg',
      },
    ];
    sql.postojecaZaliha = <String, Object?>{
      'idZaliha': 31,
      'idKorisnik': 7,
      'idSastojak': 5,
      'kolicina': 10,
      'minKolicina': 2,
      'datum': today.toIso8601String(),
    };

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Voće').last);
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Jabuka').last);
    await _pumpUi(tester, ticks: 10);

    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(find.textContaining('upsert failed'), findsOneWidget);
  });

  testWidgets('edit dialog validation and invalid-id branches', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      zalihe: <Map<String, dynamic>>[
        <String, dynamic>{
          'idZaliha': 0,
          'idKorisnik': 7,
          'idSastojak': 5,
          'sastojakIme': 'Jabuka',
          'kolicina': 4,
          'minKolicina': 1,
          'datum': 'not-a-date',
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

    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '0');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minimalna količina'), '-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Mora biti više od 0'), findsOneWidget);
    expect(find.text('Ne može biti negativno'), findsOneWidget);

    // Set valid values, but idZaliha is invalid so submit should return without SQL update.
    await tester.enterText(find.widgetWithText(TextFormField, 'Količina'), '3');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minimalna količina'), '1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Spremi'));
    await _pumpUi(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('UPDATE Zaliha')), isFalse);
  });
}

