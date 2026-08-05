#!/usr/bin/env python3
"""Regression contract for locality-aware empty-vehicle reaping."""

from pathlib import Path
import unittest


MISSION = Path(__file__).resolve().parents[2] / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
REAPER = MISSION / "Server/Functions/Server_HandleEmptyVehicle.sqf"
PVF = MISSION / "Client/Functions/Client_HandlePVF.sqf"
RECEIVER = MISSION / "Client/PVFunctions/HandleSpecial.sqf"


def _match_block(text: str, open_brace: int) -> tuple:
    """Return (body, index_after_close) for the brace-matched block opening at ``open_brace``."""
    depth = 1
    i = open_brace + 1
    while depth > 0 and i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return text[open_brace + 1:i - 1], i


def _local_branches(text: str) -> tuple:
    """Split the `if (local _vehicle) then {...} else {...}` construct into its two bodies."""
    head = "if (local _vehicle) then {"
    start = text.index(head)
    then_body, after = _match_block(text, start + len(head) - 1)
    rest = text[after:]
    else_marker = rest.index("else {")
    assert rest[:else_marker].strip() == "", "local-vehicle branch is no longer a direct if/else"
    else_body, _ = _match_block(rest, else_marker + len("else {") - 1)
    return then_body, else_body


class EmptyVehicleRemoteDeleteTests(unittest.TestCase):
    def test_reaper_keeps_local_delete_direct_and_remote_delete_bounded(self) -> None:
        text = REAPER.read_text(encoding="utf-8-sig")

        self.assertIn("_reapAttempts = 0;", text)
        self.assertIn("_maxReapAttempts = 3;", text)

        # The contract is behavioural, not textual: a SERVER-LOCAL hull must be deleted
        # directly in the `then` branch, and a REMOTE one must go out via SendToClient in
        # the `else` branch - never the other way round. Asserting the literal
        # "deleteVehicle _vehicle;" broke the moment a fold wrapped the call in an
        # `if (!isNull _vehicle) then {...}` guard, which is strictly safer code.
        local_then, local_else = _local_branches(text)
        self.assertIn("deleteVehicle _vehicle", local_then)
        self.assertNotIn("SendToClient", local_then)
        self.assertIn(
            '[_vehicle, "HandleSpecial", ["cleanup-empty-vehicle", _vehicle]] Call WFBE_CO_FNC_SendToClient;',
            local_else,
        )
        self.assertNotIn("deleteVehicle _vehicle", local_else)
        self.assertIn("_reapAttempts = _reapAttempts + 1;", text)
        self.assertNotIn(
            'if (_timer > _delay) exitWith {emptyQueu = emptyQueu - [_vehicle];',
            text,
        )

    def test_hc_allowlist_and_receiver_validate_empty_hull_dispatch(self) -> None:
        pvf = PVF.read_text(encoding="utf-8-sig")
        receiver = RECEIVER.read_text(encoding="utf-8-sig")

        self.assertIn('"cleanup-empty-vehicle"', pvf)
        self.assertIn('case "cleanup-empty-vehicle":', receiver)
        self.assertIn('local _emptyVehicle', receiver)
        self.assertIn('{({alive _x} count crew _emptyVehicle) == 0}', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_airlifted", false]', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_is_guer_fob", false]', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_empty_vehicle_reap", false]', receiver)


if __name__ == "__main__":
    unittest.main()
