"""Contract tests for the client-side map-boundary monitor wiring."""

from pathlib import Path
import re


REPO = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    REPO / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    REPO / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    REPO / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _active_lines(text: str) -> list[str]:
    return [line for line in text.splitlines() if not line.lstrip().startswith("//")]


def test_boundary_handler_is_started_by_a_lifecycle_supervisor() -> None:
    """The compiled handler must have a live call site in every release terrain."""

    for mission_root in MISSION_ROOTS:
        init_text = (mission_root / "Client/Init/Init_Client.sqf").read_text(encoding="utf-8")
        active_text = "\n".join(_active_lines(init_text))

        assert "BoundariesHandleOnMap = Compile preprocessFile" in active_text
        assert active_text.count("[] spawn BoundariesHandleOnMap;") == 1
        assert "paramBoundariesRunning" in active_text
        assert "WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED" in active_text
        assert "WFBE_GameOver" in active_text
        assert re.search(r"alive player.*paramBoundariesRunning", active_text)


def test_boundary_handler_retains_the_one_shot_kill_contract() -> None:
    """The supervisor must reuse the existing off-map countdown/kill worker."""

    for mission_root in MISSION_ROOTS:
        handler_text = (mission_root / "Client/Functions/Client_HandleOnMap.sqf").read_text(
            encoding="utf-8"
        )

        assert "WFBE_C_PLAYERS_OFFMAP_TIMEOUT" in handler_text
        assert "Call BoundariesIsOnMap" in handler_text
        assert "(vehicle player) setDamage 1" in handler_text
        assert "paramBoundariesRunning = false" in handler_text
