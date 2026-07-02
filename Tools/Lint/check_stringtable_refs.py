#!/usr/bin/env python3
"""Cross-reference mission STR_ references against stringtable.xml."""

from __future__ import annotations

import argparse
import bisect
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SOURCE_SUFFIXES = {".sqf", ".fsm", ".hpp", ".ext", ".sqm", ".cpp", ".inc"}
KEY_RE = re.compile(r"\b[Ss][Tt][Rr]_[A-Za-z0-9_]+")
KEY_ID_RE = re.compile(r"\bID\s*=\s*[\"']([Ss][Tt][Rr]_[A-Za-z0-9_]+)[\"']")
DEFAULT_IGNORED_PREFIXES = (
    "STR_EP1_",
    "STR_DN_",
    "STR_CA_",
    "STR_CFG",
    "STR_DISP_",
    "STR_ACR_",
    "STR_BAF_",
    "STR_PMC_",
    "STR_ARCMARK_",
    "STR_INPUT_DEVICE_",
    "STR_TASK",
)


@dataclass(frozen=True)
class Location:
    key: str
    path: Path
    line: int
    col: int


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    col: int
    code: str
    message: str

    def render(self, root: Path) -> str:
        try:
            shown = self.path.relative_to(root)
        except ValueError:
            shown = self.path
        return f"{shown}:{self.line}:{self.col}: {self.code}: {self.message}"


@dataclass(frozen=True)
class LanguageGap:
    location: Location
    language: str
    reason: str


def normalize_key(key: str) -> str:
    return key.upper()


def normalize_language(language: str) -> str:
    return language.casefold()


def line_starts(text: str) -> list[int]:
    starts = [0]
    for match in re.finditer(r"\n", text):
        starts.append(match.end())
    return starts


def line_col(starts: list[int], index: int) -> tuple[int, int]:
    line_idx = bisect.bisect_right(starts, index) - 1
    return line_idx + 1, index - starts[line_idx] + 1


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def mask_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    in_block = False
    in_string: str | None = None
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if in_block:
            if ch == "*" and nxt == "/":
                out.extend("  ")
                i += 2
                in_block = False
            else:
                out.append("\n" if ch == "\n" else " ")
                i += 1
            continue
        if in_string is not None:
            if ch == in_string:
                if i + 1 < len(text) and text[i + 1] == in_string:
                    out.extend("  ")
                    i += 2
                else:
                    out.append(ch)
                    i += 1
                    in_string = None
            else:
                out.append(ch)
                i += 1
            continue
        if ch == "/" and nxt == "/":
            out.extend("  ")
            i += 2
            while i < len(text) and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch == "/" and nxt == "*":
            out.extend("  ")
            i += 2
            in_block = True
            continue
        if ch in ("'", '"'):
            out.append(ch)
            i += 1
            in_string = ch
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def mask_xml_comments(text: str) -> str:
    return re.sub(
        r"<!--.*?-->",
        lambda match: "".join("\n" if ch == "\n" else " " for ch in match.group(0)),
        text,
        flags=re.DOTALL,
    )


def iter_source_files(paths: Iterable[Path]) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_dir():
            for child in path.rglob("*"):
                if child.is_file() and child.suffix.lower() in SOURCE_SUFFIXES:
                    if child.name.lower() != "stringtable.xml":
                        files.append(child)
        elif path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES:
            if path.name.lower() != "stringtable.xml":
                files.append(path)
    return sorted(set(files))


def parse_stringtable(path: Path) -> dict[str, list[Location]]:
    text = read_text(path)
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise ValueError(f"{path}: XML parse failed: {exc}") from exc

    starts = line_starts(text)
    locations: dict[str, list[Location]] = {}
    for match in KEY_ID_RE.finditer(text):
        key = match.group(1)
        line, col = line_col(starts, match.start(1))
        locations.setdefault(normalize_key(key), []).append(Location(key, path, line, col))

    parsed_keys: set[str] = set()
    for element in root.iter():
        tag = element.tag.rsplit("}", 1)[-1]
        if tag != "Key":
            continue
        key = element.attrib.get("ID")
        if key and KEY_RE.fullmatch(key):
            parsed_keys.add(normalize_key(key))

    for key in sorted(parsed_keys - set(locations)):
        locations[key] = [Location(key, path, 1, 1)]
    return locations


