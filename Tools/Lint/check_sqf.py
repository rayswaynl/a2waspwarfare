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
    "createVehicleCrew",
    "distance2D",
    "setGroupOwner",
    "groupOwner",
    "joinGroup",
    "getOrDefault",
    "deleteAt",
    "setUnitLoadout",
    "getUnitLoadout",
    "selectRandomWeighted",
    "regexFind",
    "remoteExecCall",
    "moveInAny",  # A3-only; unknown on A2 OA 1.64, causes "Error Missing ;"
    "nearestTerrainObjects",  # A3-only; parse "Missing )" on A2 OA 1.64 (re-added: lost in a merge)
    "disableMove",  # invented identifier; does not exist on A2 OA 1.64 (nor A3); use disableAI "MOVE"
    "ctrlSetTooltip",  # A3-only; parse-kills the whole script on A2 OA 1.64 (live-burned RC26/27 WF menu)
    # NOTE: bare "insert" excluded. A3_TRAPS matching uses word-boundary regex
    # on comment/string-masked text (safe), but "insert" appears in plain English
    # comments too frequently to avoid noise.
)
# Narrowed: only flag == / != against literal true / false; numeric / string
# comparisons inside control expressions are valid A2 idioms.
BOOLEAN_OP_RE = re.compile(
    r"\b(if|while|waitUntil)\b[^\n]*(==|!=)\s*(?:true|false)\b"
    r"|\b(?:true|false)\s*(==|!=)",
    re.IGNORECASE,
)
# Inline private _var = value  (A3-only syntax, fatal on A2 OA 1.64)
A3PRIVATE_RE = re.compile(r"\bprivate\s+_[A-Za-z][A-Za-z0-9_]*\s*=")
# Hash array selector _arr # 0 (A3-only). Require char before # to be
# alphanumeric / _ / ) / ] so preprocessor lines and ## token-paste never match.
A3HASH_RE = re.compile(r"(?<=[A-Za-z0-9_)\]])\s*#(?!#)\s*(?:\d|_[A-Za-z])")
# publicVariableServer called from server-side code (path /Server/ or \Server\)
PUBVARSV_RE = re.compile(r"\bpublicVariableServer\b")
QUOTED_TOKEN_RE = re.compile(r'"([A-Za-z][A-Za-z0-9_]{2,})"|\'([A-Za-z][A-Za-z0-9_]{2,})\'')
CLASSNAME_HINT_RE = re.compile(r"^(?:[A-Z][A-Za-z0-9]*_|[A-Z]+_|[a-z]+_[A-Za-z0-9_]*|[A-Z][A-Za-z0-9]+[A-Z][A-Za-z0-9]*)")
DISPLAY_TOKEN_RE = re.compile(r"\b(displayCtrl|ctrlSetText|ctrlSetTextColor|ctrlShow|ctrlEnable|lb[A-Z]|lnb[A-Z])\b")
A3_MARKER_TYPE_RE = re.compile(r"(?<![A-Za-z0-9_])[\"']([bon]_[A-Za-z0-9_]+)[\"']", re.IGNORECASE)
# Valid A2/OA 1.64 CfgMarkers mil_* classes; anything else (e.g. "mil_air") throws
# "No entry ...CfgMarkers.<type>" on every client that renders the marker.
A2_MIL_MARKER_TYPES = frozenset((
    "mil_ambush", "mil_arrow", "mil_arrow2", "mil_box", "mil_circle", "mil_cross",
    "mil_destroy", "mil_dot", "mil_end", "mil_flag", "mil_join", "mil_marker",
    "mil_objective", "mil_pickup", "mil_start", "mil_triangle", "mil_unknown", "mil_warning",
))
MIL_MARKER_TYPE_RE = re.compile(r"(?<![A-Za-z0-9_])[\"'](mil_[A-Za-z0-9_]+)[\"']", re.IGNORECASE)
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
# Default-0 WFBE_C_* flag read: missionNamespace getVariable ["WFBE_C_<NAME>", 0]
# Only fires in diff mode (added-line context). Exclude Init_CommonConstants.sqf.
FLAGGATE_READ_RE = re.compile(
    r'\bgetVariable\s*\[\s*["\']WFBE_C_[A-Za-z0-9_]+["\']\s*,\s*0\s*\]',
    re.IGNORECASE,
)
# A sufficient numeric guard on the same / next-non-blank line: > 0, >0, != 0, !=0, == 1, ==1
FLAGGATE_GUARD_RE = re.compile(r"(?:>|!=|==)\s*(?:0|1)\b|(?:>|!=|==)(?:0|1)\b")
# Trailing comma immediately before a closing ] in an array literal. Runs on
# comment/string-masked text, so whitespace, newlines, and comments between the
# comma and the ] all still match — the preprocessor strips comments, meaning
# `true],\t//--- comment\n];` is still a fatal "Error Missing [" at mission init
# (PR #801 / Init_Defenses.sqf WFBE_POSITION_TEMPLATE_MAP incident, 2026-07-07).
TRAILCOMMA_RE = re.compile(r",\s*\]")
# U+FEFF as decoded by read_text (utf-8, NOT utf-8-sig): a leading EF BB BF
# survives decoding as this character, so BOM checks can run on the text.
BOM_CHAR = "\ufeff"
# noqa directive: // noqa or // noqa: CODE1,CODE2
NOQA_RE = re.compile(r"//\s*noqa(?:\s*:\s*([A-Za-z0-9_,\s]+))?\s*$", re.IGNORECASE)

