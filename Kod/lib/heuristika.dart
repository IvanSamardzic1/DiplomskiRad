import 'dart:math' as math;

/// 1 = dorucak, 2 = rucak, 3 = vecera
class TipObroka {
  static const int dorucak = 1;
  static const int rucak = 2;
  static const int vecera = 3;
}
// HeuristikaKandidat predstavlja sve signale koji ulaze u heuristicki score
// za jedan recept i jednog korisnika u trenutnom kontekstu.
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
  // Tezine su ručno odabrane domenski:
  // najveci utjecaj imaju navike korisnika i zalihe,
  // a vrijeme i kontekst daju dodatnu korekciju.
  static const double wZalihe = 30.0;
  static const double wFifo = 17.0;
  static const double wVrijeme = 5.0;
  static const double wNavike = 50.0;

  // Unutar navika: izvrsen je znacajno jaci signal
  static const double wOdabranUnutarNavika = 15.0;
  static const double wIzvrsenUnutarNavika = 30.0;

  // minimalna pokrivenost zaliha ispod koje se penalizira score
  static const double minCoverageSoftThreshold = 0.80;

  static double score({
    required HeuristikaKandidat c,
    required int trazeniTipObrokaId,
  }) {
    // clamp(0..1) osigurava da ulazni signali ne "pobjegnu" iz normaliziranog raspona.
    final coverage = c.pokrivenostZaliha.clamp(0.0, 1.0);
    final fifo = c.fifoSignal.clamp(0.0, 1.0);

    // Krace vrijeme -> veci score
    final vrijemeNorm = (1.0 - (c.vrijemePripremeMin / 120.0)).clamp(0.0, 1.0);

    // Povijesni count signali prolaze kroz log-normalizaciju:
    // prvih nekoliko interakcija puno znaci, kasnije se efekt smanjuje.
    final odabranNorm = _countToNorm(c.userOdabranCount);
    final izvrsenNorm = _countToNorm(c.userIzvrsenCount);

    final navike = (odabranNorm * wOdabranUnutarNavika) +
        (izvrsenNorm * wIzvrsenUnutarNavika);


    double total = 0.0;
    total += coverage * wZalihe;
    total += fifo * wFifo;
    total += vrijemeNorm * wVrijeme;
    total += navike; // vec je u bodovima 0-35

    // Penal ako je mala pokrivenost zaliha
    if (coverage < minCoverageSoftThreshold) {
      final deficit =
          (minCoverageSoftThreshold - coverage) / minCoverageSoftThreshold;
      total -= (deficit.clamp(0.0, 1.0) * 20.0);
    }

    return total.clamp(0.0, 100.0);
  }

  // topRecipeIds sortira po score-u i vraca najbolja N recepta.
  // Ovo je deterministicki i interpretabilan ranking.
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

  // Log-normalizacija count signala: prvih nekoliko odabira puno znaci, kasnije se efekt smanjuje.
  static double _countToNorm(int count) {
    if (count <= 0) return 0.0;
    final raw = math.log(1 + count) / math.log(11);
    return raw.clamp(0.0, 1.0);
  }

}
