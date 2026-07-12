#!/usr/bin/env python3
"""Pack a WASP Warfare mission folder into an Arma 2: OA `.pbo` archive.

Provenance
----------
This replaces ~90 hand-rolled, one-off `_pack_*.py` / `pack_*.py` scripts that
lived only on the Game PC build box (`C:\\Users\\Game\\_pack_*.py` and
`C:\\Users\\Game\\wasp-build\\*.py`, one new copy-pasted per build from
`_pack_b48_pbo.py` in 2026-06 through `pack_release_ch.py` in 2026-07-09).
Nobody had those scripts checked in anywhere, so the only way to reproduce a
launch PBO was to already have one of those files sitting on that one machine
(bus-factor-1 in practice, even though no single person had it memorized).

This script is a faithful, generalised reimplementation of what every one of
those scripts did. It is NOT a wrapper around cpbo/armake2/MakePbo — none of
those tools are installed on the dev boxes, and the recovered scripts never
called out to one either. Like them, this is a pure-stdlib writer of the raw
Arma PBO binary format.

PBO binary format (as emitted here, matching the recovered scripts and the
publicly documented BI PBO format at a high level):

  1. A "Vers" header entry: empty name, then 5x uint32 LE
     (mimetype=0x56657273 'Vers', original_size=0, reserved=0, timestamp=0,
     data_size=0). This tells any reader a properties block follows.
  2. A properties block: null-terminated `key`, null-terminated `value`,
     repeated, terminated by one empty (zero-length) string. This tool only
     ever writes a single `prefix` property, matching every recovered script.
  3. One entry per packed file: null-terminated relative path (backslash
     separators), then 5x uint32 LE (mimetype=0 "uncompressed",
     original_size, reserved=0, timestamp=0, data_size). mimetype is always 0
     and data_size always equals original_size — none of the recovered
     scripts ever compressed an entry, and neither does this one.
  4. A terminating entry: empty name, all 5 fields zero.
  5. The raw bytes of every file, concatenated in the same order as the
     entries above (no per-file padding, no line-ending translation).
  6. A single 0x00 byte, then a 20-byte SHA1 digest of everything from byte 0
     up to (but NOT including) that trailing 0x00 byte. This exact
     hash-boundary convention (hash the header+data, then prefix the digest
     with one extra zero byte that is itself excluded from the hash) is what
     every recovered script did and is what the live server has been loading
     successfully for weeks, so it is treated as the ground truth here rather
     than any generic description of "PBO checksums."

Where this diverges from a hypothetical "by the book" packer:
  - Every stored path is lowercased. The original 2026-06/early-07 scripts did
    NOT do this and it caused a real bug (owner-reported 2026-07-09,
    "Cannot load texture ... loadscreen.jpg"): real PBO packers (MakePbo /
    cpbo / armake2) lowercase every internal path, and Arma's texture lookup
    is effectively case-sensitive against whatever got stored. The fix landed
    in `pack_release_ch.py` (the newest script recovered) and is preserved
    here as the default, correct behaviour.
  - No compression is ever attempted (mimetype always 0). This matches every
    recovered script; real BI tools can also emit LZSS-compressed entries
    (mimetype 0x43707273), but nothing in this project's build lineage ever
    used that, so it is intentionally not implemented.
  - File bytes are read/written exactly as-is (`open(..., 'rb')` /
    concatenation of raw bytes) — no CRLF normalisation of any kind. This
    matches every recovered script; PBO entries are opaque byte blobs.

See `Tools/Pack/PBO-PACKING.md` for the full writeup, the exact commands for
each of the three launch missions, and the verification procedure.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys
from pathlib import Path
from typing import List, Tuple

MAGIC_VERS = 0x56657273  # ASCII "Vers" (big-endian reading) - properties-follow signal
EXCLUDED_SUFFIXES = (".template", ".bak", ".orig")
STRUCT5I = struct.Struct("<5I")


class PackError(RuntimeError):
    """Raised for any condition that should abort packing before a byte is written."""


def log(msg: str, quiet: bool = False) -> None:
    if not quiet:
        print(msg)


def az(s: str) -> bytes:
    """Encode a string as a null-terminated PBO string entry (latin-1, as the
    recovered scripts always used — mission asset paths/names are ASCII)."""
    try:
        return s.encode("latin-1") + b"\x00"
    except UnicodeEncodeError as exc:
        raise PackError(f"Path/prefix contains a non-latin1 character: {s!r} ({exc})")


def collect_files(source: Path) -> List[Tuple[str, bytes]]:
    """Walk `source` and return (lowercased backslash-relative-path, data) pairs,
    skipping .template/.bak/.orig files exactly like every recovered script."""
    files: List[Tuple[str, bytes]] = []
    for root, _dirs, fnames in os.walk(source):
        for fn in fnames:
            if fn.lower().endswith(EXCLUDED_SUFFIXES):
                continue
            full = Path(root) / fn
            rel = str(full.relative_to(source)).replace(os.sep, "\\").replace("/", "\\")
            files.append((rel.lower(), full.read_bytes()))
    return files


def check_lowercase_collisions(files: List[Tuple[str, bytes]]) -> None:
    """Guard 0 from pack_release_ch.py: lowercasing must never collide two
    originally-different-case source files onto the same stored entry."""
    seen = set()
    for rel, _ in files:
        if rel in seen:
            raise PackError(
                f"ABORT: lowercase path collision on '{rel}' - two source files "
                "differ only by case; refusing to pack (would silently drop one)."
            )
        seen.add(rel)


def ensure_version_sqf(
    source: Path, files: List[Tuple[str, bytes]], strict_version: bool, quiet: bool
) -> None:
    """Ensure exactly one `version.sqf` entry exists. Real deployments carry a
    real (gitignored) version.sqf; a fresh checkout only has the tracked
    `version.sqf.template`. description.ext / initJIPCompatible.sqf both
    `#include "version.sqf"`, so packing without one produces a mission that
    fails to load with "Include file not found"."""
    have_real = any(rel == "version.sqf" for rel, _ in files)
    if have_real:
        return

    template = source / "version.sqf.template"
    if strict_version or not template.exists():
        raise PackError(
            f"No version.sqf found in {source} (it is gitignored by design). "
            + (
                "Refusing to synthesize one because --strict-version was passed."
                if template.exists()
                else "No version.sqf.template found either - cannot proceed."
            )
        )

    log(
        "WARNING: version.sqf missing (expected - it is gitignored). Falling back to "
        "version.sqf.template for this pack. This is fine for a structural/smoke build, "
        "but replace it with a real version.sqf before any actual deploy.",
        quiet,
    )
    files.append(("version.sqf", template.read_bytes()))


def check_debug_guard(files: List[Tuple[str, bytes]], allow_debug: bool, quiet: bool) -> None:
    """Universal guard present in every recovered script, in one form or
    another: never pack a mission with an active (uncommented) WF_DEBUG
    define. WF_DEBUG grants near-infinite funds, unlocks every unit tier, and
    enables a teleport/cheat menu - fine for local smoke tests, never for a
    real build."""
    version_entries = [(r, d) for r, d in files if r == "version.sqf"]
    for _rel, data in version_entries:
        for line in data.splitlines():
            stripped = line.strip()
            if stripped.startswith(b"#define WF_DEBUG") and not stripped.startswith(b"//"):
                if allow_debug:
                    log(
                        "!!!!!! WARNING: ACTIVE #define WF_DEBUG in version.sqf, packing "
                        "anyway because --allow-debug was passed. DO NOT deploy this "
                        "PBO to a real server. !!!!!!",
                        quiet,
                    )
                    return
                raise PackError(
                    "ABORT: ACTIVE #define WF_DEBUG in version.sqf - comment it out "
                    "(// #define WF_DEBUG 1) before packing, or pass --allow-debug for "
                    "a throwaway local smoke build."
                )


def derive_prefix(folder_name: str, build_tag: str | None) -> str:
    """Default PBO `prefix` property. With no --build-tag this is just the
    mission folder's own name (e.g. "[55-2hc]warfarev2_073v48co.chernarus").
    With a --build-tag it follows the same "insert the tag before the terrain
    suffix" convention every recovered script used
    (`[55-2hc]warfarev2_073v48co_<BUILD>.chernarus`), but derived generically
    from whatever folder name is passed in rather than hardcoded per-build."""
    if not build_tag:
        return folder_name
    stem, sep, terrain = folder_name.rpartition(".")
    if sep:
        return f"{stem}_{build_tag}.{terrain}"
    return f"{folder_name}_{build_tag}"


def build_pbo_bytes(files: List[Tuple[str, bytes]], prefix: str) -> bytes:
    """Assemble the full PBO byte stream (header + properties + file table +
    terminator + concatenated data + checksum) for an already-collected,
    already-sorted file list."""
    hdr = bytearray()
    hdr += b"\x00" + STRUCT5I.pack(MAGIC_VERS, 0, 0, 0, 0)
    hdr += az("prefix") + az(prefix) + b"\x00"
    for path, data in files:
        hdr += az(path) + STRUCT5I.pack(0, len(data), 0, 0, len(data))
    hdr += b"\x00" + STRUCT5I.pack(0, 0, 0, 0, 0)

    body = bytes(hdr) + b"".join(data for _, data in files)
    checksum = hashlib.sha1(body).digest()
    return body + b"\x00" + checksum


def self_check(pbo_bytes: bytes, expected_entry_count: int) -> None:
    """Minimal sanity check on our own freshly-built bytes (NOT the
    independent validation - see Tools/Pack/read_pbo.py and PBO-PACKING.md for
    that). This only confirms we wrote what we meant to write."""

    def raz(buf: bytes, o: int) -> Tuple[str, int]:
        e = buf.index(b"\x00", o)
        return buf[o:e].decode("latin-1"), e + 1

    o = 0
    name, o = raz(pbo_bytes, o)
    mime = struct.unpack_from("<5I", pbo_bytes, o)[0]
    o += 20
    if name != "" or mime != MAGIC_VERS:
        raise PackError("internal error: wrote a malformed header (self-check failed)")

    props = []
    while True:
        s, o = raz(pbo_bytes, o)
        if s == "":
            break
        props.append(s)
    if props[:1] != ["prefix"]:
        raise PackError("internal error: prefix property missing (self-check failed)")

    count = 0
    while True:
        nm, o = raz(pbo_bytes, o)
        mi, osz, _rv, _ts, ds = struct.unpack_from("<5I", pbo_bytes, o)
        o += 20
        if nm == "" and mi == 0 and osz == 0 and ds == 0:
            break
        count += 1
    if count != expected_entry_count:
        raise PackError(
            f"internal error: wrote {count} entries, expected {expected_entry_count} "
            "(self-check failed)"
        )


def pack(
    source: Path,
    output: Path,
    prefix: str | None,
    build_tag: str | None,
    allow_debug: bool,
    strict_version: bool,
    force: bool,
    quiet: bool,
) -> None:
    if not source.is_dir():
        raise PackError(f"Source mission folder not found or not a directory: {source}")
    if output.exists() and not force:
        raise PackError(f"Output already exists (pass --force to overwrite): {output}")

    files = collect_files(source)
    if not files:
        raise PackError(f"No files found under {source} (after excluding {EXCLUDED_SUFFIXES})")

    ensure_version_sqf(source, files, strict_version, quiet)
    check_lowercase_collisions(files)
    check_debug_guard(files, allow_debug, quiet)

    files.sort(key=lambda x: x[0])

    final_prefix = prefix if prefix else derive_prefix(source.name, build_tag)

    pbo_bytes = build_pbo_bytes(files, final_prefix)
    self_check(pbo_bytes, expected_entry_count=len(files))

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(pbo_bytes)

    log(
        f"wrote {output} ({len(pbo_bytes):,} bytes, {len(files)} files, "
        f"prefix={final_prefix!r})",
        quiet,
    )
    log(f"  build_tag={build_tag!r}", quiet)
    log(
        "self-check OK. For independent validation run: "
        f"python Tools/Pack/read_pbo.py \"{output}\"",
        quiet,
    )


def parse_args(argv: List[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Pack a WASP Warfare mission folder into an Arma 2: OA .pbo file.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument(
        "--source",
        required=True,
        type=Path,
        help="Mission folder to pack, e.g. "
        '"Missions/[55-2hc]warfarev2_073v48co.chernarus"',
    )
    p.add_argument("--output", required=True, type=Path, help="Output .pbo path")
    p.add_argument(
        "--prefix",
        default=None,
        help="Override the PBO 'prefix' property. Default: derived from the "
        "source folder name (and --build-tag, if given).",
    )
    p.add_argument(
        "--build-tag",
        default=None,
        help="Free-form build tag, folded into the default --prefix and printed "
        "in the summary. Purely informational otherwise.",
    )
    p.add_argument(
        "--allow-debug",
        action="store_true",
        help="Pack even if version.sqf has an active #define WF_DEBUG (prints a "
        "loud warning). Default: abort.",
    )
    p.add_argument(
        "--strict-version",
        action="store_true",
        help="Require a real version.sqf on disk; refuse to fall back to "
        "version.sqf.template. Use for real deploy builds.",
    )
    p.add_argument("--force", action="store_true", help="Overwrite an existing --output file.")
    p.add_argument("--quiet", action="store_true", help="Only print warnings/errors.")
    return p.parse_args(argv)


def main(argv: List[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        pack(
            source=args.source,
            output=args.output,
            prefix=args.prefix,
            build_tag=args.build_tag,
            allow_debug=args.allow_debug,
            strict_version=args.strict_version,
            force=args.force,
            quiet=args.quiet,
        )
    except PackError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
