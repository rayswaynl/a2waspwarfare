#!/usr/bin/env python3
"""Contract for the VEHDEL reason-coded deletion probe (fable/veh-delete-probe).

Required by the independent review of wasp-vehicle-crew-fast-despawn-20260719:
every scripted cleanup deletion of a hull/crewed unit must emit one structured
line binding the deletion to its source, locality, crew composition,
nearest-player distance, and player-use/exit stamps - so the live incident can
be attributed deterministically instead of by leading-candidate reasoning.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"

# Every cleanup deleteVehicle site and the reason code its probe call must carry.
PROBED_SITES = {
    "Server/FSM/server_town_ai.sqf": ["town-sweep-unit", "town-sweep-hull"],
    "Client/Functions/Client_CleanupDelegatedTownAI.sqf": ["hc-townai-cleanup-unit"],
    "Client/Functions/Client_DelegateTownAI.sqf": ["hc-townai-watch-unit"],
    "Common/Functions/Common_RunCommanderTeam.sqf": ["aicom-retire-unit", "aicom-retire-hull"],
    "Server/AI/Commander/AI_Commander_Produce.sqf": ["produce-cull-unit"],
    "Server/Functions/Server_HandleEmptyVehicle.sqf": ["empty-timeout-hull"],
}


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class VehDeleteProbeTests(unittest.TestCase):
    def test_probe_function_captures_the_required_fields(self) -> None:
        text = code("Common/Functions/Common_LogVehDelete.sqf")
        for token in (
            "WFBE_C_VEH_DELETE_PROBE",
            "nearPlayerM",
            "lastPlayerUse",
            "lastPlayerExit",
            "local _veh",
            "crew _veh",
            "VEHDEL|v1|reason=",
        ):
            self.assertIn(token, text)

    def test_every_cleanup_site_calls_the_probe_with_its_reason(self) -> None:
        for relative, reasons in PROBED_SITES.items():
            text = code(relative)
            for reason in reasons:
                self.assertIn(f'"{reason}"', text, f"{relative}: missing probe reason {reason}")
                self.assertIn("WFBE_CO_FNC_LogVehDelete", text, relative)

    def test_probe_precedes_the_delete_at_each_site(self) -> None:
        # The probe must run BEFORE deleteVehicle (a deleted object logs nothing useful).
        for relative, reasons in PROBED_SITES.items():
            text = code(relative)
            for reason in reasons:
                idx = text.index(f'"{reason}"')
                self.assertIn("deleteVehicle", text[idx : idx + 260], f"{relative}: {reason} not adjacent to its delete")

    def test_player_use_stamps_are_written_at_the_factory(self) -> None:
        text = code("Common/Functions/Common_CreateVehicle.sqf")
        self.assertIn('"GetIn"', text)
        self.assertIn('"GetOut"', text)
        self.assertIn("wfbe_player_used", text)
        self.assertIn("wfbe_player_exit", text)

    def test_probe_is_registered_and_kill_switch_declared(self) -> None:
        self.assertIn("Common_LogVehDelete.sqf", code("Common/Init/Init_Common.sqf"))
        self.assertIn(
            'if (isNil "WFBE_C_VEH_DELETE_PROBE") then {WFBE_C_VEH_DELETE_PROBE = 1}',
            code("Common/Init/Init_CommonConstants.sqf"),
        )


if __name__ == "__main__":
    unittest.main()
