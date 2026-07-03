#!/usr/bin/env python3
"""
Offline link checker for a local GitHub wiki checkout.

The checker is intentionally conservative: it only validates links that can be
resolved inside the supplied wiki directory, and reports external URLs as
ignored rather than trying to reach the network.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple
from urllib.parse import unquote, urlparse


MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
WIKI_LINK_RE = re.compile(r"\[\[([^\]\n]+)\]\]")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
BUILD_RE = re.compile(r"\b(?:Build|build|B)(\d{2,3})\b")
NON_ANCHOR_RE = re.compile(r"[^a-z0-9 _-]")

SPECIAL_PAGES = {"_Sidebar.md", "_Footer.md"}
IGNORED_SCHEMES = {"http", "https", "mailto", "tel", "ftp"}


@dataclass(frozen=True)
class Finding:
    code: str
    path: str
    line: int
    target: str
    message: str


@dataclass
class Page:
    path: Path
    rel: str
    name: str
    anchors: Set[str]


def strip_code(text: str) -> str:
    """Remove fenced code blocks before scanning prose links/headings."""
    out: List[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append("")
        elif in_fence:
            out.append("")
        else:
            out.append(line)
    return "\n".join(out)


def github_anchor(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"<[^>]+>", "", text)
    text = NON_ANCHOR_RE.sub("", text)
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


def heading_anchors(text: str) -> Set[str]:
    anchors: Set[str] = set()
    seen: Dict[str, int] = {}
    for line in strip_code(text).splitlines():
        match = HEADING_RE.match(line)
        if not match:
            continue
        base = github_anchor(match.group(2))
        if not base:
            continue
        count = seen.get(base, 0)
        seen[base] = count + 1
        anchors.add(base if count == 0 else f"{base}-{count}")
    return anchors


def page_name(path: Path) -> str:
    return path.stem.replace(" ", "-")


def collect_pages(root: Path) -> Dict[str, Page]:
    pages: Dict[str, Page] = {}
    for path in sorted(root.glob("*.md")):
        rel = path.name
        name = page_name(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        page = Page(path=path, rel=rel, name=name, anchors=heading_anchors(text))
        pages[name.lower()] = page
        pages[path.stem.lower()] = page
        pages[rel.lower()] = page
    return pages


def collect_assets(root: Path) -> Set[str]:
    assets: Set[str] = set()
    for path in root.iterdir():
        if path.is_file():
            assets.add(path.name.lower())
            assets.add(path.stem.lower())
    return assets


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def split_target(raw: str) -> Tuple[str, str]:
    raw = raw.strip()
    if "#" not in raw:
        return raw, ""
    target, anchor = raw.split("#", 1)
    return target, unquote(anchor).strip()


def normalize_wiki_target(raw: str) -> str:
    # GitHub wiki links can be [[Label|Page Name]] or [[Page Name]].
    target = raw.split("|", 1)[-1].strip()
    return target.replace(" ", "-")


def normalize_markdown_target(raw: str) -> str:
    raw = raw.strip("<>")
    raw = unquote(raw)
    return raw.replace(" ", "-")


def is_external(raw: str) -> bool:
    parsed = urlparse(raw)
    return parsed.scheme.lower() in IGNORED_SCHEMES


def looks_like_sqf_array_link(raw: str) -> bool:
    # Unfenced SQF arrays such as [[1000,0],[WFBE_UP_AIR,1]] look like wiki
    # links. Real wiki links in this project use page names, not comma tuples.
    stripped = raw.strip().strip("[]")
    return ("," in raw and "|" not in raw) or stripped.isdigit()


def resolve_asset(root: Path, assets: Set[str], current: Path, raw_target: str) -> bool:
    target = raw_target.strip().strip("/")
    if target == "":
        return True
    direct = (current.parent / target).resolve()
    try:
        direct.relative_to(root.resolve())
    except ValueError:
        return False
    if direct.exists() and direct.is_file():
        return True
    key = Path(target).name.lower()
    return key in assets


def resolve_page(root: Path, pages: Dict[str, Page], current: Path, raw_target: str) -> Optional[Page]:
    target = raw_target.strip()
    if target == "":
        return pages.get(current.name.lower())

    target = target.strip("/")
    if target.endswith(".md"):
        direct = (current.parent / target).resolve()
        try:
            direct.relative_to(root.resolve())
        except ValueError:
            return None
        if direct.exists() and direct.suffix.lower() == ".md":
            return pages.get(direct.name.lower())

    key = Path(target).name
    key = key[:-3] if key.lower().endswith(".md") else key
    return pages.get(key.lower())


def iter_links(text: str) -> Iterable[Tuple[int, str, str]]:
    scan = strip_code(text)
    for match in MARKDOWN_LINK_RE.finditer(scan):
        yield match.start(1), "markdown", match.group(1)
    for match in WIKI_LINK_RE.finditer(scan):
        yield match.start(1), "wiki", match.group(1)


def check_links(root: Path, pages: Dict[str, Page], assets: Set[str]) -> Tuple[List[Finding], Dict[str, Set[str]]]:
    findings: List[Finding] = []
    unique_pages_by_rel = {page.rel: page for page in pages.values()}
    incoming: Dict[str, Set[str]] = {rel: set() for rel in unique_pages_by_rel}
    unique_pages = sorted(unique_pages_by_rel.values(), key=lambda p: p.rel)

    for page in unique_pages:
        text = page.path.read_text(encoding="utf-8", errors="replace")
        for offset, kind, raw in iter_links(text):
            if is_external(raw):
                continue
            if looks_like_sqf_array_link(raw):
                continue
            target_raw, anchor = split_target(raw)
            target = normalize_wiki_target(target_raw) if kind == "wiki" else normalize_markdown_target(target_raw)
            target_page = resolve_page(root, pages, page.path, target)
            line = line_number(strip_code(text), offset)
            if target_page is None:
                if resolve_asset(root, assets, page.path, target):
                    continue
                findings.append(Finding("DEADLINK", page.rel, line, raw, "Cannot resolve wiki page target"))
                continue
            incoming[target_page.rel].add(page.rel)
            if anchor:
                normalized_anchor = github_anchor(anchor)
                if normalized_anchor not in target_page.anchors:
                    findings.append(Finding("BADANCHOR", page.rel, line, raw, "Target page exists, but anchor was not found"))
    return findings, incoming


def check_orphans(pages: Dict[str, Page], incoming: Dict[str, Set[str]]) -> List[Finding]:
    findings: List[Finding] = []
    for page in sorted({page.rel: page for page in pages.values()}.values(), key=lambda p: p.rel):
        if page.rel in SPECIAL_PAGES or page.rel.lower() == "home.md":
            continue
        if not incoming.get(page.rel):
            findings.append(Finding("ORPHAN", page.rel, 1, page.name, "No incoming wiki links found"))
    return findings


def check_stale_builds(root: Path, current_build: int) -> List[Finding]:
    findings: List[Finding] = []
    for path in sorted(root.glob("*.md")):
        text = strip_code(path.read_text(encoding="utf-8", errors="replace"))
        for line_no, line in enumerate(text.splitlines(), start=1):
            for match in BUILD_RE.finditer(line):
                value = int(match.group(1))
                if value < current_build:
                    findings.append(Finding("STALEBUILD", path.name, line_no, match.group(0), f"Mentions build {value}; current build is {current_build}"))
    return findings


def print_text(findings: Sequence[Finding]) -> None:
    for item in findings:
        print(f"{item.path}:{item.line}: {item.code}: {item.target}: {item.message}")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Check a local GitHub wiki clone for link hygiene.")
    parser.add_argument("wiki_root", type=Path, help="Path to the local a2waspwarfare.wiki checkout")
    parser.add_argument("--current-build", type=int, default=86, help="Current build number for STALEBUILD findings")
    parser.add_argument("--include-stale-builds", action="store_true", help="Report older Build/B references")
    parser.add_argument("--no-orphans", action="store_true", help="Skip ORPHAN findings")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    parser.add_argument("--fail-on", default="DEADLINK,BADANCHOR", help="Comma-separated finding codes that should return exit 1")
    parser.add_argument("--exit-zero", action="store_true", help="Always return exit code 0 after reporting findings")
    args = parser.parse_args(argv)

    root = args.wiki_root.resolve()
    if not root.exists() or not root.is_dir():
        print(f"wiki root does not exist or is not a directory: {root}", file=sys.stderr)
        return 2

    pages = collect_pages(root)
    assets = collect_assets(root)
    link_findings, incoming = check_links(root, pages, assets)
    findings = list(link_findings)
    if not args.no_orphans:
        findings.extend(check_orphans(pages, incoming))
    if args.include_stale_builds:
        findings.extend(check_stale_builds(root, args.current_build))

    findings.sort(key=lambda f: (f.path.lower(), f.line, f.code, f.target))
    if args.json:
        print(json.dumps([asdict(item) for item in findings], indent=2))
    else:
        print_text(findings)
        counts: Dict[str, int] = {}
        for item in findings:
            counts[item.code] = counts.get(item.code, 0) + 1
        summary = ", ".join(f"{code}={counts[code]}" for code in sorted(counts)) or "no findings"
        print(f"SUMMARY: pages={len({page.rel for page in pages.values()})} findings={len(findings)} {summary}")

    fail_codes = {code.strip().upper() for code in args.fail_on.split(",") if code.strip()}
    if args.exit_zero:
        return 0
    if any(item.code in fail_codes for item in findings):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
