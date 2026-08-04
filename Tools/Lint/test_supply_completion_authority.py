#!/usr/bin/env python3
"""Regression contract for server-authoritative helicopter supply completion."""

from pathlib import Path
import unittest

from check_sqf import mask_comments

ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class SupplyCompletionAuthorityTests(unittest.TestCase):
    def test_client_completion_rederives_sender_side_and_validates_delivery_state(self) -> None:
        source = code("Server/Module/supplyMission/supplyMissionCompleted.sqf")
        start = source.index('WFBE_SE_FNC_HandleSupplyMissionCompleted = {')
        end = source.index('"WFBE_Server_PV_SupplyMissionCompleted" addPublicVariableEventHandler')
        handler = source[start:end]
        for token in (
            '(typeName _this) != "ARRAY"',
            'count _this < 3',
            '(typeName _playerObject) != "OBJECT"',
            '(typeName _associatedSupplyTruck) != "OBJECT"',
            'isNull _playerObject',
            'isNull _associatedSupplyTruck',
            'isPlayer _playerObject',
            'driver _associatedSupplyTruck != _playerObject',
            'WFBE_C_SUPPLY_HELI_TYPES',
            'SupplyByHeli',
            'Base_WarfareBUAVterminal',
            '(_dx * _dx) + (_dy * _dy)',
            '((getPos _associatedSupplyTruck) select 0) - (_cp select 0)',
            '((getPos _associatedSupplyTruck) select 1) - (_cp select 1)',
            # fold #1619 (fix(supply): cargo transfer world revalidation...): never trust the
            # client-provided side slot - derive it from the credited player, and use
            # `side group` (more stable than bare `side unit` when the unit is mid-state-change).
            '_sidePlayer = side group _playerObject',
        ):
            self.assertIn(token, handler)


if __name__ == "__main__":
    unittest.main()
