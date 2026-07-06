#!/usr/bin/env python3
"""Small SQF lint gate for WASP Warfare PRs.

The checker is intentionally conservative: it catches the fleet prompt's common
Arma 3 command traps, Boolean-style ==/!= additions, bracket drift, suspicious
classnames that are not present elsewhere in the tree, and display scripts that
touch display controls without disableSerialization.
"""

from __future__ import annotations

import argparse
import bisect
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SQF_SUFFIXES = {".sqf", ".fsm", ".hpp", ".ext", ".sqm"}
CLASSNAME_SOURCE_SUFFIXES = {".sqf", ".fsm", ".hpp", ".ext", ".sqm", ".xml", ".cpp"}
A3_TRAPS = (
    "isEqualType",
    "isEqualTo",
    "params",
    "pushBack",
    "findIf",
    "selectRandom",
    "apply",
    "forceFollowRoad",
    "worldSize",
    "getPosVisual",
    "remoteExec",
    "distance2D",
    "setGroupOwner",
    "groupOwner",
    "joinGroup",
)
BOOLEAN_OP_RE = re.compile(r"\b(if|while|waitUntil)\b[^\n]*(==|!=)")
QUOTED_TOKEN_RE = re.compile(r'"([A-Za-z][A-Za-z0-9_]{2,})"|\'([A-Za-z][A-Za-z0-9_]{2,})\'')
CLASSNAME_HINT_RE = re.compile(r"^(?:[A-Z][A-Za-z0-9]*_|[A-Z]+_|[a-z]+_[A-Za-z0-9_]*|[A-Z][A-Za-z0-9]+[A-Z][A-Za-z0-9]*)")
DISPLAY_TOKEN_RE = re.compile(r"\b(displayCtrl|ctrlSetText|ctrlSetTextColor|ctrlShow|ctrlEnable|lb[A-Z]|lnb[A-Z])\b")
A3_MARKER_TYPE_RE = re.compile(r"(?<![A-Za-z0-9_])[\"']([bon]_[A-Za-z0-9_]+)[\"']", re.IGNORECASE)
A3_REVEAL_ARRAY_LEFT_RE = re.compile(r"\[[^\]\n;]*\]\s+reveal\b", re.IGNORECASE)
A3_REVEAL_ARRAY_RIGHT_RE = re.compile(r"\breveal\s+\[[^\]\n;]*\]", re.IGNORECASE)
A3_SELECT_SLICE_RE = re.compile(r"\bselect\s*\[", re.IGNORECASE)
A3_SORT_CODE_RE = re.compile(r"\bsort\s*\{", re.IGNORECASE)
A3_BIS_FNC_CALL_RE = re.compile(r"\bcall\s+BIS_fnc_\w+\b", re.IGNORECASE)
STRING_LITERAL_RE = "\"(?:[^\"]|\"\")*\"|'(?:[^']|'')*'"
A3_STRING_FIND_RE = re.compile(rf"(?:{STRING_LITERAL_RE})\s+find\s+(?:{STRING_LITERAL_RE})", re.IGNORECASE)
GROUP_GETVARIABLE_ARRAY_RE = re.compile(
    r"\b(?:"
    r"group\s+[A-Za-z_][A-Za-z0-9_]*|"
    r"group\s*\([^)]*\)|"
    r"_[A-Za-z0-9_]*(?:grp|group|team)[A-Za-z0-9_]*|"
    r"[A-Za-z0-9_]*(?:Group|Team)"
    r")\s+getVariable\s*\[",
    re.IGNORECASE,
)
STRING_TYPED_NUMERIC_GATE_RE = re.compile(
    r"\bgetVariable\s*\[\s*"
    r"(?P<name>"
    r"[\"'][A-Za-z_][A-Za-z0-9_]*(?:_TYPE|_CLASS|_LAUNCHER)[\"']|"
    r"[A-Za-z_][A-Za-z0-9_]*(?:_TYPE|_CLASS|_LAUNCHER)"
    r")"
    r"\s*,\s*(?:0|false)\s*\]",
    re.IGNORECASE,
)
NAMESPACE_SETVARIABLE_RE = re.compile(
    r"\b(missionNamespace|uiNamespace|profileNamespace)\s+setVariable\s*\[",
    re.IGNORECASE,
)
FINDING_CODES = (
    "A3BISFNC",
    "A3CMD",
    "A3MARKER",
    "A3NUMGATE",
    "A3REVEAL",
    "A3SELECT",
    "A3SORT",
    "A3STRING",
    "BOOLCMP",
    "BRACKET",
    "CLASSREF",
    "DISABLESER",
    "GROUPGETVAR",
    "NSSETVAR3",
)