def parse_requested_languages(values: Iterable[str], include_russian: bool) -> list[str]:
    languages: list[str] = []
    if include_russian:
        languages.append("Russian")
    for value in values:
        languages.extend(part.strip() for part in value.split(","))

    seen: set[str] = set()
    unique: list[str] = []
    for language in languages:
        if not language:
            continue
        normalized = normalize_language(language)
        if normalized in seen:
            continue
        seen.add(normalized)
        unique.append(language)
    return unique


def collect_language_gaps(
    path: Path,
    definitions: dict[str, list[Location]],
    requested_languages: Iterable[str],
) -> list[LanguageGap]:
    requested = list(requested_languages)
    if not requested:
        return []

    text = read_text(path)
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise ValueError(f"{path}: XML parse failed: {exc}") from exc

    occurrence_counts: dict[str, int] = {}
    gaps: list[LanguageGap] = []
    for element in root.iter():
        tag = element.tag.rsplit("}", 1)[-1]
        if tag != "Key":
            continue
        key = element.attrib.get("ID")
        if not key or not KEY_RE.fullmatch(key):
            continue

        normalized = normalize_key(key)
        occurrence = occurrence_counts.get(normalized, 0)
        occurrence_counts[normalized] = occurrence + 1
        definition_locations = definitions.get(normalized, [Location(key, path, 1, 1)])
        location = definition_locations[min(occurrence, len(definition_locations) - 1)]

        child_text_by_language: dict[str, str] = {}
        for child in list(element):
            child_tag = child.tag.rsplit("}", 1)[-1]
            child_text_by_language[normalize_language(child_tag)] = "".join(child.itertext()).strip()

        for language in requested:
            text_value = child_text_by_language.get(normalize_language(language))
            if text_value is None:
                gaps.append(LanguageGap(location, language, "missing"))
            elif text_value == "":
                gaps.append(LanguageGap(location, language, "blank"))
    return gaps


def collect_references(paths: Iterable[Path]) -> dict[str, list[Location]]:
    references: dict[str, list[Location]] = {}
    for path in paths:
        text = read_text(path)
        masked = mask_xml_comments(text) if path.suffix.lower() == ".xml" else mask_comments(text)
        starts = line_starts(masked)
        for match in KEY_RE.finditer(masked):
            key = match.group(0)
            line, col = line_col(starts, match.start())
            references.setdefault(normalize_key(key), []).append(Location(key, path, line, col))
    return references


def is_ignored_builtin(key: str, ignored_prefixes: Iterable[str]) -> bool:
    normalized = normalize_key(key)
    return any(normalized.startswith(normalize_key(prefix)) for prefix in ignored_prefixes)


