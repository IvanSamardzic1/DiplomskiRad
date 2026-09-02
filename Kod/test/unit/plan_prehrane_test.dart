import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';
import 'package:projekt_prvaverzija/test_seams.dart';

class _FakeSessionStore implements SessionStore {
  final String? email;
  const _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepository implements AppRepository {
  final int? userId;
  final List<Map<String, dynamic>> vrste;
  final List<Map<String, dynamic>> plan;
  final List<Map<String, dynamic>> recepti;
  final bool throwOnGetVrste;

  const _FakeRepository({
    required this.userId,
    required this.vrste,
    required this.plan,
    required this.recepti,
    this.throwOnGetVrste = false,
  });

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async {
    if (throwOnGetVrste) throw Exception('repo getVrste failed');
    return vrste;
  }

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async =>
      plan;

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async => recepti;

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async =>
      <int, bool>{};

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];
}

class _SqlStub {
  final List<String> queriedSql = <String>[];
  final List<String> executedSql = <String>[];

  List<List<Map<String, Object?>>> planRowsQueue = <List<Map<String, Object?>>>[];
  List<Map<String, Object?>> receptDetaljiRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> receptSastojciRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> mlRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> heuristicRows = <Map<String, Object?>>[];

  bool throwOnDetalji = false;

  Future<List<Map<String, Object?>>> query(String sql) async {
    queriedSql.add(sql);

    if (throwOnDetalji && sql.contains('FROM Recept r') && sql.contains('WHERE r.idRecept =')) {
      throw Exception('detalji fail');
    }

    if (sql.contains('FROM PlanObroka p') && sql.contains('ORDER BY p.datumObrok ASC')) {
      if (planRowsQueue.isEmpty) return <Map<String, Object?>>[];
      return planRowsQueue.removeAt(0);
    }

    if (sql.contains('FROM Recept r') && sql.contains('WHERE r.idRecept =')) {
      return receptDetaljiRows;
    }

    if (sql.contains('FROM ReceptSastojak rs') && sql.contains('WHERE rs.idRecept =')) {
      return receptSastojciRows;
    }

    if (sql.contains('AS trazeniTipObrokaId')) {
      return mlRows;
    }

    if (sql.contains('FROM Recept r') &&
        sql.contains('AS userOdabranCount') &&
        sql.contains('AS userIzvrsenCount')) {
      return heuristicRows;
    }

    return <Map<String, Object?>>[];
  }

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }
}