FINDING_CODES = (
    "A3BISFNC",
    "A3CMD",
    "A3HASH",
    "A3MARKER",
    "A3NUMGATE",
    "A3PRIVATE",
    "A3REVEAL",
    "A3SELECT",
    "A3SORT",
    "A3STRING",
    "BOOLCMP",
    "BRACKET",
    "CLASSREF",
    "DBLBOM",
    "DEADNOQA",
    "DISABLESER",
    "FLAGGATE",
    "GROUPGETVAR",
    "MILMARKER",
    "NSSETVAR3",
    "PUBVARSV",
    "TRAILCOMMA",
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


def mask_comments_and_strings(text: str, string_fill: str = " ") -> str:
    """Blank comments and string literals, preserving length and newlines.

    Comments always become whitespace. String literals (quotes included) become
    string_fill — the default keeps the historical all-whitespace behaviour;
    rules that must distinguish "was a string" from "was whitespace/comment"
    (TRAILCOMMA) pass a non-whitespace fill instead.
    """
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
                    out.extend(string_fill * 2)
                    i += 2
                else:
                    out.append(string_fill)
                    i += 1
                    in_string = None
            else:
                out.append("\n" if ch == "\n" else string_fill)
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
            out.append(string_fill)
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


def parse_noqa_map(text: str) -> dict[int, set[str] | None]:
    """Parse // noqa directives from raw source text (before comment masking).

    Returns a dict mapping 1-based line numbers to:
      - None       => bare // noqa: suppress ALL findings on that line
      - set[str]   => // noqa: CODE1,CODE2 suppress only those codes

    Scans the original text so the comment is still present.
    Both .sqf and .hpp use // comments, so this works for all linted file types.
    """
    result: dict[int, set[str] | None] = {}
    for lineno, line in enumerate(text.splitlines(), 1):
        m = NOQA_RE.search(line)
        if not m:
            continue
        if m.group(1):
            codes = {c.strip().upper() for c in m.group(1).split(",") if c.strip()}
            if codes:
                result[lineno] = codes
            else:
                result[lineno] = None  # "// noqa:  " with no codes -> treat as bare
        else:
            result[lineno] = None  # bare // noqa
    return result


def lint_text(path: Path, text: str, root: Path, token_index: dict[str, set[Path]]) -> list[Finding]:
    """Lint a single file and return findings with noqa suppression applied.

    noqa directives are parsed from the raw text before masking so that
    // noqa: A3CMD on a line suppresses A3CMD findings on that exact line.
    DEADNOQA findings are appended for stale coded suppressions.
    """
    # Parse noqa directives before any masking (need comment text intact)
    noqa_map = parse_noqa_map(text)

    findings: list[Finding] = []
    masked = mask_comments_and_strings(text)
    comments_masked = mask_comments(text)
    starts = line_starts(masked)
    comments_starts = line_starts(comments_masked)

    # DBLBOM: at most one UTF-8 BOM, and only at byte 0. Scans RAW text —
    # masking would blank a BOM hiding inside a string literal, but the physical
    # bytes corrupt the file for the engine no matter where they sit. A doubled
    # leading BOM parse-fails the whole file at line 1 ("Error Invalid number in
    # expression") and nil'd the constants layer on live RC20/RC22 (2026-07-07,
    # stripped in PR #832). `starts` maps raw offsets: masking is length- and
    # newline-preserving.
    leading_boms = 0
    while leading_boms < len(text) and text[leading_boms] == BOM_CHAR:
        leading_boms += 1
    for match in re.finditer(BOM_CHAR, text):
        index = match.start()
        if index == 0:
            continue
        line, col = line_col(starts, index)
        if index < leading_boms:
            message = (
                "File starts with more than one UTF-8 BOM - the A2 OA engine fails the whole "
                "file at line 1 ('Error Invalid number in expression'); keep at most one BOM, at byte 0"
            )
        else:
            message = (
                "Stray UTF-8 BOM after byte 0 - remove it; BOM bytes are only valid as the "
                "very first bytes of a file"
            )
        findings.append(Finding(path, line, col, "DBLBOM", message))

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

    for match in MIL_MARKER_TYPE_RE.finditer(comments_masked):
        if match.group(1).lower() in A2_MIL_MARKER_TYPES:
            continue
        line, col = line_col(comments_starts, match.start())
        findings.append(Finding(path, line, col, "MILMARKER", f"Unknown mil_* marker type '{match.group(1)}' - not an A2/OA CfgMarkers class"))

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
        line, col = line_col(starts, match.start())
        findings.append(Finding(path, line, col, "BOOLCMP", "Comparison with literal true/false; use if (_flag) / if (!_flag) instead"))

    for match in A3PRIVATE_RE.finditer(masked):
        line, col = line_col(starts, match.start())
        findings.append(Finding(path, line, col, "A3PRIVATE",
            "Inline 'private _x = value' is A3-only; use 'private [\"_x\"]; _x = value' instead"))

    for match in A3HASH_RE.finditer(masked):
        line, col = line_col(starts, match.start())
        findings.append(Finding(path, line, col, "A3HASH",
            "The # array-selector (_arr # 0) is Arma 3-only; use (_arr select 0) instead"))

    # Strings must stay visible as non-whitespace here: [1, "two"] masked with
    # plain spaces would read as ",   ]" and false-positive. Same newline layout
    # as `masked`, so `starts` stays valid.
    trail_masked = mask_comments_and_strings(text, string_fill="\x00")
    for match in TRAILCOMMA_RE.finditer(trail_masked):
        line, col = line_col(starts, match.start())
        findings.append(Finding(path, line, col, "TRAILCOMMA",
            "Trailing comma before ] in array literal - fatal 'Error Missing [' parse error on A2 OA 1.64 "
            "(comments between the comma and ] are stripped by the preprocessor and do not save it)"))

    path_str = str(path)
    _server_parts = {"Server", "server"}
    if any(p in _server_parts for p in path.parts):
        for match in PUBVARSV_RE.finditer(masked):
            line, col = line_col(starts, match.start())
            findings.append(Finding(path, line, col, "PUBVARSV",
                "publicVariableServer on the server never fires the server's own PVEH "
                "— call the handler directly"))

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

    # Apply noqa suppression and emit DEADNOQA for stale coded suppressions.
    # Must run after all other rules so we know what each line actually fired.
    if noqa_map:
        kept: list[Finding] = []
        suppressed: list[Finding] = []
        for finding in findings:
            directive = noqa_map.get(finding.line)
            if finding.line in noqa_map and directive is None:
                # Bare // noqa -> suppress all
                suppressed.append(finding)
            elif directive is not None and finding.code in directive:
                suppressed.append(finding)
            else:
                kept.append(finding)
        findings = kept

        # Build DEADNOQA for coded noqa directives that suppressed nothing
        suppressed_by_line: dict[int, set[str]] = {}
        for f in suppressed:
            suppressed_by_line.setdefault(f.line, set()).add(f.code)

        for lineno, directive in noqa_map.items():
            if directive is None:
                # Bare noqa: never goes stale (spec: skip DEADNOQA for bare form)
                pass
            else:
                # Coded noqa: dead for each code that suppressed nothing
                suppressed_codes = suppressed_by_line.get(lineno, set())
                dead_codes = directive - suppressed_codes
                if dead_codes:
                    dead_str = ",".join(sorted(dead_codes))
                    findings.append(Finding(
                        path, lineno, 1, "DEADNOQA",
                        f"Stale // noqa: {dead_str} — no {dead_str} finding fires on this line",
                    ))

    return findings


def lint_flaggate(
    path: Path, text: str, added_line_nos: set[int]
) -> list[Finding]:
    """Emit FLAGGATE for added lines that read a default-0 WFBE_C_* flag without a numeric guard.

    Only call in diff mode. Excludes Init_CommonConstants.sqf (flag definitions).
    Checks the same line and the next non-blank line for a sufficient guard expression.

    Uses mask_comments (not mask_comments_and_strings) so string literal content is preserved
    for the flag-name regex match — the flag name lives inside a string.
    """
    if "Init_CommonConstants" in path.name:
        return []

    # mask_comments keeps string literals intact so the flag name is visible to the regex.
    masked = mask_comments(text)
    starts = line_starts(masked)
    raw_lines = text.splitlines()

    findings: list[Finding] = []
    for m in FLAGGATE_READ_RE.finditer(masked):
        line_no, col = line_col(starts, m.start())
        if line_no not in added_line_nos:
            continue

        # Check same line for a guard
        source_line = raw_lines[line_no - 1] if line_no <= len(raw_lines) else ""
        if FLAGGATE_GUARD_RE.search(source_line):
            continue

        # Check next non-blank line
        found_guard = False
        for next_lineno in range(line_no, min(line_no + 5, len(raw_lines))):
            next_line = raw_lines[next_lineno]  # 0-indexed, so this is line_no+1
            if not next_line.strip():
                continue
            if FLAGGATE_GUARD_RE.search(next_line):
                found_guard = True
            break
        if found_guard:
            continue

        findings.append(Finding(
            path, line_no, col, "FLAGGATE",
            "Default-0 flag read without numeric guard (> 0 / != 0 / == 1); "
            "use (missionNamespace getVariable [..., 0] > 0)",
        ))
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

    # Determine if FLAGGATE should run (diff mode only)
    flaggate_active = (
        added_lines is not None
        and (selected_codes is None or "FLAGGATE" in selected_codes)
        and "FLAGGATE" not in ignored_codes
    )

    findings: list[Finding] = []
    for path in files:
        resolved = path.resolve()
        raw_text = read_text(path)
        findings.extend(lint_text(resolved, raw_text, root, token_index))

        # FLAGGATE: diff-mode only, runs on added lines
        if flaggate_active:
            file_added = added_lines.get(resolved, set())  # type: ignore[union-attr]
            if file_added:
                findings.extend(lint_flaggate(resolved, raw_text, file_added))

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
