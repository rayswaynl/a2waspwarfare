"""Regression contract for the side-patrol to AICOM recovery bridge.

Patrols own their movement loop and therefore never publish ``wfbe_aicom_order``
for ``Common_RunCommanderTeam`` to consume.  Repeated patrol wedges must invoke
the shared local recovery routine instead of only retargeting forever.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
RECOVERY_CALL = "[_team, _pBridgeTier, _side, getPos _target, \"patrol\"] Spawn WFBE_CO_FNC_RunUnstuckRecovery;"


def test_patrol_wedge_threshold_bridges_into_tiered_recovery() -> None:
    for root in MISSION_ROOTS:
        patrol = (ROOT / root / "Common/Functions/Common_RunSidePatrol.sqf").read_text(encoding="utf-8-sig")

        assert "PATROL_UNSTUCK_BRIDGE" in patrol
        assert "_pBridgeTier" in patrol
        assert RECOVERY_CALL in patrol


def test_patrol_bridge_uses_registered_tiered_recovery() -> None:
    for root in MISSION_ROOTS:
        common_init = (ROOT / root / "Common/Init/Init_Common.sqf").read_text(encoding="utf-8-sig")
        recovery = (ROOT / root / "Common/Functions/Common_RunUnstuckRecovery.sqf").read_text(encoding="utf-8-sig")

        assert 'WFBE_CO_FNC_RunUnstuckRecovery = Compile preprocessFileLineNumbers "Common\\Functions\\Common_RunUnstuckRecovery.sqf";' in common_init
        assert "UNSTUCK_FIRED" in recovery
        assert "origin=" in recovery
        assert "if (_uTier >= 3) then {" in recovery
