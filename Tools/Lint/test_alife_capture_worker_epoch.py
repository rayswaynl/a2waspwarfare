"""Regression contracts for repeated-capture worker generation guards."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_CAPTURE = Path("Server") / "FSM" / "server_town.sqf"


class CaptureWorkerEpochTests(unittest.TestCase):
    def test_defender_linger_is_bound_to_the_capture_epoch(self) -> None:
        for mission in MISSIONS:
            source = (mission / TOWN_CAPTURE).read_text(encoding="utf-8-sig")
            start = source.index("//--- Task 32: old defenders linger")
            end = source.index("//--- FINAL spec", start)
            worker = source[start:end]

            self.assertIn(
                '[_location, _side, _newSID, _captureEpoch] spawn {',
                worker,
            )
            self.assertRegex(worker, r"_captureEpoch\s*=\s*_this select 3;")
            self.assertIn(
                'if ((_loc getVariable ["wfbe_town_ai_epoch", -1]) != _captureEpoch) exitWith {};',
                worker,
            )

    def test_mopup_worker_is_bound_to_the_capture_epoch(self) -> None:
        for mission in MISSIONS:
            source = (mission / TOWN_CAPTURE).read_text(encoding="utf-8-sig")
            start = source.index("if (_town_occupation_enabled) then {")
            end = source.index("//--- Task 12: Airfield capture", start)
            worker = source[start:end]

            self.assertIn(
                '_captureEpoch = _location getVariable ["wfbe_town_ai_epoch", 0];',
                source,
            )
            self.assertIn(
                '[_location, _newSide, _newSID, _captureEpoch] spawn {',
                worker,
            )
            self.assertIn(
                'if ((_loc getVariable ["wfbe_town_ai_epoch", -1]) != _captureEpoch) exitWith {};',
                worker,
            )
            self.assertIn(
                'if ((_loc getVariable ["wfbe_town_ai_epoch", -1]) != _captureEpoch) then {_scanActive = false};',
                worker,
            )

    def test_stale_mopup_cleanup_cannot_clear_a_newer_reference(self) -> None:
        for mission in MISSIONS:
            source = (mission / TOWN_CAPTURE).read_text(encoding="utf-8-sig")
            start = source.index("if (_town_occupation_enabled) then {")
            end = source.index("//--- Task 12: Airfield capture", start)
            worker = source[start:end]

            self.assertIn(
                'if ((_loc getVariable ["wfbe_mopup_group", grpNull]) == _squadGrp) then {',
                worker,
            )


if __name__ == "__main__":
    unittest.main()
