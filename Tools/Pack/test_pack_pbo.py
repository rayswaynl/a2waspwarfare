#!/usr/bin/env python3
"""Regression tests for pack_pbo.py / read_pbo.py.

Uses tiny synthetic mission folders (not the real ~900-file trees) so this
runs in well under a second. Run with:

    python Tools/Pack/test_pack_pbo.py
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
