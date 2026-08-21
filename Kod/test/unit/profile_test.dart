import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x01, 0x73, 0x52, 0x47, 0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00,
  0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _SqlSpy {
  final List<String> queriedSql = <String>[];
  final List<String> executedSql = <String>[];

  List<Map<String, Object?>> userRows = <Map<String, Object?>>[];

  Future<List<Map<String, Object?>>> query(String sql) async {
    queriedSql.add(sql);

    if (sql.contains('FROM Korisnik') && sql.contains('SELECT TOP 1 email')) {
      return userRows;
    }

    return <Map<String, Object?>>[];
  }

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }
}

Widget _buildApp() {
  return MaterialApp(
    initialRoute: '/profile',
    routes: {
      '/': (_) => const Scaffold(body: Text('ROOT_SCREEN')),
      '/profile': (_) => const ProfilePage(),
    },
  );
}

Future<void> _pumpReady(WidgetTester tester, {int ticks = 16}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SqlSpy sql;

  setUp(() {
    sql = _SqlSpy();

    DbQueries.setSqlExecutorsForTesting(
      query: sql.query,
      execute: sql.execute,
    );

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

  testWidgets('loads profile fields and shows initials when user exists', (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'loggedInEmail': 'user@test.com', 'isLoggedIn': true},
    );

    sql.userRows = <Map<String, Object?>>[
      <String, Object?>{
        'email': 'user@test.com',
        'lozinkaHash': 'hash',
        'ime': 'Ivan',
        'prezime': 'Matic',
      }
    ];

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    expect(find.text('Profil korisnika'), findsOneWidget);
    expect(find.text('Ivan'), findsOneWidget);
    expect(find.text('Matic'), findsOneWidget);
    expect(find.text('user@test.com'), findsOneWidget);
    expect(find.text('IM'), findsOneWidget);

    expect(find.text('Odjava'), findsOneWidget);
    expect(find.text('Obriši korisnika'), findsOneWidget);
  });

  testWidgets('shows fallback initials ? when no user data is returned', (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'loggedInEmail': 'missing@test.com', 'isLoggedIn': true},
    );

    sql.userRows = <Map<String, Object?>>[];

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    expect(find.text('?'), findsOneWidget);
    expect(find.text('missing@test.com'), findsOneWidget);
  });

  testWidgets('does not query DB when loggedInEmail is empty', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': true});

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    expect(
      sql.queriedSql.any((s) => s.contains('FROM Korisnik') && s.contains('SELECT TOP 1 email')),
      isFalse,
    );
  });

  testWidgets('logout clears session and navigates to root', (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'loggedInEmail': 'user@test.com', 'isLoggedIn': true},
    );

    sql.userRows = <Map<String, Object?>>[
      <String, Object?>{
        'email': 'user@test.com',
        'lozinkaHash': 'hash',
        'ime': 'Ivan',
        'prezime': 'Matic',
      }
    ];

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    await tester.tap(find.text('Odjava'));
    await _pumpReady(tester, ticks: 8);

    expect(find.text('ROOT_SCREEN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isFalse);
    expect(prefs.getString('loggedInEmail'), isNull);
  });

  testWidgets('delete account cancelled does not delete user', (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'loggedInEmail': 'user@test.com', 'isLoggedIn': true},
    );

    sql.userRows = <Map<String, Object?>>[
      <String, Object?>{
        'email': 'user@test.com',
        'lozinkaHash': 'hash',
        'ime': 'Ivan',
        'prezime': 'Matic',
      }
    ];

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    await tester.tap(find.text('Obriši korisnika'));
    await _pumpReady(tester, ticks: 8);

    expect(find.text('Brisanje računa'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await _pumpReady(tester, ticks: 8);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Korisnik')), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isTrue);
    expect(find.text('ROOT_SCREEN'), findsNothing);
  });

  testWidgets('delete account confirmed deletes user, clears session and navigates',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'loggedInEmail': 'user@test.com', 'isLoggedIn': true},
    );

    sql.userRows = <Map<String, Object?>>[
      <String, Object?>{
        'email': 'user@test.com',
        'lozinkaHash': 'hash',
        'ime': 'Ivan',
        'prezime': 'Matic',
      }
    ];

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    await tester.tap(find.text('Obriši korisnika'));
    await _pumpReady(tester, ticks: 8);

    await tester.tap(find.widgetWithText(TextButton, 'Obriši'));
    await _pumpReady(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Korisnik')), isTrue);
    expect(find.text('ROOT_SCREEN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isFalse);
    expect(prefs.getString('loggedInEmail'), isNull);
  });

  testWidgets('delete account confirmed with empty email still clears session and navigates',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': true});

    await tester.pumpWidget(_buildApp());
    await _pumpReady(tester);

    await tester.tap(find.text('Obriši korisnika'));
    await _pumpReady(tester, ticks: 8);

    await tester.tap(find.widgetWithText(TextButton, 'Obriši'));
    await _pumpReady(tester, ticks: 10);

    expect(sql.executedSql.any((s) => s.contains('DELETE FROM Korisnik')), isFalse);
    expect(find.text('ROOT_SCREEN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isFalse);
  });
}

