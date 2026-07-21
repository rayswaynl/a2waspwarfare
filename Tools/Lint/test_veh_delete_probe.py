#!/usr/bin/env python3
"""Contract for the VEHDEL reason-coded deletion probe (fable/veh-delete-probe, round 2).

Round-2 review required an EXHAUSTIVE, MECHANICALLY CHECKED relevant-delete inventory
instead of a curated site list. Two mechanisms provide it:

1. RATCHET MANIFEST (vehdel_inventory.json): every .sqf file in the Chernarus mission
   containing the token `deleteVehicle` is listed with its occurrence count (comment
   mentions included) and its probe-call count. ANY new, moved, or removed deleteVehicle
   anywhere in the tree fails this test until the manifest is deliberately regenerated
   and re-reviewed - nothing changes unnoticed.
2. FULL ADJACENCY in cleanup files: in every file that carries probes, EVERY non-comment
   deleteVehicle statement must have its probe call on the same line or the line above.
   There is no curated subset left to argue about.

Probe policy (round-2): default 0 per repo feature-default policy; playableUnits scan
(cost bound); GetIn stamps role + UID (driver-aware attribution).
"""

import json
import re
from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MANIFEST = Path(__file__).resolve().parent / "vehdel_inventory.json"


def raw(relative: str) -> str:
    return (MISSION / relative).read_text(encoding="utf-8-sig")


class VehDeleteProbeTests(unittest.TestCase):
    def test_probe_function_captures_the_required_fields(self) -> None:
        text = mask_comments(raw("Common/Functions/Common_LogVehDelete.sqf"))
        for token in (
            'WFBE_C_VEH_DELETE_PROBE", 0]',   # round-2: default OFF
            "nearPlayerM",
            "lastPlayerUse",
            "lastPlayerExit",
            "useRole=",
            "useUid=",
            "local _veh",
            "crew _veh",
            "forEach playableUnits",           # round-2: bounded scan, not allUnits
            "VEHDEL|v1|reason=",
        ):
            self.assertIn(token, text)
        self.assertNotIn("forEach allUnits", text)

    def test_ratchet_manifest_matches_the_entire_tree(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
        actual = {}
        for path in sorted(MISSION.rglob("*.sqf")):
            text = path.read_text(encoding="utf-8-sig", errors="replace")
            total = text.count("deleteVehicle")
            if total:
                rel = path.relative_to(MISSION).as_posix()
                actual[rel] = {"total": total, "probed": text.count("WFBE_CO_FNC_LogVehDelete")}
        self.assertEqual(actual, manifest,
                         "deleteVehicle inventory drifted - reclassify and regenerate vehdel_inventory.json deliberately")

    def test_every_code_delete_in_probed_files_is_probe_adjacent(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
        probed_files = [p for p, c in manifest.items() if c["probed"] > 0]
        self.assertGreaterEqual(len(probed_files), 10)
        for rel in probed_files:
            lines = raw(rel).splitlines()
            for i, line in enumerate(lines):
                stripped = line.strip()
                if "deleteVehicle" not in stripped or stripped.startswith("//"):
                    continue
                if re.match(r"^deleteVehicle\b", stripped) or " deleteVehicle" in stripped or "{deleteVehicle" in stripped:
                    prev = lines[i - 1] if i else ""
                    self.assertTrue(
                        "WFBE_CO_FNC_LogVehDelete" in line or "WFBE_CO_FNC_LogVehDelete" in prev,
                        f"{rel}:{i + 1}: code deleteVehicle without adjacent probe",
                    )

    def test_player_use_stamps_are_role_and_identity_aware(self) -> None:
        text = mask_comments(raw("Common/Functions/Common_CreateVehicle.sqf"))
        self.assertIn('"GetIn"', text)
        self.assertIn('"GetOut"', text)
        self.assertIn("wfbe_player_used_role", text)
        self.assertIn("wfbe_player_used_uid", text)
        self.assertIn('WFBE_C_VEH_DELETE_PROBE", 0]', text)  # default OFF here too

    def test_probe_is_registered_and_armed(self) -> None:
        """wave0721 arming ruling (2026-07-21): WFBE_C_VEH_DELETE_PROBE flipped 0->1."""
        self.assertIn("Common_LogVehDelete.sqf", mask_comments(raw("Common/Init/Init_Common.sqf")))
        self.assertIn(
            'if (isNil "WFBE_C_VEH_DELETE_PROBE") then {WFBE_C_VEH_DELETE_PROBE = 1}',
            mask_comments(raw("Common/Init/Init_CommonConstants.sqf")),
        )


if __name__ == "__main__":
    unittest.main()
