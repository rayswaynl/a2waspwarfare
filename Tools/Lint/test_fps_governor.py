#!/usr/bin/env python3
"""Static contract for the default-off FPS-adaptive AI governor (fable/fps-governor).

Owner direction 2026-08-08: AI commander AI, town defenders and HQ teams should be limited per
side based on live server FPS, scaling to keep FPS high. This is a NEXT-WAVE feature (flag
WFBE_C_FPS_GOVERNOR, default 0) - every assertion below proves the flag-off path is inert (the new
code is present but textually unreachable at runtime) and that the three maintained mission roots
(Lint README scan scope: Chernarus source + the Takistan/Zargabad vanilla mirrors) carry the
identical addition, mirroring the AICAP_MIDHIGH_TRIM precedent's own footprint.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = {
    "chernarus": ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    "takistan": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    "zargabad": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
}

GOVERNOR_GATE = 'if ((missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR", 0]) > 0) then {'
MULTIPLIER_READ = 'missionNamespace getVariable ["WFBE_FpsGovMultiplier", 1]'


def code(mission: Path, relative: str) -> str:
    return mask_comments((mission / relative).read_text(encoding="utf-8-sig"))


class FpsGovernorTests(unittest.TestCase):
    def test_constants_declare_the_flag_off_and_the_neutral_multiplier_seed(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                constants = code(mission, "Common/Init/Init_CommonConstants.sqf")
                self.assertIn('if (isNil "WFBE_C_FPS_GOVERNOR") then {WFBE_C_FPS_GOVERNOR = 0};', constants)
                self.assertIn('if (isNil "WFBE_FpsGovMultiplier") then {WFBE_FpsGovMultiplier = 1};', constants)

    def test_governor_script_exists_and_the_flag_gate_is_the_first_statement(self) -> None:
        gate = 'if (!((missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR", 0]) > 0)) exitWith {};'
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                script_path = mission / "Server" / "AI" / "Server_FpsGovernor.sqf"
                self.assertTrue(script_path.is_file(), f"{script_path} must exist")
                script = mask_comments(script_path.read_text(encoding="utf-8-sig"))
                self.assertIn(gate, script)
                # Flag-off must be inert: nothing (comments/blank lines aside) may execute before
                # the gate - no singleton-var write, no isDedicated check, no loop.
                pre = script[: script.index(gate)].strip()
                self.assertEqual(pre, "", "the flag gate must precede every other statement")

    def test_init_server_launch_is_gated_on_the_same_flag(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                init_server = code(mission, "Server/Init/Init_Server.sqf")
                self.assertIn(
                    'if (isServer && {(missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR", 0]) > 0}) then {',
                    init_server,
                )
                self.assertIn('[] execVM "Server\\AI\\Server_FpsGovernor.sqf";', init_server)

    def test_all_five_consumer_sites_scale_inside_the_flag_gate(self) -> None:
        sites = {
            "Server/AI/Commander/AI_Commander_Produce.sqf":
                f"_cap = floor (_cap * ({MULTIPLIER_READ}))",
            "Server/AI/Commander/AI_Commander_Teams.sqf":
                f"_aiCapTier = floor (_aiCapTier * ({MULTIPLIER_READ}))",
            "Server/AI/Commander/AI_Commander_HCTopUp.sqf":
                f"_want = (round (_want * ({MULTIPLIER_READ}))) max _floor",
            "Server/Functions/Server_GetTownGroups.sqf":
                f"_groups_max = round (_groups_max * ({MULTIPLIER_READ}));",
            "Server/Functions/Server_GetTownGroupsDefender.sqf":
                f"_groups_max = round (_groups_max * ({MULTIPLIER_READ}));",
        }
        for name, mission in MISSIONS.items():
            for relative, expected in sites.items():
                with self.subTest(mission=name, file=relative):
                    text = code(mission, relative)
                    self.assertIn(GOVERNOR_GATE, text)
                    self.assertIn(expected, text)
                    # The scaling statement must sit INSIDE the gate's then{} block, not merely
                    # exist elsewhere in the file (proves flag-off truly skips it at runtime).
                    gate_at = text.index(GOVERNOR_GATE)
                    stmt_at = text.index(expected, gate_at)
                    self.assertGreater(stmt_at, gate_at)
                    self.assertLess(stmt_at - gate_at, 400, "scaling statement drifted far from its flag gate")

    def test_town_garrison_sites_floor_protect_groups_max(self) -> None:
        floor_clamp = (
            'if (_groups_max < (missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_TOWNS_FLOOR", 1])) '
            'then {_groups_max = missionNamespace getVariable ["WFBE_C_FPS_GOVERNOR_TOWNS_FLOOR", 1]};'
        )
        for name, mission in MISSIONS.items():
            for relative in (
                "Server/Functions/Server_GetTownGroups.sqf",
                "Server/Functions/Server_GetTownGroupsDefender.sqf",
            ):
                with self.subTest(mission=name, file=relative):
                    text = code(mission, relative)
                    self.assertIn(floor_clamp, text)

    def test_mirrors_all_carry_the_gate_and_the_new_script_is_byte_identical(self) -> None:
        """The three maintained mission roots (Chernarus source + Takistan/Zargabad vanilla
        mirrors - Lint README scan scope) must all carry the addition; Modded_Missions and
        Tools/PerfTest are outside that maintained set and were deliberately not touched, matching
        the WFBE_C_AICAP_MIDHIGH_TRIM precedent's own footprint."""
        relatives = [
            "Common/Init/Init_CommonConstants.sqf",
            "Server/Init/Init_Server.sqf",
            "Server/AI/Commander/AI_Commander_Produce.sqf",
            "Server/AI/Commander/AI_Commander_Teams.sqf",
            "Server/AI/Commander/AI_Commander_HCTopUp.sqf",
            "Server/Functions/Server_GetTownGroups.sqf",
            "Server/Functions/Server_GetTownGroupsDefender.sqf",
        ]
        for relative in relatives:
            for name, mission in MISSIONS.items():
                with self.subTest(file=relative, mission=name):
                    text = (mission / relative).read_text(encoding="utf-8-sig")
                    self.assertIn("WFBE_C_FPS_GOVERNOR", text, f"{relative} missing the governor gate on {name}")

        script_bodies = {
            name: (mission / "Server" / "AI" / "Server_FpsGovernor.sqf").read_bytes()
            for name, mission in MISSIONS.items()
        }
        first_name, first_body = next(iter(script_bodies.items()))
        for name, body in script_bodies.items():
            self.assertEqual(body, first_body, f"Server_FpsGovernor.sqf differs between {first_name} and {name}")


if __name__ == "__main__":
    unittest.main()
