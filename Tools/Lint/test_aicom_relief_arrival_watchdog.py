from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = Path("Server/AI/Commander/AI_Commander_Strategy.sqf")


def test_relief_group_at_destination_is_not_released_as_wedged():
    """A stationary defender at its relief town is holding position, not stuck en route."""
    for mission in MISSIONS:
        source = (mission / RELATIVE).read_text(encoding="utf-8-sig")
        watchdog = source.index("//--- WAVE-1 CAUSE-4 RELIEF/STRIKE WEDGE WATCHDOG")
        release = source.index('[_wTeam, "towns"] Call SetTeamMoveMode;', watchdog)
        guarded = source[watchdog:release]

        assert '"wfbe_aicom_relief"' in guarded
        assert "_wLdr distance _wRelief" in guarded
        assert "WFBE_C_AICOM_STUCK_FAR" in guarded
