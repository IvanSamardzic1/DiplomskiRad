import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/heuristika.dart';

HeuristikaKandidat _kandidat({
  required int receptId,
  required int vrijeme,
  required double pokrivenost,
  required double fifo,
  required int odabran,
  required int izvrsen,
}) {
  return HeuristikaKandidat(
      receptId: receptId,
      vrijemePripremeMin: vrijeme,
      pokrivenostZaliha: pokrivenost,
      fifoSignal: fifo,
      userOdabranCount: odabran,
      userIzvrsenCount: izvrsen
  );
}

void main() {
  group('Heuristika.score', () {
    test('score je uvijek u rasponu 0-100', () {
      final kandidat = _kandidat(
        receptId: 1,
        vrijeme: 5,
        pokrivenost: 5.0,
        fifo: 5.0,
        odabran: 999,
        izvrsen: 999,
      );

      final score = Heuristika.score(
        c: kandidat,
        trazeniTipObrokaId: TipObroka.rucak,
      );

      expect(score, inInclusiveRange(0.0, 100.0));
    });

    test('veci userIzvrsenCount daje veci score od userOdabranCount', () {
      final withOdabran = _kandidat(
        receptId: 10,
        vrijeme: 20,
        pokrivenost: 1.0,
        fifo: 1.0,
        odabran: 4,
        izvrsen: 0,
      );

      final withIzvrsen = _kandidat(
        receptId: 11,
        vrijeme: 20,
        pokrivenost: 1.0,
        fifo: 1.0,
        odabran: 0,
        izvrsen: 4,
      );

      final scoreOdabran = Heuristika.score(
        c: withOdabran,
        trazeniTipObrokaId: TipObroka.rucak,
      );
      final scoreIzvrsen = Heuristika.score(
        c: withIzvrsen,
        trazeniTipObrokaId: TipObroka.rucak,
      );

      expect(scoreIzvrsen, greaterThan(scoreOdabran));
    });

    test('niza pokrivenost zaliha aktivira penal i smanjuje score', () {
      final goodCoverage = _kandidat(
        receptId: 20,
        vrijeme: 20,
        pokrivenost: 1.0,
        fifo: 0.8,
        odabran: 1,
        izvrsen: 1,
      );

      final lowCoverage = _kandidat(
        receptId: 21,
        vrijeme: 20,
        pokrivenost: 0.3,
        fifo: 0.8,
        odabran: 1,
        izvrsen: 1,
      );

      final scoreGood = Heuristika.score(
        c: goodCoverage,
        trazeniTipObrokaId: TipObroka.rucak,
      );
      final scoreLow = Heuristika.score(
        c: lowCoverage,
        trazeniTipObrokaId: TipObroka.rucak,
      );

      expect(scoreLow, lessThan(scoreGood));
    });
  });

  group('Heuristika.topRecipeIds', () {
    test('vraca recepte sortirane po score-u i postuje limit', () {
      final kandidati = [
        _kandidat(
          receptId: 1,
          vrijeme: 18,
          pokrivenost: 1.0,
          fifo: 1.0,
          odabran: 4,
          izvrsen: 4,
        ),
        _kandidat(
          receptId: 2,
          vrijeme: 55,
          pokrivenost: 0.4,
          fifo: 0.3,
          odabran: 0,
          izvrsen: 0,
        ),
        _kandidat(
          receptId: 3,
          vrijeme: 25,
          pokrivenost: 0.9,
          fifo: 0.9,
          odabran: 2,
          izvrsen: 3,
        ),
      ];

      final top = Heuristika.topRecipeIds(
        candidates: kandidati,
        trazeniTipObrokaId: TipObroka.rucak,
        limit: 2,
      );

      expect(top.length, 2);
      expect(top.first, 1);
      expect(top, isNot(contains(2)));
    });
  });
}