"""Regression contract for live town-static ammunition replenishment."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    return (ROOT / mission / "Server/FSM/server_town_ai.sqf").read_text(encoding="utf-8-sig")


def test_active_town_statics_have_a_throttled_server_local_rearm_path() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        active = source.split('if((_town getVariable "wfbe_active") || (_town getVariable "wfbe_active_air")) then {', 1)[1]

        assert "wfbe_town_defense_rearm_at" in active
        assert "time + 300" in active
        assert '"wfbe_town_defenses", []' in active
        assert "local _defense" in active
        assert "WFBE_IsTownDefenderAI" in active
        assert "!(isPlayer (gunner _defense))" in active
        assert "_defense setVehicleAmmo 1;" in active
