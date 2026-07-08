import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/ml_scoring.dart';

void main() {
  // Potrebno za rootBundle/loadFromAsset u testovima.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MlScoring.predictProbability', () {
    //test da vraca vrijednosti u rasponu 0-1
    test('vraca vrijednost u rasponu 0-1', () {
      final ml = MlScoring()
        ..featureOrder = ['a', 'b']
        ..coef = [0.4, -0.2]
        ..intercept = 0.1
        ..mean = [0.0, 0.0]
        ..scale = [1.0, 1.0];

      final p = ml.predictProbability({'a': 1, 'b': 2});

      expect(p, inInclusiveRange(0.0, 1.0));
    });

    test('prihvaca i string vrijednosti feature-a bez rusenja', () {
      final ml = MlScoring()
        ..featureOrder = ['tipObroka', 'vrijemePripremeMin']
        ..coef = [0.3, -0.2]
        ..intercept = 0.0
        ..mean = [1.0, 10.0]
        ..scale = [1.0, 5.0];

      final p = ml.predictProbability({
        'tipObroka': '2',
        'vrijemePripremeMin': '15,5',
      });

      expect(p, inInclusiveRange(0.0, 1.0));
    });

    test('scale=0 koristi fallback 1.0 i ne baca gresku', () {
      final ml = MlScoring()
        ..featureOrder = ['x']
        ..coef = [1.0]
        ..intercept = 0.0
        ..mean = [0.0]
        ..scale = [0.0];

      final p = ml.predictProbability({'x': 3});

      expect(p, inInclusiveRange(0.0, 1.0));
    });
  });

  group('MlScoring.loadFromAsset', () {
    test('ucitava model iz assets/weights.json', () async {
      final ml = MlScoring();
      await ml.loadFromAsset('assets/weights.json');

      expect(ml.featureOrder, isNotEmpty);
      expect(ml.coef.length, ml.featureOrder.length);
      expect(ml.mean.length, ml.featureOrder.length);
      expect(ml.scale.length, ml.featureOrder.length);
    });
  });
}
