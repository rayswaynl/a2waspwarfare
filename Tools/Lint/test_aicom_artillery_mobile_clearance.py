from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
FIRE = CHERNARUS / "Common" / "Functions" / "Common_FireArtillery.sqf"
MOBILE = CHERNARUS / "Common" / "Functions" / "Common_RunCommanderTeam.sqf"


def test_mobile_artillery_preserves_its_80m_clearance_at_fire_time():
    """A mobile battery accepts an assault target at 80 m clearance; the shared worker
    must receive that same radius for its post-aim and per-round safety checks."""
    fire = FIRE.read_text(encoding="utf-8-sig")
    mobile = MOBILE.read_text(encoding="utf-8-sig")

    assert "_ffRad = if ((count _this) > 4) then {_this select 4} else {400};" in fire
    assert "[_artyHull, _tgtP, _side, 60, 80] Spawn WFBE_CO_FNC_FireArtillery;" in mobile
