import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class MlScoring {
  late final List<String> featureOrder;
  late final List<double> coef;
  late final double intercept;
  late final List<double> mean;
  late final List<double> scale;

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
    double z = intercept;
    for (int i = 0; i < featureOrder.length; i++) {
      final key = featureOrder[i];
      final x = _toDouble(features[key]);
      final s = scale[i] == 0 ? 1.0 : scale[i];
      final xs = (x - mean[i]) / s;
      z += coef[i] * xs;
    }
    return 1.0 / (1.0 + exp(-z));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? 0.0;
  }
}
