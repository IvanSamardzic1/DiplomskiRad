import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/ml_scoring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MlScoring.loadFromAsset', () {
    const assetChannel = 'flutter/assets';
    const assetPath = 'assets/test_weights.json';

    setUp(() {
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        assetChannel,
        (ByteData? message) async {
          if (message == null) return null;
          final requested = utf8.decode(message.buffer.asUint8List());
          if (requested != assetPath) return null;

          final json = '{"feature_order":["a","b"],"coef":[1.5,"-2,0"],"intercept":"0,5","mean":[1,0],"scale":[2,4]}';
          final bytes = Uint8List.fromList(utf8.encode(json));
          return ByteData.view(bytes.buffer);
        },
      );
    });

    tearDown(() {
      ServicesBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(assetChannel, null);
    });

    test('ucitava model iz asset JSON-a i mapira vrijednosti', () async {
      final ml = MlScoring();

      await ml.loadFromAsset(assetPath);

      expect(ml.featureOrder, ['a', 'b']);
      expect(ml.coef, [1.5, -2.0]);
      expect(ml.intercept, 0.5);
      expect(ml.mean, [1.0, 0.0]);
      expect(ml.scale, [2.0, 4.0]);

      final p = ml.predictProbability({'a': 3, 'b': 2});
      expect(p, inInclusiveRange(0.0, 1.0));
    });
  });

  group('MlScoring.predictProbability', () {
    test('vraca 0.5 kad je linearni skor z = 0', () {
      final ml = MlScoring()
        ..featureOrder = ['x1']
        ..coef = [1.0]
        ..intercept = 0.0
        ..mean = [0.0]
        ..scale = [1.0];

      final p = ml.predictProbability({'x1': 0});

      expect(p, closeTo(0.5, 1e-12));
    });

    test('veci feature signal daje vecu vjerojatnost', () {
      final ml = MlScoring()
        ..featureOrder = ['x1']
        ..coef = [1.2]
        ..intercept = -0.5
        ..mean = [0.0]
        ..scale = [1.0];

      final low = ml.predictProbability({'x1': 0});
      final high = ml.predictProbability({'x1': 3});

      expect(high, greaterThan(low));
    });

    test('ispravno parsira brojeve iz stringa (uklj. decimalni zarez)', () {
      final ml = MlScoring()
        ..featureOrder = ['a', 'b']
        ..coef = [1.0, 1.0]
        ..intercept = 0.0
        ..mean = [0.0, 0.0]
        ..scale = [1.0, 1.0];

      // a = "1,5" -> 1.5 ; b = "neispravno" -> 0.0
      final p = ml.predictProbability({'a': '1,5', 'b': 'neispravno'});

      final expected = 1.0 / (1.0 + exp(-1.5));
      expect(p, closeTo(expected, 1e-12));
    });

    test('null i nepostojeci feature tretira kao 0.0', () {
      final ml = MlScoring()
        ..featureOrder = ['a', 'b']
        ..coef = [0.7, -0.2]
        ..intercept = 0.1
        ..mean = [0.0, 0.0]
        ..scale = [1.0, 1.0];

      final p1 = ml.predictProbability({'a': null});
      final p2 = ml.predictProbability({});

      expect(p1, closeTo(p2, 1e-12));
    });

    test('kad je scale 0 koristi fallback 1.0', () {
      final ml = MlScoring()
        ..featureOrder = ['x1']
        ..coef = [2.0]
        ..intercept = 0.0
        ..mean = [1.0]
        ..scale = [0.0]; // fallback u kodu

      final p = ml.predictProbability({'x1': 2.0});
      final expected = 1.0 / (1.0 + exp(-2.0)); // (2 - 1)/1 = 1, z = 2

      expect(p, closeTo(expected, 1e-12));
    });
  });
}

