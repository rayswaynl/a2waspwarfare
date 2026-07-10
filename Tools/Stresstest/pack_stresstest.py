#!/usr/bin/env python3
"""Pack a WASP stresstest mission into a PBO, with version.sqf rendered + asserted.

Background (read-only recon, 2026-07-08/09): there is no Mikero pboProject / BI AddonBuilder
on the build box. Every deployed WASP build (200+ builds) has instead been packed by
hand-rolled, per-build, throwaway Python scripts under `C:\\Users\\Game\\wasp-build\\_pack_*.py`
that construct the Arma PBO binary format directly (a custom header + `prefix` entry + one
header entry per file + a SHA1 trailer over the whole body) and walk a git checkout directory
for the file list. That IS the project's build tool; there is no other packer to shell out to.
This script is a repo-tracked, reviewed port of that exact binary-pack routine.

The defect this script fixes: the historical per-build scripts skip `*.template` files while
walking the checkout (`version.sqf.template` is git-tracked; the real `version.sqf` it renders
to is git-ignored and only ever created by a manual copy step) and never render `version.sqf`
before packing. A fresh checkout therefore has no `version.sqf` on disk, the walk silently omits
it, and the resulting PBO ships without it. Both `description.ext` and `initJIPCompatible.sqf`
`#include "version.sqf"`, so the mission fails to parse at load time -- confirmed live 2026-07-09
on the `[61-2hc]warfarev2_073v48co_stresstest.zargabad` PBO ("3/3 up" was a false positive; the
RPT failure probe used at the time did not include the `Include file` / `not found` signatures
that this failure mode actually produces -- see deploy.ps1/rollback.ps1 in this same directory).

This script renders version.sqf from version.sqf.template FIRST and ASSERTS it exists and is
well-formed before ever building the PBO body -- it fails loudly (non-zero exit) instead of
silently shipping a broken build.

Usage:
    python Tools\\Stresstest\\pack_stresstest.py ^
        --mission-dir "C:\\Users\\Game\\a2wasp-fold89\\Missions_Vanilla\\[61-2hc]warfarev2_073v48co.zargabad" ^
        --out "C:\\Users\\Game\\wasp-build\\stresstest-zg.pbo" ^
        --prefix "[61-2hc]warfarev2_073v48co_stresstest.zargabad" ^
        --candidate "stresstest-20260709"

--git-sha defaults to `git -C <mission-dir> rev-parse --short HEAD` when omitted.
--terrain defaults to the mission folder's suffix after the last '.' (e.g. "zargabad").
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import struct
import subprocess
import sys
from pathlib import Path

SKIP_SUFFIXES = (".template", ".bak", ".orig")
WF_DEBUG_LIVE_RE = re.compile(r"^\s*#define\s+WF_DEBUG\b", re.MULTILINE)
RELEASE_MARKER_RE = re.compile(r'^#define\s+WF_RELEASE_MARKER\s+"[^"]*"\s*$', re.MULTILINE)


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def detect_git_sha(mission_dir: Path) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(mission_dir), "rev-parse", "--short", "HEAD"],
            check=True, capture_output=True, text=True,
        )
        return result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def detect_terrain(mission_dir: Path) -> str:
    name = mission_dir.name
    if "." in name:
        return name.rsplit(".", 1)[-1]
    return "manual"


def render_version_sqf(mission_dir: Path, candidate: str, git_sha: str, terrain: str) -> Path:
    """Render version.sqf from version.sqf.template. Returns the written path.

    Forces WF_DEBUG to stay commented (defensive: even if the template somehow had it live,
    a stresstest build must never ship with instant-funds/all-tiers-unlocked debug mode) and
    stamps a fresh WF_RELEASE_MARKER line built from candidate/git_sha/terrain.
    """
    template_path = mission_dir / "version.sqf.template"
    if not template_path.is_file():
        raise SystemExit(f"ABORT: {template_path} not found - cannot render version.sqf without its tracked template.")

    text = template_path.read_text(encoding="utf-8")

    # Defensive: comment out any live (uncommented) WF_DEBUG define.
    text = WF_DEBUG_LIVE_RE.sub(lambda m: "// " + m.group(0).lstrip(), text)

    marker = f'#define WF_RELEASE_MARKER "WASPRELEASE|v1|candidate={candidate}|git={git_sha}|terrain={terrain}"'
    text, n = RELEASE_MARKER_RE.subn(marker, text)
    if n != 1:
        raise SystemExit(
            f"ABORT: expected exactly one WF_RELEASE_MARKER #define line in {template_path}, found {n}. "
            "Template format changed - update render_version_sqf() before packing."
        )

    out_path = mission_dir / "version.sqf"
    out_path.write_text(text, encoding="utf-8")
    return out_path


def assert_version_sqf(mission_dir: Path) -> None:
    """Fail loudly if version.sqf is missing or malformed. This is the core fix: the historical
    packers never checked this and silently shipped PBOs without it."""
    version_path = mission_dir / "version.sqf"
    if not version_path.is_file():
        raise SystemExit(
            f"ABORT: {version_path} does not exist after render - refusing to pack. "
            "(This is the exact 2026-07-09 defect: a PBO built without version.sqf fails "
            "description.ext's/initJIPCompatible.sqf's #include \"version.sqf\" at mission load.)"
        )
    data = version_path.read_bytes()
    if len(data) == 0:
        raise SystemExit(f"ABORT: {version_path} is empty - refusing to pack.")
    text = data.decode("utf-8", errors="replace")
    if "WF_RELEASE_MARKER" not in text:
        raise SystemExit(f"ABORT: {version_path} has no WF_RELEASE_MARKER define - refusing to pack (malformed render).")
    if WF_DEBUG_LIVE_RE.search(text):
        raise SystemExit(f"ABORT: {version_path} has an ACTIVE WF_DEBUG define - refusing to pack a debug build.")


def collect_files(mission_dir: Path) -> list[tuple[str, bytes]]:
    files: list[tuple[str, bytes]] = []
    for root, _dirs, fnames in os.walk(mission_dir):
        for fn in fnames:
            if fn.lower().endswith(SKIP_SUFFIXES):
                continue
            full = Path(root) / fn
            rel = full.relative_to(mission_dir).as_posix().replace("/", "\\")
            files.append((rel, full.read_bytes()))
    files.sort(key=lambda item: item[0].lower())
    return files


def assert_version_sqf_in_files(files: list[tuple[str, bytes]]) -> None:
    """Belt-and-suspenders: re-check the walked file list itself contains version.sqf,
    independent of assert_version_sqf() above, in case a future refactor reorders steps."""
    for rel, data in files:
        if rel.lower().endswith("version.sqf"):
            if WF_DEBUG_LIVE_RE.search(data.decode("utf-8", errors="replace")):
                raise SystemExit("ABORT: ACTIVE WF_DEBUG in the version.sqf about to be packed - comment it before packing.")
            return
    raise SystemExit(
        "ABORT: version.sqf is not present in the walked file list - refusing to write a PBO "
        "that would fail to load. (render_version_sqf()/assert_version_sqf() should have caught "
        "this already; seeing this means the walk excluded it some other way.)"
    )


def az(value: str) -> bytes:
    return value.encode("latin-1") + b"\x00"


def build_pbo_bytes(prefix: str, files: list[tuple[str, bytes]]) -> bytes:
    header = bytearray()
    header += b"\x00" + struct.pack("<5I", 0x56657273, 0, 0, 0, 0)
    header += az("prefix") + az(prefix) + b"\x00"
    for path, data in files:
        header += az(path) + struct.pack("<5I", 0, len(data), 0, 0, len(data))
    header += b"\x00" + struct.pack("<5I", 0, 0, 0, 0, 0)
    body = bytes(header) + b"".join(data for _, data in files)
    return body + b"\x00" + hashlib.sha1(body).digest()


def selfcheck_pbo(out_path: Path) -> None:
    data = out_path.read_bytes()

    def read_asciiz(buf: bytes, offset: int) -> tuple[str, int]:
        end = buf.index(b"\x00", offset)
        return buf[offset:end].decode("latin-1"), end + 1

    offset = 0
    name, offset = read_asciiz(data, offset)
    if name != "" or struct.unpack_from("<5I", data, offset)[0] != 0x56657273:
        raise SystemExit(f"ABORT: self-check failed - {out_path} does not start with a valid PBO header.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mission-dir", required=True, type=Path, help="Mission source checkout to pack (must contain version.sqf.template).")
    parser.add_argument("--out", required=True, type=Path, help="Output PBO path.")
    parser.add_argument("--prefix", required=True, help="PBO internal mission-folder prefix, e.g. [61-2hc]warfarev2_073v48co_stresstest.zargabad")
    parser.add_argument("--candidate", required=True, help="Candidate/build marker stamped into WF_RELEASE_MARKER, e.g. stresstest-20260709")
    parser.add_argument("--git-sha", default=None, help="Git short SHA to stamp; auto-detected via git rev-parse if omitted.")
    parser.add_argument("--terrain", default=None, help="Terrain to stamp; auto-detected from the mission folder name if omitted.")
    args = parser.parse_args(argv)

    mission_dir = args.mission_dir.resolve()
    if not mission_dir.is_dir():
        parser.error(f"--mission-dir {mission_dir} is not a directory")

    git_sha = args.git_sha or detect_git_sha(mission_dir)
    terrain = args.terrain or detect_terrain(mission_dir)

    print(f"Mission dir: {mission_dir}")
    print(f"Candidate:   {args.candidate}")
    print(f"Git SHA:     {git_sha}")
    print(f"Terrain:     {terrain}")

    version_path = render_version_sqf(mission_dir, args.candidate, git_sha, terrain)
    print(f"Rendered:    {version_path}")
    assert_version_sqf(mission_dir)
    print("version.sqf assertion: OK")

    files = collect_files(mission_dir)
    print(f"Files:       {len(files)}")
    assert_version_sqf_in_files(files)
    print("version.sqf-in-package assertion: OK")

    out_path = args.out.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    pbo_bytes = build_pbo_bytes(args.prefix, files)
    out_path.write_bytes(pbo_bytes)
    print(f"Wrote:       {out_path} ({out_path.stat().st_size} bytes, prefix={args.prefix})")

    selfcheck_pbo(out_path)
    print("PBO header self-check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
