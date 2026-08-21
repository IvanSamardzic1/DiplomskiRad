import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/authscreen.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
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

class _SqlQueue {
  final List<List<Map<String, Object?>>> _queryResults = <List<Map<String, Object?>>>[];
  final List<String> executedSql = <String>[];

  void queueQueryResult(List<Map<String, Object?>> rows) {
    _queryResults.add(rows);
  }

  Future<List<Map<String, Object?>>> query(String sql) async {
    if (_queryResults.isEmpty) return <Map<String, Object?>>[];
    return _queryResults.removeAt(0);
  }

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }
}

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('HOME_SCREEN')),
    },
    home: const AuthScreen(),
  );
}

Future<void> _openRegisterTab(WidgetTester tester) async {
  await tester.tap(find.text('Register'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SqlQueue sql;

  setUp(() {
    sql = _SqlQueue();
    SharedPreferences.setMockInitialValues(<String, Object>{});

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

  testWidgets('prikazuje Login i Register tabove', (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsWidgets);
  });

  testWidgets('login validacija prikazuje greske za neispravan unos', (tester) async {
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Email je obavezno polje'), findsOneWidget);
    expect(find.text('Lozinka je obavezno polje'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'neispravno');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'abc');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Unesite ispravan email'), findsOneWidget);
  });

  testWidgets('login prikazuje dialog kad korisnik ne postoji', (tester) async {
    sql.queueQueryResult(<Map<String, Object?>>[]);

    await tester.pumpWidget(_buildApp());
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'none@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'Lozinka1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Korisnik s tim emailom ne postoji.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('login prikazuje dialog kad lozinka nije tocna', (tester) async {
    sql
      ..queueQueryResult(<Map<String, Object?>>[
        <String, Object?>{
          'email': 'user@test.com',
          'lozinkaHash': DbQueries.hashPassword('DobraLozinka1'),
          'ime': 'Ime',
          'prezime': 'Prezime',
        }
      ])
      ..queueQueryResult(<Map<String, Object?>>[
        <String, Object?>{
          'email': 'user@test.com',
          'lozinkaHash': DbQueries.hashPassword('DobraLozinka1'),
          'ime': 'Ime',
          'prezime': 'Prezime',
        }
      ]);

    await tester.pumpWidget(_buildApp());
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'KrivaLozinka1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Pogrešna lozinka.'), findsOneWidget);
  });

  testWidgets('uspjesan login sprema session i navigira na /home', (tester) async {
    final hash = DbQueries.hashPassword('Lozinka1');
    sql
      ..queueQueryResult(<Map<String, Object?>>[
        <String, Object?>{'email': 'user@test.com', 'lozinkaHash': hash, 'ime': 'A', 'prezime': 'B'}
      ])
      ..queueQueryResult(<Map<String, Object?>>[
        <String, Object?>{'email': 'user@test.com', 'lozinkaHash': hash, 'ime': 'A', 'prezime': 'B'}
      ]);

    await tester.pumpWidget(_buildApp());
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'Lozinka1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_SCREEN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isTrue);
    expect(prefs.getString('loggedInEmail'), 'user@test.com');
  });

  testWidgets('register validacija lozinke i potvrde', (tester) async {
    await tester.pumpWidget(_buildApp());
    await _openRegisterTab(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ime'), 'Ivo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezime'), 'Ivic');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ivo@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'abc');
    await tester.enterText(find.widgetWithText(TextFormField, 'Potvrdi lozinku'), 'abcd');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Lozinka mora imati barem 8 znakova'), findsOneWidget);
    expect(find.text('Lozinke se ne podudaraju'), findsOneWidget);
  });

  testWidgets('register prikazuje dialog kad mail vec postoji', (tester) async {
    sql.queueQueryResult(<Map<String, Object?>>[
      <String, Object?>{
        'email': 'ivo@test.com',
        'lozinkaHash': 'hash',
        'ime': 'Ivo',
        'prezime': 'Ivic',
      }
    ]);

    await tester.pumpWidget(_buildApp());
    await _openRegisterTab(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ime'), 'Ivo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezime'), 'Ivic');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ivo@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'Lozinka1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Potvrdi lozinku'), 'Lozinka1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Ovaj mail je već registriran.'), findsOneWidget);
  });

  testWidgets('uspjesan register radi insert, sprema session i navigira', (tester) async {
    sql.queueQueryResult(<Map<String, Object?>>[]);

    await tester.pumpWidget(_buildApp());
    await _openRegisterTab(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ime'), 'Ivo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezime'), 'Ivic');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ivo@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'Lozinka1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Potvrdi lozinku'), 'Lozinka1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(sql.executedSql, hasLength(1));
    expect(sql.executedSql.first.contains('INSERT INTO Korisnik'), isTrue);
    expect(find.text('HOME_SCREEN'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isTrue);
    expect(prefs.getString('loggedInEmail'), 'ivo@test.com');
  });
}

