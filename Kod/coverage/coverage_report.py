"""
Jednostavan generator izvjestaja o pokrivenosti koda iz lcov.info datoteke,
bez potrebe za instaliranim `genhtml` alatom.

Pokretanje:
    flutter test --coverage
    python coverage/coverage_report.py

Generira:
    coverage/coverage_summary.txt  - tekstualni sazetak po datoteci
    coverage/html/index.html       - jednostavan HTML izvjestaj s postocima
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LCOV_PATH = ROOT / "coverage" / "lcov.info"
OUT_TXT = ROOT / "coverage" / "coverage_summary.txt"
OUT_HTML_DIR = ROOT / "coverage" / "html"
OUT_HTML = OUT_HTML_DIR / "index.html"
MIN_COVERAGE = 60.0


def parse_lcov(path: Path):
    files = []
    current = None

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                current = {"path": line[3:], "lines": {}}
            elif line.startswith("DA:"):
                # DA:<line_number>,<hit_count>
                m = re.match(r"DA:(\d+),(\d+)", line)
                if m and current is not None:
                    ln, hits = int(m.group(1)), int(m.group(2))
                    current["lines"][ln] = hits
            elif line == "end_of_record":
                if current is not None:
                    files.append(current)
                current = None

    return files


def compute_summary(files):
    rows = []
    total_lines = 0
    total_hit = 0

    for f in files:
        lines = f["lines"]
        n_lines = len(lines)
        n_hit = sum(1 for h in lines.values() if h > 0)
        pct = (n_hit / n_lines * 100) if n_lines else 0.0

        rel = f["path"]
        try:
            rel = str(Path(f["path"]).resolve().relative_to(ROOT))
        except Exception:
            pass

        rows.append({
            "file": rel,
            "lines": n_lines,
            "hit": n_hit,
            "pct": pct,
        })

        total_lines += n_lines
        total_hit += n_hit

    rows.sort(key=lambda r: r["pct"])
    total_pct = (total_hit / total_lines * 100) if total_lines else 0.0
    return rows, total_lines, total_hit, total_pct


def write_txt(rows, total_lines, total_hit, total_pct):
    with open(OUT_TXT, "w", encoding="utf-8") as f:
        f.write(f"{'Datoteka':<55} {'Pokriveno':>12} {'Ukupno':>8} {'%':>7}\n")
        f.write("-" * 90 + "\n")
        for r in rows:
            f.write(
                f"{r['file']:<55} {r['hit']:>12} {r['lines']:>8} {r['pct']:>6.1f}%\n"
            )
        f.write("-" * 90 + "\n")
        f.write(
            f"{'UKUPNO':<55} {total_hit:>12} {total_lines:>8} {total_pct:>6.1f}%\n"
        )
    print(f"Tekstualni sazetak spremljen u: {OUT_TXT}")


def write_html(rows, total_lines, total_hit, total_pct):
    OUT_HTML_DIR.mkdir(parents=True, exist_ok=True)

    def color_for(pct):
        if pct >= 80:
            return "#2e7d32"  # zeleno
        if pct >= 50:
            return "#f9a825"  # zuto
        return "#c62828"  # crveno

    rows_html = "\n".join(
        f"""
        <tr>
          <td>{r['file']}</td>
          <td style="text-align:right">{r['hit']}</td>
          <td style="text-align:right">{r['lines']}</td>
          <td style="text-align:right; color:{color_for(r['pct'])}; font-weight:bold">
            {r['pct']:.1f}%
          </td>
          <td>
            <div style="background:#eee; width:200px; height:10px; border-radius:4px; overflow:hidden;">
              <div style="background:{color_for(r['pct'])}; width:{r['pct']:.1f}%; height:100%;"></div>
            </div>
          </td>
        </tr>
        """
        for r in rows
    )

    html = f"""<!DOCTYPE html>
<html lang="hr">
<head>
<meta charset="UTF-8">
<title>Coverage izvjestaj</title>
<style>
  body {{ font-family: Arial, sans-serif; margin: 24px; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ padding: 6px 10px; border-bottom: 1px solid #ddd; font-size: 14px; }}
  th {{ text-align: left; background: #fafafa; }}
  tfoot td {{ font-weight: bold; border-top: 2px solid #333; }}
  h1 {{ font-size: 20px; }}
</style>
</head>
<body>
  <h1>Izvjestaj o pokrivenosti koda testovima</h1>
  <p>Ukupna pokrivenost: <strong style="color:{color_for(total_pct)}">{total_pct:.1f}%</strong>
     ({total_hit} / {total_lines} linija)</p>
  <table>
    <thead>
      <tr><th>Datoteka</th><th>Pokriveno</th><th>Ukupno</th><th>%</th><th></th></tr>
    </thead>
    <tbody>
      {rows_html}
    </tbody>
    <tfoot>
      <tr><td>UKUPNO</td><td style="text-align:right">{total_hit}</td>
          <td style="text-align:right">{total_lines}</td>
          <td style="text-align:right">{total_pct:.1f}%</td><td></td></tr>
    </tfoot>
  </table>
</body>
</html>
"""
    with open(OUT_HTML, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"HTML izvjestaj spremljen u: {OUT_HTML}")


def main():
    if not LCOV_PATH.exists():
        print(f"Nije pronadjen {LCOV_PATH}. Prvo pokreni: flutter test --coverage")
        return

    files = parse_lcov(LCOV_PATH)
    if not files:
        print("lcov.info je prazan ili nije u ocekivanom formatu.")
        return

    rows, total_lines, total_hit, total_pct = compute_summary(files)

    print(f"\nUkupna pokrivenost: {total_pct:.1f}% ({total_hit}/{total_lines} linija)\n")
    for r in rows:
        print(f"  {r['pct']:>5.1f}%  {r['file']}  ({r['hit']}/{r['lines']})")

    write_txt(rows, total_lines, total_hit, total_pct)
    write_html(rows, total_lines, total_hit, total_pct)

    if total_pct < MIN_COVERAGE:
        print(
            f"\nERROR: Pokrivenost je {total_pct:.1f}%, a minimum je {MIN_COVERAGE:.1f}%."
        )
        sys.exit(1)


if __name__ == "__main__":
    main()

