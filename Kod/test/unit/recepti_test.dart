import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/test_seams.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x01, 0x73, 0x52, 0x47, 0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00,
  0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _FakeSessionStore implements SessionStore {
  final String? email;
  const _FakeSessionStore(this.email);

  @override
  Future<String?> getLoggedInEmail() async => email;
}

class _FakeRepository implements AppRepository {
  final int? userId;
  final List<Map<String, dynamic>> recepti;
  final Map<int, bool> missing;
  final bool throwOnReceptiList;

  const _FakeRepository({
    required this.userId,
    required this.recepti,
    required this.missing,
    this.throwOnReceptiList = false,
  });

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() async {
    if (throwOnReceptiList) throw Exception('repo failed');
    return recepti;
  }

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) async => missing;

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) async => <Map<String, dynamic>>[];
}

class _SqlStub {
  final List<String> queriedSql = <String>[];
  final List<String> executedSql = <String>[];

  List<Map<String, Object?>> allSastojciRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> receptDetaljiRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> receptSastojciRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> missingRows = <Map<String, Object?>>[];

  bool throwOnInsert = false;
  bool throwOnUpdate = false;
  bool throwOnDelete = false;

  Future<List<Map<String, Object?>>> query(String sql) async {
    queriedSql.add(sql);

    if (throwOnInsert && sql.contains('INSERT INTO Recept (naziv, opis, vrijemePripreme, autorKorisnikId)')) {
      throw Exception('insert recept failed');
    }

    if (sql.contains('SELECT @newId AS idRecept')) {
      return <Map<String, Object?>>[
        <String, Object?>{'idRecept': 999},
      ];
    }

    if (sql.contains('FROM Recept r') && sql.contains('WHERE r.idRecept =')) {
      return receptDetaljiRows;
    }
    if (sql.contains('FROM ReceptSastojak rs') && sql.contains('WHERE rs.idRecept =')) {
      return receptSastojciRows;
    }
    if (sql.contains('AS nedostaje') && sql.contains('FROM ReceptSastojak rs')) {
      return missingRows;
    }
    if (sql.contains('FROM Sastojak s') && sql.contains('kategorijaIme')) {
      return allSastojciRows;
    }

    return <Map<String, Object?>>[];
  }

  Future<void> execute(String sql) async {
    if (throwOnUpdate && sql.contains('UPDATE Recept')) {
      throw Exception('update recept failed');
    }
    if (throwOnDelete && sql.contains('DELETE FROM Recept')) {
      throw Exception('delete recept failed');
    }
    executedSql.add(sql);
  }
}

