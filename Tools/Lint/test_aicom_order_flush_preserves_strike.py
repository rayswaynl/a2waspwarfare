from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = Path("Common/Functions/Common_RunCommanderTeam.sqf")


def test_teleport_order_flush_preserves_optional_strike_tier():
    for mission in MISSIONS:
        text = (mission / RELATIVE).read_text(encoding="utf-8")
        assert text.count('_uFlushTier = if (count _uFlushOrder > 3) then {_uFlushOrder select 3} else {0};') == 2
        assert text.count('[_uFlushSeq + 1, _uFlushMode, _uFlushDest, _uFlushTier]') == 2