def build_findings(
    definitions: dict[str, list[Location]],
    references: dict[str, list[Location]],
    root: Path,
    ignored_prefixes: Iterable[str],
    include_orphans: bool,
    max_locations_per_key: int,
    language_gaps: Iterable[LanguageGap],
) -> list[Finding]:
    del root
    findings: list[Finding] = []

    for normalized, locations in sorted(definitions.items()):
        if len(locations) <= 1:
            continue
        for location in locations[1:]:
            findings.append(
                Finding(
                    location.path,
                    location.line,
                    location.col,
                    "STRDUP",
                    f"Duplicate stringtable key ID: {location.key}",
                )
            )

    for normalized, locations in sorted(references.items()):
        if normalized in definitions:
            continue
        if is_ignored_builtin(locations[0].key, ignored_prefixes):
            continue
        total = len(locations)
        for location in locations[:max_locations_per_key]:
            findings.append(
                Finding(
                    location.path,
                    location.line,
                    location.col,
                    "STRMISSING",
                    f"{location.key} is referenced but not defined in stringtable.xml ({total} reference(s))",
                )
            )

    if include_orphans:
        for normalized, locations in sorted(definitions.items()):
            if normalized in references or is_ignored_builtin(locations[0].key, ignored_prefixes):
                continue
            location = locations[0]
            findings.append(
                Finding(
                    location.path,
                    location.line,
                    location.col,
                    "STRORPHAN",
                    f"{location.key} is defined in stringtable.xml but not referenced by the scanned files",
                )
            )

    for gap in sorted(
        language_gaps,
        key=lambda item: (
            str(item.location.path),
            item.location.line,
            item.location.col,
            normalize_key(item.location.key),
            normalize_language(item.language),
        ),
    ):
        verb = "has blank" if gap.reason == "blank" else "is missing"
        findings.append(
            Finding(
                gap.location.path,
                gap.location.line,
                gap.location.col,
                "STRLANG",
                f"{gap.location.key} {verb} {gap.language} text in stringtable.xml",
            )
        )

    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Check STR_ references against a mission stringtable.xml.")
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="Files or directories to scan. Defaults to the maintained Chernarus source mission.",
    )
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root for relative output paths.")
    parser.add_argument("--stringtable", type=Path, help="Stringtable XML to check against.")
    parser.add_argument(
        "--orphans",
        action="store_true",
        help="Also report stringtable keys that are not referenced by scanned files.",
    )
    parser.add_argument(
        "--check-builtins",
        action="store_true",
        help="Do not ignore BI/expansion STR_ prefixes such as STR_EP1_ and STR_DN_.",
    )
    parser.add_argument(
        "--ignore-prefix",
        action="append",
        default=[],
        help="Additional STR_ prefix to ignore when reporting missing/orphan keys. May be repeated.",
    )
    parser.add_argument(
        "--max-locations-per-key",
        type=int,
        default=5,
        help="Maximum missing-reference locations to print per key.",
    )
    parser.add_argument(
        "--languages",
        action="append",
        default=[],
        help="Comma-separated stringtable language columns to report when missing or blank. May be repeated.",
    )
    parser.add_argument(
        "--ru-gaps",
        action="store_true",
        help="Shorthand for --languages Russian; reports missing or blank Russian stringtable text.",
    )
    parser.add_argument(
        "--exit-zero",
        action="store_true",
        help="Always exit 0 after a successful scan, useful for report-only CI jobs.",
    )
    args = parser.parse_args(argv)

    root = args.root.resolve()
    default_mission = root / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
    stringtable = args.stringtable or default_mission / "stringtable.xml"
    stringtable = stringtable if stringtable.is_absolute() else root / stringtable
    scan_paths = [path if path.is_absolute() else root / path for path in (args.paths or [default_mission])]

    try:
        definitions = parse_stringtable(stringtable)
    except (OSError, ValueError) as exc:
        print(exc, file=sys.stderr)
        return 2

    requested_languages = parse_requested_languages(args.languages, args.ru_gaps)
    try:
        language_gaps = collect_language_gaps(stringtable, definitions, requested_languages)
    except (OSError, ValueError) as exc:
        print(exc, file=sys.stderr)
        return 2

    files = iter_source_files(scan_paths)
    if not files:
        print("No source files found for requested paths.", file=sys.stderr)
        return 2

    references = collect_references(files)
    ignored_prefixes = [] if args.check_builtins else list(DEFAULT_IGNORED_PREFIXES)
    ignored_prefixes.extend(args.ignore_prefix)
    findings = build_findings(
        definitions,
        references,
        root,
        ignored_prefixes,
        args.orphans,
        max(1, args.max_locations_per_key),
        language_gaps,
    )

    for finding in findings:
        print(finding.render(root))
    print(
        f"Scanned {len(files)} file(s); stringtable keys: {len(definitions)}; "
        f"referenced keys: {len(references)}; findings: {len(findings)}"
    )
    if args.exit_zero:
        return 0
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