@dataclass
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


def iter_files(paths: Iterable[Path]) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_dir():
            for child in path.rglob("*"):
                if child.is_file() and child.suffix.lower() in SQF_SUFFIXES:
                    files.append(child)
        elif path.is_file() and path.suffix.lower() in SQF_SUFFIXES:
            files.append(path)
    return sorted(set(files))


def git_pathspec(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def parse_added_lines_from_diff(diff_text: str, root: Path) -> dict[Path, set[int]]:
    added_lines: dict[Path, set[int]] = {}
    current_path: Path | None = None
    next_new_line: int | None = None

    for line in diff_text.splitlines():
        if line.startswith("+++ ") and (line.startswith("+++ b/") or line.startswith("+++ /dev/null")):
            shown = line[4:].strip()
            if shown == "/dev/null":
                current_path = None
                next_new_line = None
                continue
            if shown.startswith("b/"):
                shown = shown[2:]
            current_path = (root / shown).resolve()
            added_lines.setdefault(current_path, set())
            next_new_line = None
            continue

        if line.startswith("@@ "):
            match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
            if match:
                next_new_line = int(match.group(1))
            continue

        if current_path is None or next_new_line is None:
            continue
        if line.startswith("+") and not line.startswith("+++ "):
            added_lines.setdefault(current_path, set()).add(next_new_line)
            next_new_line += 1
        elif line.startswith("-") and not line.startswith("--- "):
            continue
        elif line.startswith(" "):
            next_new_line += 1

    return {path: lines for path, lines in added_lines.items() if lines}


def collect_diff_added_lines(root: Path, ref: str, paths: Iterable[Path]) -> dict[Path, set[int]]:
    pathspecs = [git_pathspec(root, path) for path in paths]
    command = ["git", "-C", str(root), "diff", "--unified=0", "--no-ext-diff", ref, "--", *pathspecs]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return parse_added_lines_from_diff(result.stdout, root)


def filter_findings_to_added_lines(findings: Iterable[Finding], added_lines: dict[Path, set[int]]) -> list[Finding]:
    filtered: list[Finding] = []
    for finding in findings:
        lines = added_lines.get(finding.path.resolve())
        if lines is not None and finding.line in lines:
            filtered.append(finding)
    return filtered


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def line_starts(text: str) -> list[int]:
    starts = [0]
    for match in re.finditer(r"\n", text):
        starts.append(match.end())
    return starts


def line_col(starts: list[int], index: int) -> tuple[int, int]:
    line_idx = bisect.bisect_right(starts, index) - 1
    return line_idx + 1, index - starts[line_idx] + 1


def mask_comments_and_strings(text: str) -> str:
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
                    out.append(" ")
                    i += 1
                    in_string = None
            else:
                out.append("\n" if ch == "\n" else " ")
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
            out.append(" ")
            i += 1
            in_string = ch
            continue
        out.append(ch)
        i += 1
    return "".join(out)


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
            out.append(ch)
            if ch == in_string:
                if i + 1 < len(text) and text[i + 1] == in_string:
                    out.append(text[i + 1])
                    i += 2
                else:
                    i += 1
                    in_string = None
            else:
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
            in_string = ch
        out.append(ch)
        i += 1
    return "".join(out)


def count_top_level_elements(masked: str, open_index: int) -> int | None:
    """Count comma-separated top-level elements of the bracket opening at open_index.

    Expects masked text (string contents already blanked), so commas inside
    string literals never reach the counter. Returns None when the bracket
    never closes; BRACKET reports that case separately.
    """
    depth = 0
    commas = 0
    has_content = False
    for index in range(open_index, len(masked)):
        ch = masked[index]
        if ch in "([{":
            if depth > 0:
                has_content = True
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                if commas:
                    return commas + 1
                return 1 if has_content else 0
        elif depth == 1:
            if ch == ",":
                commas += 1
            elif not ch.isspace():
                has_content = True
    return None


def build_token_index(root: Path) -> dict[str, set[Path]]:
    index: dict[str, set[Path]] = {}
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in CLASSNAME_SOURCE_SUFFIXES:
            continue
        try:
            text = read_text(path)
        except OSError:
            continue
        for match in QUOTED_TOKEN_RE.finditer(text):
            token = match.group(1) or match.group(2)
            if CLASSNAME_HINT_RE.match(token):
                index.setdefault(token, set()).add(path)
    return index


def lint_text(path: Path, text: str, root: Path, token_index: dict[str, set[Path]]) -> list[Finding]:
    findings: list[Finding] = []
    masked = mask_comments_and_strings(text)
    comments_masked = mask_comments(text)
    starts = line_starts(masked)
    comments_starts = line_starts(comments_masked)

    for trap in A3_TRAPS:
        for match in re.finditer(rf"\b{re.escape(trap)}\b", masked, re.IGNORECASE):
            line, col = line_col(starts, match.start())
            findings.append(Finding(path, line, col, "A3CMD", f"Arma 3-only command or prompt trap: {trap}"))

    for regex, code, message in (
        (A3_REVEAL_ARRAY_LEFT_RE, "A3REVEAL", "Array-form reveal is an A3-era trap; reveal units one at a time"),
        (A3_REVEAL_ARRAY_RIGHT_RE, "A3REVEAL", "Array-form reveal is an A3-era trap; reveal units one at a time"),
        (A3_SELECT_SLICE_RE, "A3SELECT", "select [start,count] syntax is not A2/OA 1.64-safe"),
        (A3_SORT_CODE_RE, "A3SORT", "sort-by-code syntax is not A2/OA 1.64-safe"),
        (A3_BIS_FNC_CALL_RE, "A3BISFNC", "BIS_fnc_* calls require the Arma 3 function library and are not A2/OA 1.64-safe"),
        (GROUP_GETVARIABLE_ARRAY_RE, "GROUPGETVAR", "Review two-argument getVariable on a group; use plain get + isNil for groups"),
    ):
        for match in regex.finditer(masked):
            line, col = line_col(starts, match.start())
            findings.append(Finding(path, line, col, code, message))

    for match in NAMESPACE_SETVARIABLE_RE.finditer(masked):
        elements = count_top_level_elements(masked, match.end() - 1)
        if elements is not None and elements >= 3:
            line, col = line_col(starts, match.start())
            findings.append(
                Finding(
                    path,
                    line,
                    col,
                    "NSSETVAR3",
                    f"{match.group(1)} setVariable takes exactly [name, value] on A2/OA 1.64; "
                    f"the {elements}-element public-flag form is Arma 3-only, throws "
                    "'Error 3 elements provided, 2 expected' and leaves the variable unset",
                )
            )

    for match in A3_MARKER_TYPE_RE.finditer(comments_masked):
        line, col = line_col(comments_starts, match.start())
        findings.append(Finding(path, line, col, "A3MARKER", "A3 NATO marker type; use an A2/OA marker type instead"))

    for match in A3_STRING_FIND_RE.finditer(comments_masked):
        line, col = line_col(comments_starts, match.start())
        findings.append(Finding(path, line, col, "A3STRING", "String find syntax is not A2/OA 1.64-safe"))

    for match in STRING_TYPED_NUMERIC_GATE_RE.finditer(comments_masked):
        line, col = line_col(comments_starts, match.start())
        findings.append(
            Finding(
                path,
                line,
                col,
                "A3NUMGATE",
                f"Review numeric getVariable gate on string-typed constant name {match.group('name')}; use a numeric feature flag instead",
            )
        )

    for match in BOOLEAN_OP_RE.finditer(masked):
        line, col = line_col(starts, match.start(2))
        findings.append(Finding(path, line, col, "BOOLCMP", "Review ==/!= inside a control expression; Boolean operands are rejected by the fleet prompt"))

    stack: list[tuple[str, int]] = []
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = {")": "(", "]": "[", "}": "{"}
    for index, ch in enumerate(masked):
        if ch in pairs:
            stack.append((ch, index))
        elif ch in closers:
            if not stack or stack[-1][0] != closers[ch]:
                line, col = line_col(starts, index)
                findings.append(Finding(path, line, col, "BRACKET", f"Unmatched closing {ch}"))
            else:
                stack.pop()
    for ch, index in stack:
        line, col = line_col(starts, index)
        findings.append(Finding(path, line, col, "BRACKET", f"Unmatched opening {ch}"))

    if DISPLAY_TOKEN_RE.search(masked) and "disableSerialization" not in masked:
        findings.append(Finding(path, 1, 1, "DISABLESER", "Display-control script uses UI control helpers without disableSerialization"))

    for match in QUOTED_TOKEN_RE.finditer(text):
        token = match.group(1) or match.group(2)
        if not CLASSNAME_HINT_RE.match(token):
            continue
        owners = token_index.get(token, set())
        if owners == {path}:
            line, col = line_col(line_starts(text), match.start())
            findings.append(Finding(path, line, col, "CLASSREF", f"Quoted classname-like token appears only in this file: {token}"))

    return findings


def parse_code_filter(value: str, parser: argparse.ArgumentParser, option_name: str) -> set[str]:
    codes = {part.strip().upper() for part in value.split(",") if part.strip()}
    unknown = sorted(codes - set(FINDING_CODES))
    if unknown:
        parser.error(f"{option_name} contains unknown finding code(s): {', '.join(unknown)}")
    if not codes:
        parser.error(f"{option_name} requires at least one finding code")
    return codes


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Run WASP SQF lint checks.")
    parser.add_argument("paths", nargs="*", type=Path, help="Files or directories to scan. Defaults to the maintained mission roots.")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root for relative paths and classname indexing.")
    parser.add_argument("--no-classname-index", action="store_true", help="Skip quoted classname-like token uniqueness checks.")
    parser.add_argument("--select", help="Comma-separated finding codes to include, e.g. A3CMD,BRACKET.")
    parser.add_argument("--ignore", help="Comma-separated finding codes to suppress, e.g. BOOLCMP,CLASSREF.")
    parser.add_argument("--diff-from", metavar="REF", help="Only report findings whose primary line was added since REF.")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    selected_codes = parse_code_filter(args.select, parser, "--select") if args.select else None
    ignored_codes = parse_code_filter(args.ignore, parser, "--ignore") if args.ignore else set()
    default_paths = [
        root / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
        root / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
        root / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
    ]
    scan_paths = [path if path.is_absolute() else root / path for path in (args.paths or default_paths)]

    added_lines: dict[Path, set[int]] | None = None
    if args.diff_from:
        try:
            added_lines = collect_diff_added_lines(root, args.diff_from, scan_paths)
        except subprocess.CalledProcessError as exc:
            stderr = exc.stderr.strip()
            print(f"git diff failed for --diff-from {args.diff_from}: {stderr or exc}", file=sys.stderr)
            return 2
        files = sorted(path for path in added_lines if path.exists() and path.suffix.lower() in SQF_SUFFIXES)
        if not files:
            print("No added SQF/HPP/EXT/FSM/SQM lines found for requested diff scope.")
            return 0
    else:
        files = iter_files(scan_paths)

    if not files:
        print("No SQF/HPP/EXT/FSM/SQM files found for requested paths.", file=sys.stderr)
        return 2

    token_index: dict[str, set[Path]] = {}
    needs_classname_index = (selected_codes is None or "CLASSREF" in selected_codes) and "CLASSREF" not in ignored_codes
    if not args.no_classname_index and needs_classname_index:
        token_index = build_token_index(root)

    findings: list[Finding] = []
    for path in files:
        findings.extend(lint_text(path.resolve(), read_text(path), root, token_index))
    if added_lines is not None:
        findings = filter_findings_to_added_lines(findings, added_lines)
    if selected_codes is not None:
        findings = [finding for finding in findings if finding.code in selected_codes]
    if ignored_codes:
        findings = [finding for finding in findings if finding.code not in ignored_codes]

    for finding in findings:
        print(finding.render(root))
    print(f"Scanned {len(files)} file(s); findings: {len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
