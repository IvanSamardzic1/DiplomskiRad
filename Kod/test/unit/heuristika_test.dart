import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/heuristika.dart';

void main() {
  HeuristikaKandidat kandidat({
    required int receptId,
    required int vrijemePripremeMin,
    required double pokrivenostZaliha,
    required double fifoSignal,
    required int userOdabranCount,
    required int userIzvrsenCount,
  }) {
    return HeuristikaKandidat(
      receptId: receptId,
      vrijemePripremeMin: vrijemePripremeMin,
      pokrivenostZaliha: pokrivenostZaliha,
      fifoSignal: fifoSignal,
      userOdabranCount: userOdabranCount,
      userIzvrsenCount: userIzvrsenCount,
    );
  }

  group('Heuristika.score', () {
    test('uvijek vraca score u intervalu 0..100', () {
      final low = Heuristika.score(
        c: kandidat(
          receptId: 1,
          vrijemePripremeMin: 999,
          pokrivenostZaliha: -5.0,
          fifoSignal: -3.0,
          userOdabranCount: 0,
          userIzvrsenCount: 0,
        ),
        trazeniTipObrokaId: TipObroka.rucak,
      );

      final high = Heuristika.score(
        c: kandidat(
          receptId: 2,
          vrijemePripremeMin: 1,
          pokrivenostZaliha: 5.0,
          fifoSignal: 3.0,
          userOdabranCount: 999,
          userIzvrsenCount: 999,
        ),
        trazeniTipObrokaId: TipObroka.rucak,
      );

      expect(low, inInclusiveRange(0.0, 100.0));
      expect(high, inInclusiveRange(0.0, 100.0));
    });

    test('penalizira pokrivenost ispod soft thresholda (0.80)', () {
      final justBelow = Heuristika.score(
        c: kandidat(
          receptId: 10,
          vrijemePripremeMin: 25,
          pokrivenostZaliha: 0.79,
          fifoSignal: 0.5,
          userOdabranCount: 2,
          userIzvrsenCount: 2,
        ),
        trazeniTipObrokaId: TipObroka.rucak,
      );

      final atThreshold = Heuristika.score(
        c: kandidat(
          receptId: 11,
          vrijemePripremeMin: 25,
          pokrivenostZaliha: 0.80,
          fifoSignal: 0.5,
          userOdabranCount: 2,
          userIzvrsenCount: 2,
        ),
        trazeniTipObrokaId: TipObroka.rucak,
      );

      expect(atThreshold, greaterThan(justBelow));
    });

    test('za dorucak preferira krace vrijeme pripreme', () {
      final fast = Heuristika.score(
        c: kandidat(
          receptId: 20,
          vrijemePripremeMin: 15,
          pokrivenostZaliha: 0.9,
          fifoSignal: 0.7,
          userOdabranCount: 1,
          userIzvrsenCount: 1,
        ),
        trazeniTipObrokaId: TipObroka.dorucak,
      );

      final slow = Heuristika.score(
        c: kandidat(
          receptId: 21,
          vrijemePripremeMin: 45,
          pokrivenostZaliha: 0.9,
          fifoSignal: 0.7,
          userOdabranCount: 1,
          userIzvrsenCount: 1,
        ),
        trazeniTipObrokaId: TipObroka.dorucak,
      );

      expect(fast, greaterThan(slow));
    });

    test('veci user history signal povecava score', () {
      final weakHistory = Heuristika.score(
        c: kandidat(
          receptId: 30,
          vrijemePripremeMin: 25,
          pokrivenostZaliha: 0.85,
          fifoSignal: 0.6,
          userOdabranCount: 0,
          userIzvrsenCount: 0,
        ),
        trazeniTipObrokaId: TipObroka.vecera,
      );

      final strongHistory = Heuristika.score(
        c: kandidat(
          receptId: 31,
          vrijemePripremeMin: 25,
          pokrivenostZaliha: 0.85,
          fifoSignal: 0.6,
          userOdabranCount: 10,
          userIzvrsenCount: 10,
        ),
        trazeniTipObrokaId: TipObroka.vecera,
      );

      expect(strongHistory, greaterThan(weakHistory));
    });
  });

  group('Heuristika.topRecipeIds', () {
    test('sortira po score-u silazno i postuje limit', () {
      final candidates = <HeuristikaKandidat>[
        kandidat(
          receptId: 100,
          vrijemePripremeMin: 15,
          pokrivenostZaliha: 0.95,
          fifoSignal: 0.9,
          userOdabranCount: 4,
          userIzvrsenCount: 4,
        ),
        kandidat(
          receptId: 200,
          vrijemePripremeMin: 60,
          pokrivenostZaliha: 0.40,
          fifoSignal: 0.2,
          userOdabranCount: 0,
          userIzvrsenCount: 0,
        ),
        kandidat(
          receptId: 300,
          vrijemePripremeMin: 20,
          pokrivenostZaliha: 0.90,
          fifoSignal: 0.8,
          userOdabranCount: 1,
          userIzvrsenCount: 1,
        ),
      ];

      final top = Heuristika.topRecipeIds(
        candidates: candidates,
        trazeniTipObrokaId: TipObroka.dorucak,
        limit: 2,
      );

      expect(top, hasLength(2));
      expect(top.first, 100);
    });

    test('za prazan ulaz vraca prazan popis', () {
      final top = Heuristika.topRecipeIds(
        candidates: const <HeuristikaKandidat>[],
        trazeniTipObrokaId: TipObroka.rucak,
        limit: 3,
      );

      expect(top, isEmpty);
    });

    test('kad je limit veci od broja kandidata vraca sve', () {
      final candidates = <HeuristikaKandidat>[
        kandidat(
          receptId: 1,
          vrijemePripremeMin: 20,
          pokrivenostZaliha: 0.8,
          fifoSignal: 0.5,
          userOdabranCount: 0,
          userIzvrsenCount: 0,
        ),
        kandidat(
          receptId: 2,
          vrijemePripremeMin: 30,
          pokrivenostZaliha: 0.7,
          fifoSignal: 0.4,
          userOdabranCount: 0,
          userIzvrsenCount: 0,
        ),
      ];

      final top = Heuristika.topRecipeIds(
        candidates: candidates,
        trazeniTipObrokaId: TipObroka.vecera,
        limit: 10,
      );

      expect(top, hasLength(2));
      expect(top.toSet(), {1, 2});
    });
  });
}
