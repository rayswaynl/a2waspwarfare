#!/usr/bin/env python3
"""Regression contract for server-authoritative faction-smoke emission."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Common/Functions/Common_SpawnFactionSmoke.sqf"


def test_faction_smoke_rejects_non_server_callers_before_mutating_state() -> None:
    for mission in MISSIONS:
        source = (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")
        assert "if (!isServer) exitWith {};" in source, (
            "Faction-smoke may be called from HC-owned commander teams; only the server may create smoke."
        )
        authority_guard = source.index("if (!isServer) exitWith {};")
        feature_gate = source.index('WFBE_C_FSMOKE_ENABLED')
        create_vehicle = source.index("createVehicle")
        assert authority_guard < feature_gate < create_vehicle


if __name__ == "__main__":
    test_faction_smoke_rejects_non_server_callers_before_mutating_state()
    print("faction smoke server-authority contract: PASS")