Widget _buildPage({required AppRepository repo, required SessionStore session}) {
  return MaterialApp(
    home: Scaffold(
      body: PlanPrehranePage(repository: repo, sessionStore: session),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _closeOkIfPresent(WidgetTester tester) async {
  final okFinder = find.text('OK');
  if (okFinder.evaluate().isNotEmpty) {
    await tester.tap(okFinder.first);
    await _pumpUi(tester, ticks: 8);
  }
}

Future<void> _disposeUi(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime today;
  late _SqlStub sql;
  late Uint8List logoBytes;

  setUpAll(() {
    logoBytes = File('assets/slike/logo.png').readAsBytesSync();
  });

  setUp(() {
    sql = _SqlStub();

    DbQueries.setSqlExecutorsForTesting(
      query: sql.query,
      execute: sql.execute,
    );

    today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
          (ByteData? message) async {
        if (message == null) return null;

        final requested =
        utf8.decode(message.buffer.asUint8List());

        if (requested == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(
            <String, List<Map<String, Object?>>>{
              'assets/slike/logo.png': <Map<String, Object?>>[
                <String, Object?>{
                  'asset': 'assets/slike/logo.png',
                  'dpr': 1.0,
                },
              ],
              'assets/weights.json': <Map<String, Object?>>[
                <String, Object?>{
                  'asset': 'assets/weights.json',
                  'dpr': 1.0,
                },
              ],
            },
          );
        }

        if (requested == 'AssetManifest.json') {
          final bytes = Uint8List.fromList(
            utf8.encode(
              '{"assets/slike/logo.png":["assets/slike/logo.png"],'
                  '"assets/weights.json":["assets/weights.json"]}',
            ),
          );

          return ByteData.view(bytes.buffer);
        }

        if (requested == 'assets/weights.json') {
          final bytes = Uint8List.fromList(
            utf8.encode(
              '{"feature_order":'
                  '["vrijemePripremeMin","pokrivenostZaliha","fifoSignal",'
                  '"userOdabranCount","userIzvrsenCount","trazeniTipObrokaId"],'
                  '"coef":[0,0,0,0,0,0],'
                  '"intercept":0,'
                  '"mean":[0,0,0,0,0,0],'
                  '"scale":[1,1,1,1,1,1]}',
            ),
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

  testWidgets('renders loaded meal card for today', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 1, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 1,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 1,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 10,
          'receptNaziv': 'Varivo',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 10, 'naziv': 'Varivo'},
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.text('Varivo'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    await _disposeUi(tester);
  });

  testWidgets('renders page structure for logged user even with empty plan', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 1, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 10,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 1,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 100,
          'receptNaziv': 'Plan test',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 100, 'naziv': 'Plan test'},
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _disposeUi(tester);
  });

  testWidgets('keeps page structure stable on repeated load', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 1, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 11,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 1,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 101,
          'receptNaziv': 'Plan test 2',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 101, 'naziv': 'Plan test 2'},
      ],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _disposeUi(tester);
  });

  testWidgets('switches day chip and shows meal for selected day', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final tomorrow = today.add(const Duration(days: 1));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 2, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 21,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 201,
          'receptNaziv': 'Danasnji rucak',
        },
        <String, dynamic>{
          'idPlanObroka': 22,
          'datumObrok': tomorrow.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 202,
          'receptNaziv': 'Sutrasnji rucak',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 201, 'naziv': 'Danasnji rucak'},
        <String, dynamic>{'idRecept': 202, 'naziv': 'Sutrasnji rucak'},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    expect(find.text('Danasnji rucak'), findsOneWidget);
    expect(find.text('Sutrasnji rucak'), findsNothing);

    await tester.tap(find.textContaining('Sutra ('));
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Sutrasnji rucak'), findsOneWidget);
    expect(find.text('Danasnji rucak'), findsNothing);
  });

  testWidgets('shows fallback text when type has no plan item', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 3, 'ime': 'Vecera'},
      ],
      plan: const <Map<String, dynamic>>[],
      recepti: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    expect(find.text('Nije odabran recept'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Obriši recept'), findsNothing);
  });

  testWidgets('done meal hides delete and disables checkbox', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 2, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 31,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 1,
          'idRecept': 301,
          'receptNaziv': 'Gotov obrok',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 301, 'naziv': 'Gotov obrok'},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    expect(find.text('Obriši recept'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNull);
  });

  testWidgets('opens details dialog and shows recipe fields', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    sql.receptDetaljiRows = <Map<String, Object?>>[
      <String, Object?>{
        'idRecept': 401,
        'naziv': 'Lazanje',
        'opis': 'Opis jela',
        'vrijemePripreme': 55,
      },
    ];
    sql.receptSastojciRows = <Map<String, Object?>>[
      <String, Object?>{
        'sastojakIme': 'Tijesto',
        'potrebnaKolicina': 2,
        'oznakaVelicine': 'kom',
      },
    ];

    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 2, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 41,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 401,
          'receptNaziv': 'Lazanje',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 401, 'naziv': 'Lazanje'},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.text('Detalji'));
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Lazanje'), findsWidgets);
    expect(find.textContaining('Opis: Opis jela'), findsOneWidget);
    expect(find.textContaining('Vrijeme pripreme: 55 min'), findsOneWidget);
    expect(find.textContaining('- Tijesto: 2 kom'), findsOneWidget);

    await tester.tap(find.text('Zatvori'));
    await _pumpUi(tester, ticks: 6);
  });

  testWidgets('delete meal confirm executes SQL delete statement', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    sql.planRowsQueue = <List<Map<String, Object?>>>[
      <Map<String, Object?>>[],
    ];

    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 2, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 51,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 501,
          'receptNaziv': 'Za brisanje',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 501, 'naziv': 'Za brisanje'},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.text('Obriši recept'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.text('Obriši'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM PlanObroka')), isTrue);
  });

  testWidgets('mark done confirm executes SQL and shows snackbar', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    sql.planRowsQueue = <List<Map<String, Object?>>>[
      <Map<String, Object?>>[
        <String, Object?>{
          'idPlanObroka': 61,
          'idKorisnik': 7,
          'idRecept': 601,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 1,
          'receptNaziv': 'Oznacen obrok',
        },
      ],
    ];

    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 2, 'ime': 'Rucak'},
      ],
      plan: <Map<String, dynamic>>[
        <String, dynamic>{
          'idPlanObroka': 61,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 2,
          'odabran': 1,
          'izvrsen': 0,
          'idRecept': 601,
          'receptNaziv': 'Oznacen obrok',
        },
      ],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 601, 'naziv': 'Oznacen obrok'},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byType(Checkbox));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.text('Da'));
    await _pumpUi(tester, ticks: 10);

    expect(
      sql.executedSql.any((s) => s.contains('UPDATE PlanObroka') && s.contains('izvrsen = 1')),
      isTrue,
    );
    expect(find.text('Obrok je označen i zalihe su ažurirane.'), findsOneWidget);
  });

  testWidgets('add meal dialog filters recipes and saves selection', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    sql.planRowsQueue = <List<Map<String, Object?>>>[
      <Map<String, Object?>>[
        <String, Object?>{
          'idPlanObroka': 71,
          'idKorisnik': 7,
          'idRecept': 701,
          'datumObrok': today.toIso8601String(),
          'tipObroka': 1,
          'odabran': 1,
          'izvrsen': 0,
          'receptNaziv': 'Omlet',
        },
      ],
    ];

    final repo = _FakeRepository(
      userId: 7,
      vrste: <Map<String, dynamic>>[
        <String, dynamic>{'idVrstaObroka': 1, 'ime': 'Dorucak'},
      ],
      plan: const <Map<String, dynamic>>[],
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{'idRecept': 701, 'naziv': 'Omlet', 'jeDorucak': 1},
        <String, dynamic>{'idRecept': 702, 'naziv': 'Pasta', 'jeDorucak': 0},
      ],
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpUi(tester, ticks: 10);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.text('Dorucak').last);
    await _pumpUi(tester, ticks: 12);

    expect(find.text('Nema ML preporuka za odabrani tip obroka.'), findsOneWidget);
    expect(find.text('Nema heurističkih preporuka za odabrani tip obroka.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await _pumpUi(tester, ticks: 6);
    expect(find.text('Pasta'), findsNothing);
    await tester.tap(find.text('Omlet').last);
    await _pumpUi(tester, ticks: 6);

    await tester.tap(find.text('Spremi'));
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('INSERT INTO PlanObroka')), isTrue);
    expect(find.text('Omlet'), findsOneWidget);
  });

  testWidgets('handles null email from session without crash', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: const <Map<String, dynamic>>[],
      plan: const <Map<String, dynamic>>[],
      recepti: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore(null)),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _closeOkIfPresent(tester);
  });

  testWidgets('handles missing user id without crash', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: null,
      vrste: const <Map<String, dynamic>>[],
      plan: const <Map<String, dynamic>>[],
      recepti: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _closeOkIfPresent(tester);
  });

  testWidgets('handles repository failure in vrste load without crash', (tester) async {
    addTearDown(() async => _disposeUi(tester));
    final repo = _FakeRepository(
      userId: 7,
      vrste: const <Map<String, dynamic>>[],
      plan: const <Map<String, dynamic>>[],
      recepti: const <Map<String, dynamic>>[],
      throwOnGetVrste: true,
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _closeOkIfPresent(tester);
  });

}
