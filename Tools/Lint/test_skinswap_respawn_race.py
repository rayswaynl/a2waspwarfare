"""Regression contract for the skin-swap versus death/respawn handoff."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
SKIN_RELATIVE = Path("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")


def test_skin_swap_cancels_after_locality_wait_when_respawn_starts() -> None:
    """A death during the suspension must not reach the group handoff/selectPlayer path."""

    for mission_root in MISSION_ROOTS:
        source = mask_comments((ROOT / mission_root / SKIN_RELATIVE).read_text(encoding="utf-8-sig"))
        wait_start = source.index("_waitStart = time;")
        join_start = source.index("if (_usedSwapGrp) then {", wait_start)
        select_start = source.index("WFBE_CO_FNC_SelectPlayerCrossGroup", wait_start)
        handoff_window = source[wait_start:join_start]

        assert join_start < select_start, f"unexpected handoff ordering in {mission_root}"
        assert "alive _oldUnit" in handoff_window, (
            f"death of the captured body is not checked after the locality wait in {mission_root}"
        )
        assert "WFBE_Client_IsRespawning" in handoff_window, (
            f"respawn state is not checked after the locality wait in {mission_root}"
        )
        assert "deleteVehicle _newUnit" in handoff_window, (
            f"cancelled swap does not clean the unselected body in {mission_root}"
        )
        assert "WFBE_SkinSelector_InProgress = false" in handoff_window, (
            f"cancelled swap leaves the re-entry lock set in {mission_root}"
        )
