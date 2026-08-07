#!/usr/bin/env python3
"""Round-trip proof for `cprs.py` (BIS Cprs LZSS codec).

Run with:

    python Tools/Pack/test_cprs.py

or via pytest (this repo's convention):

    python -m pytest Tools/Pack -q

Requirement (see task spec): every real text file in
`Missions/[55-2hc]warfarev2_073v48co.chernarus` must round-trip
byte-identical through `compress()` -> `decompress()`, with the trailing
checksum verifying, before any measurement or `read_pbo.py` integration is
trusted. `test_all_real_mission_text_files_round_trip` below asserts this
for every single one of them and reports the exact count.
"""

from __future__ import annotations

import os
import random
import unittest
from pathlib import Path

import cprs

REPO_ROOT = Path(__file__).resolve().parents[2]
MISSION_DIR = REPO_ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"

# Matches the task spec's own definition of "the text corpus": these are the
# extensions the 8.85 MB / 3.32x zlib-proxy figure was computed over.
TEXT_SUFFIXES = (".sqf", ".hpp", ".ext", ".sqm", ".fsm", ".html", ".bikb", ".xml")


def _collect_mission_text_files() -> list[Path]:
    if not MISSION_DIR.is_dir():
        return []
    out = []
    for root, _dirs, fnames in os.walk(MISSION_DIR):
        for fn in fnames:
            if fn.lower().endswith(TEXT_SUFFIXES):
                out.append(Path(root) / fn)
    return sorted(out)


class CprsRoundTripTests(unittest.TestCase):
    def _assert_round_trip(self, data: bytes, label: str) -> None:
        comp = cprs.compress(data)
        # compressed stream must always end with a verifiable 4-byte checksum
        self.assertGreaterEqual(len(comp), 4, f"{label}: compressed stream too short")
        back = cprs.decompress(comp, len(data))
        self.assertEqual(back, data, f"{label}: round-trip byte mismatch")

    def test_empty_input(self) -> None:
        self._assert_round_trip(b"", "empty")

    def test_one_byte(self) -> None:
        for b in (0x00, 0x20, 0xFF, 0x41):
            self._assert_round_trip(bytes([b]), f"1 byte 0x{b:02x}")

    def test_two_and_three_bytes(self) -> None:
        self._assert_round_trip(b"AB", "2 bytes")
        self._assert_round_trip(b"AAA", "3 bytes (exactly MIN_MATCH)")
        self._assert_round_trip(b"ABC", "3 distinct bytes")

    def test_random_bytes_various_sizes(self) -> None:
        rng = random.Random(20260805)
        for size in (1, 2, 3, 17, 18, 19, 100, 999, 1000, 1001, 4095, 4096, 4097, 65536):
            data = bytes(rng.getrandbits(8) for _ in range(size))
            self._assert_round_trip(data, f"random {size} bytes")

    def test_highly_repetitive_bytes(self) -> None:
        self._assert_round_trip(b"X" * 100000, "100000x 'X'")
        self._assert_round_trip(b"\x00" * 100000, "100000x 0x00")
        self._assert_round_trip(b"ABCDEFGH" * 20000, "repeating 8-byte pattern x20000")

    def test_leading_space_run_exercises_prefill_region(self) -> None:
        # Exercises the ring buffer's space pre-fill zone directly: matches
        # near the start of a file that legitimately begins with spaces.
        self._assert_round_trip(b" " * 5000 + b"real content follows" * 50, "leading spaces")

    def test_window_boundary_sizes(self) -> None:
        rng = random.Random(7)
        for size in (4095, 4096, 4097, 8192, 8193):
            data = bytes(rng.getrandbits(8) for _ in range(size))
            self._assert_round_trip(data, f"window-boundary {size} bytes")

    def test_checksum_detects_corruption(self) -> None:
        data = b"hello world" * 200
        comp = bytearray(cprs.compress(data))
        comp[-1] ^= 0xFF  # flip a bit in the trailing checksum
        with self.assertRaises(cprs.CprsError):
            cprs.decompress(bytes(comp), len(data))

    def test_all_real_mission_text_files_round_trip(self) -> None:
        files = _collect_mission_text_files()
        self.assertGreater(
            len(files),
            0,
            f"no text files found under {MISSION_DIR} - mission tree missing or "
            "extension list stale",
        )
        failures: list[str] = []
        total_bytes = 0
        for path in files:
            data = path.read_bytes()
            total_bytes += len(data)
            try:
                comp = cprs.compress(data)
                back = cprs.decompress(comp, len(data))
                if back != data:
                    failures.append(f"{path}: byte mismatch after round-trip")
            except cprs.CprsError as exc:
                failures.append(f"{path}: {exc}")

        if failures:
            preview = "\n".join(failures[:20])
            self.fail(
                f"{len(failures)}/{len(files)} real mission text files failed "
                f"round-trip:\n{preview}"
            )

        # Exact count report, per task spec item 3.
        print(
            f"\ncprs round-trip: {len(files)}/{len(files)} real mission text "
            f"files passed ({total_bytes:,} bytes total)."
        )


if __name__ == "__main__":
    unittest.main()
