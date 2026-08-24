import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/authscreen.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/home.dart';
import 'package:projekt_prvaverzija/main.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';
import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/trgovina.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final Uint8List logoBytes = File('assets/slike/logo.png').readAsBytesSync();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    DbQueries.setSqlExecutorsForTesting(
      query: (sql) async => <Map<String, Object?>>[],
      execute: (sql) async {},
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
              'assets/weights.json': <Map<String, Object?>>[
                <String, Object?>{'asset': 'assets/weights.json', 'dpr': 1.0},
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

        if (requested.endsWith('.json')) {
          final bytes = Uint8List.fromList(utf8.encode('{}'));
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

  testWidgets('MyApp konfigurira MaterialApp i AuthGate', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AuthGate), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.routes?.containsKey('/home'), isTrue);
  });

  testWidgets('AuthGate prikazuje AuthScreen kada korisnik nije prijavljen',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': false});

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('AuthGate otvara MyHomePage kada je korisnik prijavljen',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': true});

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();

    expect(find.byType(MyHomePage), findsOneWidget);
    expect(find.text('Aplikacija za praćenje namirnica'), findsOneWidget);
  });

  testWidgets('MyHomePage ima 5 kartica i mijenja ekran klikom',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'Aplikacija za praćenje namirnica'),
      ),
    );

    expect(find.byType(HomePage), findsOneWidget);

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.length, 5);
    expect(nav.currentIndex, 0);

    await tester.tap(find.text('Moje namirnice'));
    await tester.pumpAndSettle();
    expect(find.byType(ZalihaNamirnicePage), findsOneWidget);

    await tester.tap(find.text('Trgovina'));
    await tester.pumpAndSettle();
    expect(find.byType(TrgovinaPage), findsOneWidget);

    await tester.tap(find.text('Recepti'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceptiPage), findsOneWidget);

    await tester.tap(find.text('Plan prehrane'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanPrehranePage), findsOneWidget);
  });
}

