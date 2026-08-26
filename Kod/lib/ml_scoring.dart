import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class MlScoring {
  late final List<String> featureOrder;
  late final List<double> coef;
  late final double intercept;
  late final List<double> mean;
  late final List<double> scale;

  // Model se ucitava iz JSON-a koji je exportan iz Python-a (sklearn).
  // JSON sadrzi feature_order, coef, intercept, mean i scale.
  Future<void> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final j = jsonDecode(raw) as Map<String, dynamic>;

    featureOrder = (j['feature_order'] as List).map((e) => e.toString()).toList();
    coef = (j['coef'] as List).map((e) => _toDouble(e)).toList();
    intercept = _toDouble(j['intercept']);
    mean = (j['mean'] as List).map((e) => _toDouble(e)).toList();
    scale = (j['scale'] as List).map((e) => _toDouble(e)).toList();
  }

  double predictProbability(Map<String, dynamic> features) {
    // z je linearni skor logisticke regresije
    // z = intercept + sum(coef[i] * (features[i] - mean[i]) / scale[i])
    double z = intercept;
    for (int i = 0; i < featureOrder.length; i++) {
      final key = featureOrder[i];
      final x = _toDouble(features[key]);
      //sigurno scale[i] ne smije biti 0, ali ako je, postavljamo na 1.0 da izbjegnemo dijeljenje s nulom
      final s = scale[i] == 0 ? 1.0 : scale[i];
      final xs = (x - mean[i]) / s;
      z += coef[i] * xs;
    }
    // primjenjujemo sigmoidnu funkciju da dobijemo vjerojatnost
    return 1.0 / (1.0 + exp(-z));
  }

  // _toDouble konvertira dynamic vrijednost u double, ako je null vraca 0.0, ako je num vraca toDouble, inace pokusava parsirati string u double
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? 0.0;
  }
}
