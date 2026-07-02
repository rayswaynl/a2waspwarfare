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
)
BOOLEAN_OP_RE = re.compile(r"\b(if|while|waitUntil)\b[^\n]*(==|!=)")
QUOTED_TOKEN_RE = re.compile(r'"([A-Za-z][A-Za-z0-9_]{2,})"|\'([A-Za-z][A-Za-z0-9_]{2,})\'')
CLASSNAME_HINT_RE = re.compile(r"^(?:[A-Z][A-Za-z0-9]*_|[A-Z]+_|[a-z]+_[A-Za-z0-9_]*|[A-Z][A-Za-z0-9]+[A-Z][A-Za-z0-9]*)")
DISPLAY_TOKEN_RE = re.compile(r"\b(displayCtrl|ctrlSetText|ctrlSetTextColor|ctrlShow|ctrlEnable|lb[A-Z]|lnb[A-Z])\b")


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
    starts = line_starts(masked)

    for trap in A3_TRAPS:
        for match in re.finditer(rf"\b{re.escape(trap)}\b", masked):
            line, col = line_col(starts, match.start())
            findings.append(Finding(path, line, col, "A3CMD", f"Arma 3-only command or prompt trap: {trap}"))

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


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Run WASP SQF lint checks.")
    parser.add_argument("paths", nargs="*", type=Path, help="Files or directories to scan. Defaults to both maintained mission roots.")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root for relative paths and classname indexing.")
    parser.add_argument("--no-classname-index", action="store_true", help="Skip quoted classname-like token uniqueness checks.")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    default_paths = [
        root / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
        root / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ]
    scan_paths = [path if path.is_absolute() else root / path for path in (args.paths or default_paths)]
    files = iter_files(scan_paths)
    if not files:
        print("No SQF/HPP/EXT/FSM/SQM files found for requested paths.", file=sys.stderr)
        return 2

    token_index: dict[str, set[Path]] = {}
    if not args.no_classname_index:
        token_index = build_token_index(root)

    findings: list[Finding] = []
    for path in files:
        findings.extend(lint_text(path.resolve(), read_text(path), root, token_index))

    for finding in findings:
        print(finding.render(root))
    print(f"Scanned {len(files)} file(s); findings: {len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
