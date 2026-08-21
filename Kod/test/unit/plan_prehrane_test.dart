import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';
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
  final List<Map<String, dynamic>> vrste;
  final List<Map<String, dynamic>> plan;
  final List<Map<String, dynamic>> recepti;

  const _FakeRepository({
    required this.userId,
    required this.vrste,
    required this.plan,
    required this.recepti,
  });

  @override
  Future<int?> getUserIdByMail(String mail) async => userId;

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() async => vrste;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime today;
  late DateTime tomorrow;

  setUp(() {
    today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    tomorrow = today.add(const Duration(days: 1));

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
            utf8.encode(
              '{"assets/slike/logo.png":["assets/slike/logo.png"],"assets/weights.json":["assets/weights.json"]}',
            ),
          );
          return ByteData.view(bytes.buffer);
        }

        if (requested == 'assets/weights.json') {
          final bytes = Uint8List.fromList(utf8.encode('{}'));
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
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('renders loaded meal card for today', (tester) async {
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
    expect(find.text('Plan za sljedeća 3 dana'), findsOneWidget);
    expect(find.text('Varivo'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('renders page structure for logged user even with empty plan', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
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
  });

  testWidgets('handles missing logged user email without crash', (tester) async {
    final repo = _FakeRepository(
      userId: 7,
      vrste: const <Map<String, dynamic>>[],
      plan: const <Map<String, dynamic>>[],
      recepti: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      _buildPage(repo: repo, session: const _FakeSessionStore('')),
    );
    await _pumpUi(tester);

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

}

