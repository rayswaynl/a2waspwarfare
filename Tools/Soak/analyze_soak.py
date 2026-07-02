#!/usr/bin/env python3
"""
Summarize WASP Warfare soak RPT logs by build.

The parser is intentionally tolerant: Build 86 logs mix pipe-delimited telemetry
with plain diag_log / LogContent strings, and an RPT can contain appended server
sessions. Feed one or more RPT/log/text files and the tool emits a compact KPI
table plus optional CSV/JSON/Markdown artifacts.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from statistics import mean
from typing import Dict, Iterable, List, Optional, Tuple


NUMBER_RE = re.compile(r"[-+]?\d+(?:\.\d+)?")
KEYVAL_RE = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([^|,\s]+)")
SKIN_STAGE_RE = re.compile(r"\[WFBE \(SKIN\)\]\s*(B[0-9][A-Za-z]?)?\s*([^:]+)?", re.IGNORECASE)
BUILD_ROAD_RE = re.compile(r"\b(BUILD_ROAD_[A-Z0-9_]+|BUILD_ROAD|ROAD-CLEAR|road-clear|ONROAD!)\b", re.IGNORECASE)
NAVAL_SKIP_RE = re.compile(r"\b(naval[-_ ]?skip|PATROL[_-]?NAVAL[_-]?SKIP|naval town patrol exclusion)\b", re.IGNORECASE)
SCUD_RE = re.compile(r"(SCUD|ScudStrike|TEL|MAZ_543|9P117|SAT|RECON|FASCAM|STEELRAIN|BUSTER)", re.IGNORECASE)
EASA_GEAR_RE = re.compile(r"\b(EASA|GEAR|LOADOUT|WFBE_EASA|GUI_Menu_EASA|BuyGear)\b", re.IGNORECASE)


@dataclass
class BuildStats:
    build: str
    files: List[str] = field(default_factory=list)
    lines: int = 0
    first_timestamp: str = ""
    last_timestamp: str = ""
    counters: Counter = field(default_factory=Counter)
    aicom_events: Counter = field(default_factory=Counter)
    mhq_states: Counter = field(default_factory=Counter)
    skin_stages: Counter = field(default_factory=Counter)
    fps_values: List[float] = field(default_factory=list)
    fps_min_values: List[float] = field(default_factory=list)
    rpt_warnings: int = 0
    rpt_errors: int = 0

    def add_file(self, path: Path) -> None:
        value = str(path)
        if value not in self.files:
            self.files.append(value)

    def row(self) -> Dict[str, object]:
        avg_fps = round(mean(self.fps_values), 2) if self.fps_values else ""
        avg_min_fps = round(mean(self.fps_min_values), 2) if self.fps_min_values else ""
        worst_min_fps = round(min(self.fps_min_values), 2) if self.fps_min_values else ""
        return {
            "build": self.build,
            "files": len(self.files),
            "lines": self.lines,
            "warnings": self.rpt_warnings,
            "errors": self.rpt_errors,
            "fps_reports": len(self.fps_values),
            "avg_fps": avg_fps,
            "avg_min_fps": avg_min_fps,
            "worst_min_fps": worst_min_fps,
            "mhq_triggers": self.mhq_states["TRIGGER"],
            "mhq_deployed": self.mhq_states["DEPLOYED"],
            "mhq_aborts": sum(v for k, v in self.mhq_states.items() if k == "ABORT" or k.startswith("ABORT:")),
            "mhq_relaxed": self.counters["mhqreloc_relaxed"],
            "build_road": self.counters["build_road"],
            "patrol_unstuck": self.aicom_events["PATROL_UNSTUCK"],
            "patrol_naval_skip": self.counters["patrol_naval_skip"],
            "scud_tel": self.counters["scud_tel"],
            "scud_denied": self.counters["scud_denied"],
            "scud_launched": self.counters["scud_launched"],
            "easa_gear": self.counters["easa_gear"],
            "skin_apply": self.counters["skin_apply"],
            "skin_abort": self.counters["skin_abort"],
            "skin_complete": self.counters["skin_complete"],
            "waspstat": self.counters["waspstat"],
            "roundend": self.counters["roundend"],
            "playerstat": self.counters["playerstat"],
            "hc_connect": self.counters["hc_connect"],
            "hc_disconnect": self.counters["hc_disconnect"],
        }


def read_lines(path: Path) -> Iterable[str]:
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            yield line.rstrip("\r\n")


def parse_timestamp(line: str) -> str:
    # Common RPT prefixes start with a timestamp-like token. Keep it as text so
    # the tool works across localized/trimmed log extracts.
    head = line[:32].strip()
    if re.match(r"^\d{1,4}[-/:.]\d", head):
        return head
    return ""


def extract_float(fields: Dict[str, str], key: str) -> Optional[float]:
    value = fields.get(key)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def parse_keyvals(text: str) -> Dict[str, str]:
    return {match.group(1): match.group(2) for match in KEYVAL_RE.finditer(text)}


def clean_event_name(value: str) -> str:
    value = value.strip()
    if not value:
        return "UNKNOWN"
    return value.split("|", 1)[0].split("=", 1)[0].strip().upper()


def parse_aicomstat(stats: BuildStats, payload: str) -> None:
    parts = payload.split("|")
    if len(parts) < 3:
        return
    stats.counters["aicomstat"] += 1
    record_type = parts[2].upper()
    if record_type == "MHQRELOC" and len(parts) >= 6:
        state = clean_event_name(parts[5])
        if state == "ABORT" and len(parts) >= 7:
            state = "ABORT:" + clean_event_name(parts[6]).lower()
        stats.mhq_states[state] += 1
        if "RELAX" in payload.upper():
            stats.counters["mhqreloc_relaxed"] += 1
        return
    if record_type == "EVENT" and len(parts) >= 6:
        event = clean_event_name(parts[5])
        stats.aicom_events[event] += 1
        if event.startswith("BUILD_ROAD"):
            stats.counters["build_road"] += 1
        if event == "PATROL_UNSTUCK":
            stats.counters["patrol_unstuck"] += 1
        return
    if record_type in {"TICK", "POSTURE", "FRONT", "STALL", "END"}:
        stats.aicom_events[record_type] += 1


def parse_fpsreport(stats: BuildStats, payload: str) -> None:
    fields = parse_keyvals(payload)
    fps = extract_float(fields, "fps")
    fps_min = extract_float(fields, "fpsMin")
    if fps is not None:
        stats.fps_values.append(fps)
    if fps_min is not None:
        stats.fps_min_values.append(fps_min)
    stats.counters["fpsreport"] += 1


def parse_waspstat(stats: BuildStats, payload: str) -> None:
    stats.counters["waspstat"] += 1
    if "|ROUNDEND|" in payload:
        stats.counters["roundend"] += 1
    elif "|CAPTURE|" in payload:
        stats.counters["capture"] += 1
    elif "|KILL|" in payload:
        stats.counters["kill"] += 1
    elif "|BUILDINGKILL|" in payload:
        stats.counters["buildingkill"] += 1


def parse_hcside(stats: BuildStats, payload: str) -> None:
    if "|connect|" in payload:
        stats.counters["hc_connect"] += 1
    elif "|disconnect|" in payload:
        stats.counters["hc_disconnect"] += 1
    elif "|connect-failed|" in payload:
        stats.counters["hc_connect_failed"] += 1
    elif "|connect-deferred|" in payload:
        stats.counters["hc_connect_deferred"] += 1
    stats.counters["hcside"] += 1


def parse_skin(stats: BuildStats, line: str) -> None:
    stats.counters["skin_apply"] += 1
    match = SKIN_STAGE_RE.search(line)
    if match:
        stage = (match.group(1) or "UNKNOWN").upper()
        stats.skin_stages[stage] += 1
    upper = line.upper()
    if "ABORT" in upper:
        stats.counters["skin_abort"] += 1
    if "COMPLETE" in upper:
        stats.counters["skin_complete"] += 1


def analyze_line(stats: BuildStats, line: str) -> None:
    stats.lines += 1
    ts = parse_timestamp(line)
    if ts:
        if not stats.first_timestamp:
            stats.first_timestamp = ts
        stats.last_timestamp = ts

    upper = line.upper()
    if "WARNING" in upper:
        stats.rpt_warnings += 1
    if "ERROR" in upper or "EXCEPTION" in upper:
        stats.rpt_errors += 1

    structured_marker = False
    for marker, parser in (
        ("AICOMSTAT|", parse_aicomstat),
        ("FPSREPORT|", parse_fpsreport),
        ("WASPSTAT|", parse_waspstat),
        ("HCSIDE|", parse_hcside),
    ):
        idx = line.find(marker)
        if idx >= 0:
            structured_marker = True
            parser(stats, line[idx:])

    if "PLAYERSTAT|v1|" in line:
        stats.counters["playerstat"] += 1
    if "[WFBE (SKIN)]" in line:
        parse_skin(stats, line)
    if not structured_marker and BUILD_ROAD_RE.search(line):
        stats.counters["build_road"] += 1
    if NAVAL_SKIP_RE.search(line):
        stats.counters["patrol_naval_skip"] += 1
    if SCUD_RE.search(line):
        stats.counters["scud_tel"] += 1
        if "DENIED" in upper or "COOLDOWN" in upper or "INSUFFICIENT" in upper:
            stats.counters["scud_denied"] += 1
        if "LAUNCHED" in upper or "AUTHORIZED" in upper or "REQUEST AT" in upper:
            stats.counters["scud_launched"] += 1
    if EASA_GEAR_RE.search(line):
        stats.counters["easa_gear"] += 1


def expand_inputs(paths: Iterable[Path], recurse: bool) -> List[Path]:
    out: List[Path] = []
    for path in paths:
        if path.is_dir():
            pattern = "**/*" if recurse else "*"
            out.extend(p for p in path.glob(pattern) if p.suffix.lower() in {".rpt", ".log", ".txt"})
        else:
            out.append(path)
    return out


def split_build_path(value: str) -> Tuple[str, Path]:
    if "=" in value:
        build, raw_path = value.split("=", 1)
        return build.strip(), Path(raw_path)
    path = Path(value)
    return path.stem, path


def analyze(build_inputs: Iterable[Tuple[str, Path]], recurse: bool) -> Dict[str, BuildStats]:
    builds: Dict[str, BuildStats] = {}
    grouped: Dict[str, List[Path]] = defaultdict(list)
    for build, path in build_inputs:
        grouped[build].extend(expand_inputs([path], recurse))

    for build, paths in grouped.items():
        stats = builds.setdefault(build, BuildStats(build=build))
        for path in paths:
            if not path.exists():
                raise FileNotFoundError(path)
            stats.add_file(path)
            for line in read_lines(path):
                analyze_line(stats, line)
    return builds


def write_csv(path: Path, rows: List[Dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, builds: Dict[str, BuildStats], rows: List[Dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "wasp-soak-analysis-v1",
        "builds": rows,
        "details": {
            build: {
                "files": stats.files,
                "first_timestamp": stats.first_timestamp,
                "last_timestamp": stats.last_timestamp,
                "aicom_events": dict(stats.aicom_events),
                "mhq_states": dict(stats.mhq_states),
                "skin_stages": dict(stats.skin_stages),
                "counters": dict(stats.counters),
            }
            for build, stats in builds.items()
        },
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def markdown_table(rows: List[Dict[str, object]]) -> str:
    columns = [
        "build",
        "lines",
        "warnings",
        "errors",
        "avg_fps",
        "worst_min_fps",
        "mhq_triggers",
        "mhq_deployed",
        "mhq_aborts",
        "build_road",
        "patrol_naval_skip",
        "scud_tel",
        "easa_gear",
        "skin_complete",
    ]
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def comparison_lines(rows: List[Dict[str, object]]) -> List[str]:
    if len(rows) < 2:
        return []
    base = rows[0]
    metrics = ["errors", "avg_fps", "worst_min_fps", "mhq_deployed", "mhq_aborts", "patrol_unstuck", "scud_denied", "skin_abort"]
    out = [f"Baseline: {base['build']}"]
    for row in rows[1:]:
        parts = []
        for metric in metrics:
            lhs = base.get(metric, "")
            rhs = row.get(metric, "")
            if isinstance(lhs, (int, float)) and isinstance(rhs, (int, float)):
                parts.append(f"{metric} {rhs - lhs:+g}")
        out.append(f"{row['build']}: " + (", ".join(parts) if parts else "no numeric deltas"))
    return out


def write_markdown(path: Path, rows: List[Dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# WASP Soak Analysis", "", markdown_table(rows)]
    deltas = comparison_lines(rows)
    if deltas:
        lines.extend(["", "## Build Comparison", ""])
        lines.extend(f"- {line}" for line in deltas)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def print_summary(rows: List[Dict[str, object]]) -> None:
    print(markdown_table(rows))
    deltas = comparison_lines(rows)
    if deltas:
        print()
        for line in deltas:
            print(line)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze WASP Warfare soak RPT logs and compare per-build KPIs.",
        epilog="Inputs may be PATH or BUILD=PATH. Directories include .rpt/.log/.txt files.",
    )
    parser.add_argument("inputs", nargs="+", help="RPT/log paths, folders, or BUILD=PATH entries")
    parser.add_argument("--recurse", action="store_true", help="recurse into input folders")
    parser.add_argument("--csv", type=Path, help="write KPI summary CSV")
    parser.add_argument("--json", type=Path, help="write detailed JSON")
    parser.add_argument("--md", type=Path, help="write Markdown report")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    try:
        build_inputs = [split_build_path(value) for value in args.inputs]
        builds = analyze(build_inputs, recurse=args.recurse)
    except Exception as exc:  # pragma: no cover - CLI guard
        print(f"analyze_soak.py: {exc}", file=sys.stderr)
        return 2

    rows = [stats.row() for stats in builds.values()]
    if not rows:
        print("No input lines parsed.", file=sys.stderr)
        return 1
    print_summary(rows)
    if args.csv:
        write_csv(args.csv, rows)
    if args.json:
        write_json(args.json, builds, rows)
    if args.md:
        write_markdown(args.md, rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
