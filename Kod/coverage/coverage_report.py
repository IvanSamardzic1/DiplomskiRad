#!/usr/bin/env python3
"""Simple LCOV coverage gate for Flutter/Dart projects.

Usage:
  python coverage/coverage_report.py
  python coverage/coverage_report.py --min 60
  python coverage/coverage_report.py --lcov coverage/lcov.info --min 70
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass


@dataclass
class FileCoverage:
    path: str
    covered: int = 0
    executable_total: int = 0
    source_total: int = 0

    @property
    def percent(self) -> float:
        if self.executable_total == 0:
            return 0.0
        return (self.covered / self.executable_total) * 100.0


def parse_lcov(path: str) -> tuple[int, int]:
    """Return (covered_lines, total_lines) from an LCOV file."""
    covered = 0
    total = 0

    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if line.startswith("DA:"):
                # DA:<line number>,<execution count>[,<checksum>]
                payload = line[3:]
                parts = payload.split(",")
                if len(parts) < 2:
                    continue
                try:
                    hit_count = int(parts[1])
                except ValueError:
                    continue
                total += 1
                if hit_count > 0:
                    covered += 1

    return covered, total


def parse_lcov_per_file(path: str) -> list[FileCoverage]:
    """Return per-file coverage parsed from SF/DA LCOV records."""
    rows: dict[str, FileCoverage] = {}
    current_file: str | None = None

    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()

            if line.startswith("SF:"):
                current_file = line[3:]
                rows.setdefault(current_file, FileCoverage(path=current_file))
                continue

            if line.startswith("DA:") and current_file is not None:
                payload = line[3:]
                parts = payload.split(",")
                if len(parts) < 2:
                    continue
                try:
                    hit_count = int(parts[1])
                except ValueError:
                    continue

                rows[current_file].executable_total += 1
                if hit_count > 0:
                    rows[current_file].covered += 1

            if line == "end_of_record":
                current_file = None

    return list(rows.values())


def normalize_path(path: str) -> str:
    return path.replace("\\", "/")


def list_dart_files_under_lib() -> list[str]:
    """Return all Dart files under lib/ as normalized relative paths."""
    rows: list[str] = []
    for root, _, files in os.walk("lib"):
        for name in files:
            if not name.endswith(".dart"):
                continue
            rel = os.path.join(root, name)
            rows.append(normalize_path(rel))
    rows.sort()
    return rows


def count_source_lines(path: str) -> int:
    """Count non-empty source lines for fallback totals when LCOV has no record."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return sum(1 for line in f if line.strip())
    except OSError:
        return 0


def merge_with_all_lib_files(file_rows: list[FileCoverage]) -> list[FileCoverage]:
    """Ensure per-file output contains every lib/*.dart file.

    Coverage is based on executable LCOV lines, while source_total is reported
    as an additional informational column.
    """
    merged: dict[str, FileCoverage] = {}
    for row in file_rows:
        key = normalize_path(row.path)
        merged[key] = FileCoverage(
            path=key,
            covered=row.covered,
            executable_total=row.executable_total,
            source_total=row.source_total,
        )

    for lib_file in list_dart_files_under_lib():
        merged.setdefault(
            lib_file,
            FileCoverage(path=lib_file, covered=0, executable_total=0, source_total=0),
        )

    # Always fill source totals for reporting.
    for file_path, row in merged.items():
        row.source_total = count_source_lines(file_path)

    return list(merged.values())


def write_per_file_markdown(path: str, rows: list[FileCoverage]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Pokrivenost po datotekama (lib)\n\n")
        f.write("| Datoteka | Pokrivene linije | Testabilne linije | Ukupno linija | Pokrivenost % |\n")
        f.write("|---|---:|---:|---:|---:|\n")
        for row in rows:
            f.write(
                f"| `{row.path}` | {row.covered} | {row.executable_total} | {row.source_total} | {row.percent:.2f} |\n"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check coverage threshold from lcov.info")
    parser.add_argument("--lcov", default="coverage/lcov.info", help="Path to lcov.info file")
    parser.add_argument("--min", type=float, default=60.0, help="Minimum required coverage percent")
    parser.add_argument(
        "--per-file-out",
        default="coverage/lib_coverage_table.md",
        help="Output markdown file for per-file lib coverage table",
    )
    parser.add_argument(
        "--scope",
        default="lib/",
        help="Path fragment filter for per-file report (default: lib/)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.lcov):
        print(f"ERROR: LCOV file not found: {args.lcov}")
        print("Run: flutter test --coverage")
        return 2

    file_rows = parse_lcov_per_file(args.lcov)
    file_rows = merge_with_all_lib_files(file_rows)
    scope = args.scope.strip()
    if scope:
        file_rows = [r for r in file_rows if scope in normalize_path(r.path)]
    file_rows.sort(key=lambda r: (r.percent, normalize_path(r.path)))
    write_per_file_markdown(args.per_file_out, file_rows)

    covered = sum(r.covered for r in file_rows)
    total = sum(r.executable_total for r in file_rows)
    if total == 0:
        print("ERROR: No lines found for selected scope.")
        return 2

    percent = (covered / total) * 100.0

    print(f"Coverage: {percent:.2f}% ({covered}/{total} lines)")
    print(f"Required : {args.min:.2f}%")
    print(f"Per-file : {args.per_file_out}")

    if percent + 1e-12 < args.min:
        print("FAIL: Coverage is below required threshold.")
        return 1

    print("PASS: Coverage is at or above required threshold.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

