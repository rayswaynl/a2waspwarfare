#!/usr/bin/env python3
"""Regression tests for pack_pbo.py / read_pbo.py.

Uses tiny synthetic mission folders (not the real ~900-file trees) so this
runs in well under a second. Run with:

    python Tools/Pack/test_pack_pbo.py
"""

from __future__ import annotations

import shutil
import struct
import tempfile
import unittest
from pathlib import Path

import cprs
import pack_pbo
import read_pbo


def make_mission(root: Path, extra_files: dict[str, bytes] | None = None) -> Path:
    mission = root / "[55-2hc]warfarev2_073v48co.chernarus"
    mission.mkdir(parents=True)
    (mission / "mission.sqm").write_bytes(b"dummy sqm content\r\n")
    (mission / "version.sqf.template").write_bytes(
        b"// #define WF_DEBUG 1\n#define WF_MISSIONNAME \"test\"\n"
    )
    sub = mission / "Common" / "Functions"
    sub.mkdir(parents=True)
    (sub / "Common_Thing.sqf").write_bytes(b"hint 'hi';\r\n")
    if extra_files:
        for rel, data in extra_files.items():
            p = mission / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
    return mission


def write_slot_layout(mission: Path, max_players: int) -> None:
    (mission / "version.sqf").write_bytes(
        f"#define WF_MAXPLAYERS {max_players}\n".encode("ascii")
    )
    (mission / "mission.sqm").write_bytes(
        b'''class Mission\n{
    class Groups\n    {\n        class Item0 { class Vehicles { class Item0 {\n            player="PLAY CDG";\n        }; }; };\n        class Item1 { class Vehicles { class Item0 {\n            player="PLAY CDG";\n            forceHeadlessClient=1;\n        }; }; };\n        class Item2 { class Vehicles { class Item0 {\n            player="PLAY CDG";\n            init="this setVariable [""wfbe_caster_slot"", true];";\n        }; }; };\n        class Item3 { class Vehicles { class Item0 {\n            player="PLAY CDG";\n        }; }; };\n    };\n};\n'''
    )


