from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
CHERNARUS = MISSIONS[0]
WILDCARD = CHERNARUS / "Server" / "Functions" / "AI_Commander_Wildcard.sqf"
READY = CHERNARUS / "Server" / "PVFunctions" / "AttackWave.sqf"
RECEIVER = CHERNARUS / "Client" / "PVFunctions" / "WildcardMarker.sqf"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


class AicomWildcardJipTests(unittest.TestCase):
    def test_producer_records_the_full_payload_before_broadcast(self) -> None:
        source = read(WILDCARD)

        self.assertIn(
            'missionNamespace getVariable ["WFBE_AICOM_WILDCARD_ACTIVE", []]',
            source,
        )
        self.assertIn("_mkExpiry = time + _mkLife;", source)
        self.assertIn(
            "[_side, _mkName, _mkPos, _mkColor, _mkType, _wName, _wDesc, _mkExpiry]",
            source,
        )
        ledger_writes = source.count(
            'missionNamespace setVariable ["WFBE_AICOM_WILDCARD_ACTIVE"'
        )
        self.assertGreaterEqual(ledger_writes, 2)
        self.assertLess(
            source.index('missionNamespace setVariable ["WFBE_AICOM_WILDCARD_ACTIVE"'),
            source.index('[_side, "WildcardMarker", ["create"'),
        )

    def test_expiry_worker_removes_only_its_side_and_name(self) -> None:
        source = read(WILDCARD)

        self.assertIn(
            'private ["_s","_n","_lf","_active","_kept"]',
            source,
        )
        self.assertIn(
            'if ((_x select 0) != _s || {(_x select 1) != _n}) then {_kept = _kept + [_x]};',
            source,
        )
        self.assertIn(
            'missionNamespace setVariable ["WFBE_AICOM_WILDCARD_ACTIVE", _kept];',
            source,
        )

    def test_ready_handler_replays_only_unexpired_same_side_markers(self) -> None:
        source = read(READY)

        self.assertIn('"CLIENT_INIT_READY" addPublicVariableEventHandler', source)
        self.assertIn(
            '_wildReplay = + (missionNamespace getVariable ["WFBE_AICOM_WILDCARD_ACTIVE", []]);',
            source,
        )
        self.assertIn(
            'if ((_x select 0) == _jipSide && {(_x select 7) > time}) then {',
            source,
        )
        self.assertIn(
            '[_jipPlayer, "WildcardMarker", ["create", _x select 1, _x select 2, _x select 3, _x select 4, _x select 5, _x select 6, false]] Call WFBE_CO_FNC_SendToClient;',
            source,
        )
        self.assertIn("sleep 0.5;", source)

    def test_receiver_can_suppress_replay_chat_without_changing_live_default(self) -> None:
        source = read(RECEIVER)

        self.assertIn(
            'Private ["_op","_mkName","_pos","_color","_type","_label","_detail","_markerText","_notify"];',
            source,
        )
        self.assertIn("_notify = true;", source)
        self.assertIn("if (count _this > 7) then {_notify = _this select 7};", source)
        self.assertIn('if ((typeName _notify) != "BOOL") then {_notify = true};', source)
        self.assertIn(
            'if (_notify && {!isNil "CommandChatMessage"}) then {',
            source,
        )

    def test_changed_runtime_files_remain_byte_identical_across_mission_mirrors(self) -> None:
        relative_paths = [
            Path("Server") / "Functions" / "AI_Commander_Wildcard.sqf",
            Path("Server") / "PVFunctions" / "AttackWave.sqf",
            Path("Client") / "PVFunctions" / "WildcardMarker.sqf",
        ]

        for relative_path in relative_paths:
            expected = (CHERNARUS / relative_path).read_bytes()
            for mission in MISSIONS[1:]:
                self.assertEqual(
                    expected,
                    (mission / relative_path).read_bytes(),
                    str(relative_path),
                )


if __name__ == "__main__":
    unittest.main()