Widget _buildPage({required AppRepository repo, required SessionStore session}) {
  return MaterialApp(
    home: Scaffold(
      body: ReceptiPage(repository: repo, sessionStore: session),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester, {int ticks = 16}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SqlStub sql;

  setUp(() {
    sql = _SqlStub();

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
          final bytes = Uint8List.fromList(_kTransparentImage);
          return ByteData.view(bytes.buffer);
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

  testWidgets('renders recipes, search and author actions', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
        <String, dynamic>{
          'idRecept': 2,
          'naziv': 'Pasta',
          'autorIme': 'Marko Drugi',
          'autorKorisnikId': 15,
        },
      ],
      missing: <int, bool>{1: true},
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    expect(find.text('Svi recepti'), findsOneWidget);
    expect(find.text('Juha'), findsOneWidget);
    expect(find.textContaining('Nedostaju sastojci'), findsOneWidget);
    expect(find.byTooltip('Uredi'), findsOneWidget);
    expect(find.byTooltip('Obriši'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'marko');
    await _pumpUi(tester, ticks: 8);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Juha'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await _pumpUi(tester, ticks: 8);
    expect(find.text('Juha'), findsOneWidget);
  });

  testWidgets('shows empty search result text', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.enterText(find.byType(TextField), 'nema');
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Nema rezultata pretrage.'), findsOneWidget);
  });

  testWidgets('shows error state when repository throws', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: const <Map<String, dynamic>>[],
      missing: const <int, bool>{},
      throwOnReceptiList: true,
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('repo failed'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
  });

  testWidgets('add recipe dialog validates and saves recipe', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    sql.allSastojciRows = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 10,
        'sastojakIme': 'Mrkva',
        'oznakaVelicine': 'kom',
        'kategorijaIme': 'Povrće',
      },
    ];

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Dodaj recept'));
    await _pumpUi(tester, ticks: 10);

    await tester.tap(find.text('Dodaj').last);
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Naziv je obavezan'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Naziv recepta'), 'Nova Juha');
    await tester.enterText(find.widgetWithText(TextFormField, 'Vrijeme pripreme (min)'), '20');

    await tester.ensureVisible(find.text('Dodaj sastojak'));
    await tester.tap(find.text('Dodaj sastojak').last);
    await _pumpUi(tester, ticks: 8);
    expect(find.textContaining('Odaberi sastojak'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.textContaining('Mrkva').last);
    await _pumpUi(tester, ticks: 8);

    await tester.enterText(find.widgetWithText(TextFormField, 'Potrebna količina sastojka'), '2');
    await tester.ensureVisible(find.text('Dodaj sastojak'));
    await tester.tap(find.text('Dodaj sastojak').last);
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Mrkva'), findsOneWidget);

    await tester.tap(find.text('Dodaj').last);
    await _pumpUi(tester, ticks: 10);

    expect(sql.queriedSql.any((s) => s.contains('INSERT INTO Recept (naziv, opis, vrijemePripreme, autorKorisnikId)')), isTrue);
  });

  testWidgets('add recipe dialog shows submit error when insert fails', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    sql.throwOnInsert = true;
    sql.allSastojciRows = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 10,
        'sastojakIme': 'Mrkva',
        'oznakaVelicine': 'kom',
        'kategorijaIme': 'Povrće',
      },
    ];

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Dodaj recept'));
    await _pumpUi(tester, ticks: 10);

    await tester.enterText(find.widgetWithText(TextFormField, 'Naziv recepta'), 'Nova Juha');
    await tester.enterText(find.widgetWithText(TextFormField, 'Vrijeme pripreme (min)'), '20');
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await _pumpUi(tester, ticks: 6);
    await tester.tap(find.textContaining('Mrkva').last);
    await _pumpUi(tester, ticks: 8);
    await tester.enterText(find.widgetWithText(TextFormField, 'Potrebna količina sastojka'), '2');
    await tester.ensureVisible(find.text('Dodaj sastojak'));
    await tester.tap(find.text('Dodaj sastojak').last);
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.text('Dodaj').last);
    await _pumpUi(tester, ticks: 10);

    expect(find.textContaining('insert recept failed'), findsOneWidget);
  });

  testWidgets('edit recipe unauthorized shows error dialog', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    sql.receptDetaljiRows = <Map<String, Object?>>[
      <String, Object?>{
        'idRecept': 1,
        'naziv': 'Juha',
        'opis': 'Opis',
        'vrijemePripreme': 10,
        'autorKorisnikId': 999,
        'autorIme': 'Netko drugi',
      },
    ];

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 8);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('Možeš uređivati samo svoje recepte'), findsOneWidget);
  });

  testWidgets('edit recipe success and failure paths', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    sql.receptDetaljiRows = <Map<String, Object?>>[
      <String, Object?>{
        'idRecept': 1,
        'naziv': 'Juha',
        'opis': 'Opis',
        'vrijemePripreme': 10,
        'autorKorisnikId': 7,
        'autorIme': 'Ivan Autor',
      },
    ];
    sql.receptSastojciRows = <Map<String, Object?>>[
      <String, Object?>{
        'idRecept': 1,
        'idSastojak': 10,
        'sastojakIme': 'Mrkva',
        'oznakaVelicine': 'kom',
        'potrebnaKolicina': 2,
      },
    ];
    sql.allSastojciRows = <Map<String, Object?>>[
      <String, Object?>{
        'idSastojak': 10,
        'sastojakIme': 'Mrkva',
        'oznakaVelicine': 'kom',
        'kategorijaIme': 'Povrće',
      },
    ];

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 10);
    await tester.tap(find.text('Spremi').last);
    await _pumpUi(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('UPDATE Recept')), isTrue);

    // Reopen and trigger failure path.
    sql.throwOnUpdate = true;
    await tester.tap(find.byTooltip('Uredi'));
    await _pumpUi(tester, ticks: 10);
    await tester.tap(find.text('Spremi').last);
    await _pumpUi(tester, ticks: 10);

    expect(find.textContaining('update recept failed'), findsOneWidget);
  });

  testWidgets('delete recipe cancel and failure paths', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      recepti: <Map<String, dynamic>>[
        <String, dynamic>{
          'idRecept': 1,
          'naziv': 'Juha',
          'autorIme': 'Ivan Autor',
          'autorKorisnikId': 7,
        },
      ],
      missing: const <int, bool>{},
    );

    await tester.pumpWidget(_buildPage(repo: repo, session: const _FakeSessionStore('user@test.com')));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpUi(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Recept')), isFalse);

    sql.throwOnDelete = true;
    await tester.tap(find.byTooltip('Obriši'));
    await _pumpUi(tester, ticks: 8);
    await tester.tap(find.text('Obriši').last);
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Greška'), findsOneWidget);
    expect(find.textContaining('delete recept failed'), findsOneWidget);
  });

  testWidgets('details page renders success with missing section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReceptDetaljiPage(
          idRecept: 1,
          currentUserId: 7,
          loadReceptDetalji: _loadDetaljiOk,
          loadReceptSastojci: _loadSastojciOk,
          loadMissingSastojci: _loadMissingOk,
        ),
      ),
    );
    await _pumpUi(tester);

    expect(find.text('Detalji recepta'), findsOneWidget);
    expect(find.text('Sastojci'), findsOneWidget);
    expect(find.text('Nedostaje'), findsOneWidget);
    expect(find.textContaining('Nedostaje:'), findsOneWidget);
  });

  testWidgets('details page shows error and can retry', (tester) async {
    var fail = true;

    Future<Map<String, dynamic>?> loader(int id) async {
      if (fail) throw Exception('detail failed');
      return <String, dynamic>{
        'idRecept': 1,
        'naziv': 'Juha',
        'opis': 'Opis',
        'vrijemePripreme': 10,
        'autorKorisnikId': 1,
        'autorIme': 'Autor',
      };
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptDetaljiPage(
          idRecept: 1,
          currentUserId: null,
          loadReceptDetalji: loader,
          loadReceptSastojci: (id) async => <Map<String, dynamic>>[],
        ),
      ),
    );
    await _pumpUi(tester);

    expect(find.textContaining('detail failed'), findsOneWidget);
    fail = false;

    await tester.tap(find.text('Pokušaj ponovno').last);
    await _pumpUi(tester, ticks: 10);

    expect(find.text('Juha'), findsOneWidget);
    expect(find.text('Sastojci'), findsOneWidget);
  });
}

Future<Map<String, dynamic>?> _loadDetaljiOk(int id) async {
  return <String, dynamic>{
    'idRecept': id,
    'naziv': 'Juha',
    'opis': 'Topla juha',
    'vrijemePripreme': 20,
    'autorKorisnikId': 7,
    'autorIme': 'Ivan Autor',
  };
}

Future<List<Map<String, dynamic>>> _loadSastojciOk(int id) async {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'idSastojak': 10,
      'sastojakIme': 'Mrkva',
      'oznakaVelicine': 'kom',
      'potrebnaKolicina': 3,
    },
  ];
}

Future<List<Map<String, dynamic>>> _loadMissingOk({
  required int idRecept,
  required int idKorisnik,
}) async {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'idSastojak': 10,
      'sastojakIme': 'Mrkva',
      'potrebno': 3,
      'dostupno': 1,
      'nedostaje': 2,
      'oznakaVelicine': 'kom',
    },
  ];
}

