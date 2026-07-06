import 'dart:math' as math;

/// 1 = dorucak, 2 = rucak, 3 = vecera
class TipObroka {
  static const int dorucak = 1;
  static const int rucak = 2;
  static const int vecera = 3;
}

class HeuristikaKandidat {
  final int receptId;
  final int vrijemePripremeMin;

  /// 0-1, koliko sastojaka/kolicina je pokriveno zalihama
  final double pokrivenostZaliha;

  /// 0-1, veci signal kada recept trosi namirnice s blizim rokom
  final double fifoSignal;

  /// Korisnikovi signali
  final int userOdabranCount;
  final int userIzvrsenCount;

  const HeuristikaKandidat({
    required this.receptId,
    required this.vrijemePripremeMin,
    required this.pokrivenostZaliha,
    required this.fifoSignal,
    required this.userOdabranCount,
    required this.userIzvrsenCount,
  });
}

class Heuristika {
  // Ukupno 100 bodova
  static const double wZalihe = 28.0;
  static const double wFifo = 17.0;
  static const double wVrijeme = 12.0;
  static const double wNavike = 35.0;
  static const double wContextFit = 8.0;

  // Unutar navika: izvrsen je znacajno jaci signal
  static const double wOdabranUnutarNavika = 10.0;
  static const double wIzvrsenUnutarNavika = 25.0;

  static const double minCoverageSoftThreshold = 0.80;

  static double score({
    required HeuristikaKandidat c,
    required int trazeniTipObrokaId,
  }) {
    final coverage = c.pokrivenostZaliha.clamp(0.0, 1.0);
    final fifo = c.fifoSignal.clamp(0.0, 1.0);

    // Krace vrijeme -> veci score
    final vrijemeNorm = (1.0 - (c.vrijemePripremeMin / 60.0)).clamp(0.0, 1.0);

    // Povijesni signali (saturacija kroz log)
    final odabranNorm = _countToNorm(c.userOdabranCount);
    final izvrsenNorm = _countToNorm(c.userIzvrsenCount);

    final navike = (odabranNorm * wOdabranUnutarNavika) +
        (izvrsenNorm * wIzvrsenUnutarNavika);

    final contextFit = _contextFit(
      tipObrokaId: trazeniTipObrokaId,
      vrijemePripremeMin: c.vrijemePripremeMin,
    );

    double total = 0.0;
    total += coverage * wZalihe;
    total += fifo * wFifo;
    total += vrijemeNorm * wVrijeme;
    total += navike; // vec je u bodovima 0-35
    total += contextFit * wContextFit;

    // Penal ako je mala pokrivenost zaliha
    if (coverage < minCoverageSoftThreshold) {
      final deficit =
          (minCoverageSoftThreshold - coverage) / minCoverageSoftThreshold;
      total -= (deficit.clamp(0.0, 1.0) * 20.0);
    }

    return total.clamp(0.0, 100.0);
  }

  static List<int> topRecipeIds({
    required List<HeuristikaKandidat> candidates,
    required int trazeniTipObrokaId,
    int limit = 3,
  }) {
    final scored = candidates
        .map(
          (c) => MapEntry(
        c.receptId,
        score(c: c, trazeniTipObrokaId: trazeniTipObrokaId),
      ),
    )
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  static double _countToNorm(int count) {
    if (count <= 0) return 0.0;
    final raw = math.log(1 + count) / math.log(11);
    return raw.clamp(0.0, 1.0);
  }

  /// Kontekst bez prisiljavanja recepta na tip obroka:
  /// recept moze biti bilo koji obrok, ali score varira po kontekstu.
  static double _contextFit({
    required int tipObrokaId,
    required int vrijemePripremeMin,
  }) {
    switch (tipObrokaId) {
      case TipObroka.dorucak:
        if (vrijemePripremeMin <= 20) return 1.0;
        if (vrijemePripremeMin <= 35) return 0.6;
        return 0.2;

      case TipObroka.rucak:
        if (vrijemePripremeMin <= 45) return 1.0;
        if (vrijemePripremeMin <= 70) return 0.7;
        return 0.4;

      case TipObroka.vecera:
        if (vrijemePripremeMin <= 30) return 1.0;
        if (vrijemePripremeMin <= 50) return 0.75;
        return 0.45;

      default:
        return 0.6;
    }
  }
}
