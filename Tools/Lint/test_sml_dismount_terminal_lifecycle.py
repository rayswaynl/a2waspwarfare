"""Contract for the HC-local SML-2 watchdog at round end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SML_REL = Path("Common/Functions/Common_SMLDismounts.sqf")


def test_sml_dismount_watchdog_exits_at_game_over_before_rejoin() -> None:
    sources = [(root / SML_REL).read_text(encoding="utf-8-sig") for root in MISSION_ROOTS]

    for source in sources:
        loop = "while {!WFBE_GameOver} do {"
        reason = 'if (WFBE_GameOver) then {_exitReason = "game_over"};'
        rejoin = "//--- ===== REJOIN: clear stamp + doFollow on every dismounted unit ====="

        assert loop in source
        assert "while {true} do {" not in source
        assert reason in source
        assert source.index(loop) < source.index(reason) < source.index(rejoin)
        assert '_uX setVariable ["wfbe_sml_detach_at", nil];' in source
        assert "_uX doFollow (leader _team);" in source

    assert all(source == sources[0] for source in sources[1:])
