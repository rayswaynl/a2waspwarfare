#!/usr/bin/env python3
"""Independent reader/validator for Arma 2: OA `.pbo` archives.

Written separately from `pack_pbo.py`'s writer so that verifying a packed
output means two independently-implemented parsers agreeing on the same
bytes, not the writer grading its own homework. Also usable stand-alone
against any existing PBO (including third-party ones) to inspect its header,
list its entries, verify its checksum, and optionally extract or diff its
contents against a source folder.

Usage:
    python read_pbo.py PBO_PATH
    python read_pbo.py PBO_PATH --extract-to DIR
    python read_pbo.py PBO_PATH --diff-source MISSION_DIR

Exit code is non-zero if the checksum fails to verify, or (with
--diff-source) if any entry's bytes do not match the source folder.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path
from typing import List, Tuple

MAGIC_VERS = 0x56657273


class PboFormatError(RuntimeError):
    pass


def read_cstr(buf: bytes, offset: int) -> Tuple[str, int]:
    end = buf.index(b"\x00", offset)
    return buf[offset:end].decode("latin-1"), end + 1


def parse_pbo(buf: bytes):
    """Parse a PBO byte buffer. Returns (properties: dict, entries: list of
    (name, mimetype, original_size, reserved, timestamp, data_size), data_start:
    int, trailer: bytes)."""
    o = 0
    name, o = read_cstr(buf, o)
    mimetype, original_size, reserved, timestamp, data_size = struct.unpack_from("<5I", buf, o)
    o += 20
    if name != "" or mimetype != MAGIC_VERS:
        raise PboFormatError(
            f"First entry is not the expected empty-name/'Vers' header "
            f"(name={name!r}, mimetype=0x{mimetype:08x})"
        )

    raw_props: List[str] = []
    while True:
        s, o = read_cstr(buf, o)
        if s == "":
            break
        raw_props.append(s)
    properties = dict(zip(raw_props[0::2], raw_props[1::2]))

    entries = []
    while True:
        nm, o = read_cstr(buf, o)
        mi, osz, rv, ts, ds = struct.unpack_from("<5I", buf, o)
        o += 20
        if nm == "" and mi == 0 and osz == 0 and ds == 0:
            break
        entries.append((nm, mi, osz, rv, ts, ds))

    data_start = o
    data_end = data_start + sum(e[5] for e in entries)
    trailer = buf[data_end:]
    return properties, entries, data_start, data_end, trailer


def verify_checksum(buf: bytes, data_end: int, trailer: bytes) -> bool:
    if len(trailer) != 21 or trailer[0] != 0:
        return False
    stored = trailer[1:]
    computed = hashlib.sha1(buf[:data_end]).digest()
    return stored == computed


def extract_entry_data(buf: bytes, entries, data_start: int):
    """Return {name: bytes} for every entry, in stored order. Only correct for
    mimetype==0 (uncompressed) entries, which is all this project's build
    lineage ever produced; a compressed (mimetype != 0) entry is returned as
    its raw (still-compressed) stored bytes with a note, since decompression
    is out of scope here."""
    out = {}
    off = data_start
    notes = []
    for nm, mi, osz, _rv, _ts, ds in entries:
        out[nm] = buf[off : off + ds]
        if mi != 0:
            notes.append(f"{nm}: mimetype=0x{mi:08x} (compressed - not decompressed)")
        off += ds
    return out, notes


def main(argv: List[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("pbo", type=Path, help="Path to the .pbo file to read")
    p.add_argument("--extract-to", type=Path, default=None, help="Extract all entries to this directory")
    p.add_argument(
        "--diff-source",
        type=Path,
        default=None,
        help="Byte-compare every stored entry against files under this mission folder "
        "(case-insensitive path match, backslash-normalised)",
    )
    args = p.parse_args(argv)

    buf = args.pbo.read_bytes()

    try:
        properties, entries, data_start, data_end, trailer = parse_pbo(buf)
    except PboFormatError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"file: {args.pbo}  ({len(buf):,} bytes)")
    print(f"properties: {properties}")
    print(f"entry count: {len(entries)}")
    mimetypes = {mi for _n, mi, *_r in entries}
    print(f"distinct entry mimetypes: {[hex(m) for m in sorted(mimetypes)]} (0x0 == uncompressed)")

    ok = verify_checksum(buf, data_end, trailer)
    print(
        f"trailer: {len(trailer)} bytes, leading byte={trailer[0] if trailer else 'MISSING'}, "
        f"checksum(SHA1 of bytes[0:{data_end}]) {'OK' if ok else 'MISMATCH'}"
    )

    data, notes = extract_entry_data(buf, entries, data_start)
    for note in notes:
        print(f"note: {note}")

    lower_dupes = {}
    for nm, *_rest in entries:
        lower_dupes.setdefault(nm.lower(), []).append(nm)
    mixed_case = [nm for nm in lower_dupes if any(v != nm for v in lower_dupes[nm])]
    print(f"entries with any uppercase char stored: {sum(1 for n, *_ in entries if n != n.lower())}")

    if args.extract_to:
        args.extract_to.mkdir(parents=True, exist_ok=True)
        for nm, blob in data.items():
            dest = args.extract_to / nm.replace("\\", "/")
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(blob)
        print(f"extracted {len(data)} files to {args.extract_to}")

    diff_ok = True
    if args.diff_source:
        source_map = {}
        for f in args.diff_source.rglob("*"):
            if f.is_file():
                rel = str(f.relative_to(args.diff_source)).replace("/", "\\").lower()
                source_map[rel] = f
        missing = []
        mismatched = []
        matched = 0
        for nm, blob in data.items():
            src = source_map.get(nm.lower())
            if src is None:
                missing.append(nm)
                continue
            if src.read_bytes() == blob:
                matched += 1
            else:
                mismatched.append(nm)
        print(
            f"diff-source: {matched} byte-identical, {len(mismatched)} mismatched, "
            f"{len(missing)} not found under source"
        )
        if mismatched:
            print("  mismatched (first 20):", mismatched[:20])
            diff_ok = False
        if missing:
            print("  missing under source (first 20):", missing[:20])
            diff_ok = False

    return 0 if (ok and diff_ok) else 1


if __name__ == "__main__":
    raise SystemExit(main())