class PackPboTests(unittest.TestCase):
    def test_slot_census_ignores_comments_and_quoted_fake_slots(self) -> None:
        mission_sqm = b'''class Mission
{
    /*
        player="COMMENTED";
    */
    class Item0 { class Vehicles { class Item0 {
        player="REAL";
        init="this setVariable [""wfbe_caster_slot"", true]; { player=""FAKE""; }";
    }; }; };
};
'''
        self.assertEqual(pack_pbo._slot_capacity(mission_sqm), (1, 0, 1))

    def test_slot_census_recognizes_headless_by_description_without_flag(self) -> None:
        # fix0807b: forceHeadlessClient is no longer written to the two CIV magnet
        # slots (proven inert/harmful for A2 OA 1.64 -client auto-seat). The census
        # must still classify them as headless via the description text alone.
        mission_sqm = b'''class Mission
{
    class Item0 { class Vehicles { class Item0 {
        player="PLAY CDG";
        description="Headless Client 1";
    }; }; };
    class Item1 { class Vehicles { class Item0 {
        player="PLAY CDG";
        description="Headless Client 2";
    }; }; };
    class Item2 { class Vehicles { class Item0 {
        player="PLAY CDG";
    }; }; };
};
'''
        self.assertEqual(pack_pbo._slot_capacity(mission_sqm), (3, 2, 0))

    def test_stale_maxplayers_rejected_after_reserved_slots_are_excluded(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            write_slot_layout(mission, 55)
            out = root / "out.pbo"
            with self.assertRaisesRegex(pack_pbo.PackError, r"WF_MAXPLAYERS=55"):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=True,
                    force=False,
                    quiet=True,
                )

    def test_reserved_hc_and_caster_slots_do_not_reduce_human_capacity(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            write_slot_layout(mission, 2)
            out = root / "out.pbo"
            pack_pbo.pack(
                source=mission,
                output=out,
                prefix=None,
                build_tag=None,
                allow_debug=False,
                strict_version=True,
                force=False,
                quiet=True,
            )
            self.assertTrue(out.exists())

    def test_round_trip_synthesizes_version_from_template(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            out = root / "out.pbo"
            pack_pbo.pack(
                source=mission,
                output=out,
                prefix=None,
                build_tag="unittest",
                allow_debug=False,
                strict_version=False,
                force=False,
                quiet=True,
            )
            buf = out.read_bytes()
            properties, entries, data_start, data_end, trailer = read_pbo.parse_pbo(buf)
            self.assertEqual(
                properties["prefix"],
                "[55-2hc]warfarev2_073v48co_unittest.chernarus",
            )
            # mission.sqm + version.sqf.template->excluded + version.sqf(synth) + Common\Functions\Common_Thing.sqf
            names = sorted(n for n, *_ in entries)
            self.assertEqual(
                names,
                ["common\\functions\\common_thing.sqf", "mission.sqm", "version.sqf"],
            )
            self.assertTrue(read_pbo.verify_checksum(buf, data_end, trailer))

    def test_strict_version_without_real_file_aborts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            out = root / "out.pbo"
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=True,
                    force=False,
                    quiet=True,
                )

    def test_no_version_sqf_and_no_template_aborts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            (mission / "version.sqf.template").unlink()
            out = root / "out.pbo"
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=False,
                    force=False,
                    quiet=True,
                )

    def test_active_debug_define_aborts_unless_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(
                root, extra_files={"version.sqf": b"#define WF_DEBUG 1\n"}
            )
            out = root / "out.pbo"
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=False,
                    force=False,
                    quiet=True,
                )
            # should succeed with --allow-debug
            pack_pbo.pack(
                source=mission,
                output=out,
                prefix=None,
                build_tag=None,
                allow_debug=True,
                strict_version=False,
                force=True,
                quiet=True,
            )
            self.assertTrue(out.exists())

    def test_lowercase_collision_aborts(self) -> None:
        # NTFS is case-insensitive, so two source files differing only by case
        # cannot coexist on a Windows disk (writing "dup.sqf" after "Dup.sqf"
        # just overwrites the same file) - exercise the guard function
        # directly with a synthetic pre-collected list instead, simulating a
        # source drawn from a case-sensitive filesystem or an archive.
        with self.assertRaises(pack_pbo.PackError):
            pack_pbo.check_lowercase_collisions(
                [("dup.sqf", b"a"), ("dup.sqf", b"b")]
            )
        # sanity: no collision, no error
        pack_pbo.check_lowercase_collisions([("a.sqf", b"a"), ("b.sqf", b"b")])

    def test_no_init_sqf_packs_fine(self) -> None:
        # make_mission() ships no init.sqf by default, matching the proven-live
        # mission tree (wave0720b extraction: 938 entries, no init.sqf, only
        # initjipcompatible.sqf) - this is the "guard passes" half of the
        # both-ways proof.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            out = root / "out.pbo"
            pack_pbo.pack(
                source=mission,
                output=out,
                prefix=None,
                build_tag=None,
                allow_debug=False,
                strict_version=False,
                force=False,
                quiet=True,
            )
            self.assertTrue(out.exists())

    def test_init_sqf_selftest_stub_contamination_aborts(self) -> None:
        # release-critical guard (wave0721, council finding C4): reproduce the
        # exact stray local-test-harness stub found on real dev boxes - must
        # abort, not silently pack a mission that never boots the real game.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            (mission / "init.sqf").write_bytes(
                b"//--- LOCAL TESTING ONLY: spawn the WASP self-test/observer harness.\r\n"
                b"if (isServer) then {\r\n"
                b'    [] execVM "test\\wasp_selftest.sqf";\r\n'
                b"};\r\n"
            )
            out = root / "out.pbo"
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=False,
                    force=False,
                    quiet=True,
                )

    def test_init_sqf_delegating_shim_contamination_aborts(self) -> None:
        # a "helpful" delegating shim is ALSO contamination, not just the
        # self-test stub: the live tree has no init.sqf at all, so anything
        # named init.sqf would double-execute initJIPCompatible.sqf's 414-line
        # bootstrap (duplicate PV handler registrations, doubled loops, etc.)
        # on top of the engine's own native run of it. Any content aborts.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            (mission / "init.sqf").write_bytes(
                b'execVM "initJIPCompatible.sqf";\r\n'
            )
            out = root / "out.pbo"
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=False,
                    force=False,
                    quiet=True,
                )

    def test_refuses_to_overwrite_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(root)
            out = root / "out.pbo"
            out.write_bytes(b"existing")
            with self.assertRaises(pack_pbo.PackError):
                pack_pbo.pack(
                    source=mission,
                    output=out,
                    prefix=None,
                    build_tag=None,
                    allow_debug=False,
                    strict_version=False,
                    force=False,
                    quiet=True,
                )

    def test_diff_source_byte_identical_with_real_version_sqf(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(
                root, extra_files={"version.sqf": b"#define WF_MISSIONNAME \"x\"\n"}
            )
            out = root / "out.pbo"
            pack_pbo.pack(
                source=mission,
                output=out,
                prefix=None,
                build_tag=None,
                allow_debug=False,
                strict_version=True,
                force=False,
                quiet=True,
            )
            buf = out.read_bytes()
            properties, entries, data_start, data_end, trailer = read_pbo.parse_pbo(buf)
            data, notes = read_pbo.extract_entry_data(buf, entries, data_start)
            self.assertEqual(notes, [])
            source_map = {}
            for f in mission.rglob("*"):
                if f.is_file() and not f.name.endswith(".template"):
                    rel = str(f.relative_to(mission)).replace("/", "\\").lower()
                    source_map[rel] = f
            self.assertEqual(set(data.keys()), set(source_map.keys()))
            for name, blob in data.items():
                self.assertEqual(blob, source_map[name].read_bytes())


class PackPboCompressionTests(unittest.TestCase):
    """Cprs compression (--compress) round-trip coverage. Default (compress=False)
    behaviour is already covered by every test above unmodified - these
    exercise the opt-in compress=True path specifically."""

    def _packed_mission(
        self, extra_files: dict[str, bytes], compress: bool
    ) -> tuple[Path, Path, dict]:
        # NOTE: deliberately NOT a `with tempfile.TemporaryDirectory()` block -
        # callers need `mission` to stay on disk (for rglob-based diffing)
        # after this returns. Cleaned up via addCleanup instead.
        tmp = tempfile.mkdtemp(prefix="wasp_pack_cprs_test_")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        root = Path(tmp)
        mission = make_mission(
            root,
            extra_files={
                "version.sqf": b"#define WF_MISSIONNAME \"x\"\n",
                **extra_files,
            },
        )
        out = root / "out.pbo"
        pack_pbo.pack(
            source=mission,
            output=out,
            prefix=None,
            build_tag=None,
            allow_debug=False,
            strict_version=True,
            force=False,
            quiet=True,
            compress=compress,
        )
        buf = out.read_bytes()
        properties, entries, data_start, data_end, trailer = read_pbo.parse_pbo(buf)
        return mission, out, {
            "buf": buf,
            "entries": entries,
            "data_start": data_start,
            "data_end": data_end,
            "trailer": trailer,
        }

    def test_compress_tags_large_text_entry_as_cprs_and_shrinks_it(self) -> None:
        # Above REAL_LZSS_MIN_SIZE (1024) and highly compressible, so this MUST
        # be picked up by the >=1024-byte + TEXT_COMPRESS_SUFFIXES gate.
        big_sqf = (b"hint 'the quick brown fox jumps over the lazy dog';\r\n" * 60)
        self.assertGreaterEqual(len(big_sqf), 1024)
        mission, out, parsed = self._packed_mission(
            {"common\\functions\\common_big.sqf": big_sqf}, compress=True
        )
        entry = next(
            e for e in parsed["entries"] if e[0] == "common\\functions\\common_big.sqf"
        )
        nm, mi, osz, _rv, _ts, ds = entry
        self.assertEqual(mi, cprs.MAGIC_CPRS, "large repetitive .sqf must be Cprs-tagged")
        self.assertEqual(osz, len(big_sqf))
        self.assertLess(ds, osz, "compressed data_size must be smaller than original_size")

    def test_compress_round_trips_byte_identical_via_read_pbo(self) -> None:
        # The independent reader (read_pbo.py, a from-scratch second parser)
        # must decompress every Cprs entry back to byte-identical source data -
        # this is the "prove it offline HARD" round-trip gate for --compress.
        big_sqf = (b"hint 'the quick brown fox jumps over the lazy dog';\r\n" * 60)
        big_hpp = (b"class CfgSomething { value = 1; };\r\n" * 60)
        mission, out, parsed = self._packed_mission(
            {
                "common\\functions\\common_big.sqf": big_sqf,
                "rsc\\big_defines.hpp": big_hpp,
            },
            compress=True,
        )
        data, notes = read_pbo.extract_entry_data(
            parsed["buf"], parsed["entries"], parsed["data_start"]
        )
        self.assertTrue(
            any("common_big.sqf" in n and "decompressed" in n for n in notes)
        )
        self.assertTrue(
            any("big_defines.hpp" in n and "decompressed" in n for n in notes)
        )
        source_map = {}
        for f in mission.rglob("*"):
            if f.is_file() and not f.name.endswith(".template"):
                rel = str(f.relative_to(mission)).replace("/", "\\").lower()
                source_map[rel] = f
        self.assertEqual(set(data.keys()), set(source_map.keys()))
        for name, blob in data.items():
            self.assertEqual(
                blob, source_map[name].read_bytes(), f"{name} not byte-identical after Cprs round-trip"
            )
        self.assertTrue(
            read_pbo.verify_checksum(parsed["buf"], parsed["data_end"], parsed["trailer"])
        )

    def test_compress_never_touches_entries_below_threshold(self) -> None:
        # make_mission()'s own Common_Thing.sqf is 12 bytes - far under
        # REAL_LZSS_MIN_SIZE (1024). Even with --compress it must stay
        # mimetype=0, matching the real BIS packer/reader convention.
        mission, out, parsed = self._packed_mission({}, compress=True)
        entry = next(
            e for e in parsed["entries"] if e[0] == "common\\functions\\common_thing.sqf"
        )
        nm, mi, osz, _rv, _ts, ds = entry
        self.assertEqual(mi, 0, "sub-threshold entry must never be Cprs-tagged")
        self.assertEqual(osz, ds)

    def test_compress_never_touches_non_text_suffixes(self) -> None:
        # A large binary-ish extension outside TEXT_COMPRESS_SUFFIXES (e.g. a
        # stand-in for .paa/.ogg) must stay uncompressed even though it is
        # well above the size threshold and highly compressible.
        big_blob = b"\x00" * 4096
        mission, out, parsed = self._packed_mission(
            {"textures\\big.paa": big_blob}, compress=True
        )
        entry = next(e for e in parsed["entries"] if e[0] == "textures\\big.paa")
        nm, mi, osz, _rv, _ts, ds = entry
        self.assertEqual(mi, 0, ".paa (not in TEXT_COMPRESS_SUFFIXES) must never be Cprs-tagged")

    def test_compress_false_is_byte_identical_to_omitting_the_flag(self) -> None:
        # compress=False (the explicit default) must produce byte-for-byte the
        # same PBO as never having added the parameter at all.
        big_sqf = (b"hint 'the quick brown fox jumps over the lazy dog';\r\n" * 60)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mission = make_mission(
                root,
                extra_files={
                    "version.sqf": b"#define WF_MISSIONNAME \"x\"\n",
                    "common\\functions\\common_big.sqf": big_sqf,
                },
            )
            files = pack_pbo.collect_files(mission)
            files.sort(key=lambda x: x[0])
            prefix = pack_pbo.derive_prefix(mission.name, None)
            default_bytes = pack_pbo.build_pbo_bytes(files, prefix)
            explicit_false_bytes = pack_pbo.build_pbo_bytes(files, prefix, compress=False)
            self.assertEqual(default_bytes, explicit_false_bytes)
            # And every entry is mimetype 0 - compress=True is required to see Cprs at all.
            mimetypes = {
                e[1] for e in read_pbo.parse_pbo(default_bytes)[1]
            }
            self.assertEqual(mimetypes, {0})

    def test_self_check_rejects_cprs_entry_below_threshold(self) -> None:
        # Synthesize a malformed PBO that tags a tiny entry as Cprs (something
        # this writer's own compress_entries() would never do, but a future
        # bug could) and confirm self_check() catches it rather than shipping
        # a build no real engine would decode correctly.
        tiny = b"hi"
        comp = cprs.compress(tiny)
        hdr = bytearray()
        hdr += b"\x00" + pack_pbo.STRUCT5I.pack(pack_pbo.MAGIC_VERS, 0, 0, 0, 0)
        hdr += pack_pbo.az("prefix") + pack_pbo.az("test") + b"\x00"
        hdr += pack_pbo.az("tiny.sqf") + pack_pbo.STRUCT5I.pack(
            cprs.MAGIC_CPRS, len(tiny), 0, 0, len(comp)
        )
        hdr += b"\x00" + pack_pbo.STRUCT5I.pack(0, 0, 0, 0, 0)
        import hashlib

        body = bytes(hdr) + comp
        checksum = hashlib.sha1(body).digest()
        pbo_bytes = body + b"\x00" + checksum
        with self.assertRaisesRegex(pack_pbo.PackError, "below.*threshold|threshold"):
            pack_pbo.self_check(pbo_bytes, expected_entry_count=1)

    def test_self_check_rejects_corrupt_cprs_entry(self) -> None:
        # Flip a byte in a compressed entry's payload after packing and
        # confirm self_check() (re-run against the tampered bytes) trips the
        # checksum/decompress-failure path instead of silently accepting it.
        big_sqf = (b"hint 'the quick brown fox jumps over the lazy dog';\r\n" * 60)
        mission, out, parsed = self._packed_mission(
            {"common\\functions\\common_big.sqf": big_sqf}, compress=True
        )
        buf = bytearray(parsed["buf"])
        # Corrupt a byte inside the compressed data region (well after the
        # header/table, inside the concatenated entry bytes).
        corrupt_at = parsed["data_start"] + 5
        buf[corrupt_at] ^= 0xFF
        with self.assertRaises(pack_pbo.PackError):
            pack_pbo.self_check(bytes(buf), expected_entry_count=len(parsed["entries"]))


if __name__ == "__main__":
    unittest.main()
