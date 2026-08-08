from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MISSILE_HANDLER = MISSION / "Common" / "Functions" / "Common_HandleShootMissiles.sqf"
CLIENT_INIT = MISSION / "Client" / "Init" / "Init_Client.sqf"


def _terrain_masking_block(source: str) -> str:
    start = source.index("_fromPos = ")
    end = source.index("_terrainMasked = terrainIntersectASL", start)
    return source[start:end]


def test_terrain_masking_uses_operator_eye_and_target_aim_positions():
    """A clear turret/optic sight line must not be judged from ground-level object origins."""
    for path in (MISSILE_HANDLER, CLIENT_INIT):
        source = path.read_text(encoding="utf-8-sig")
        block = _terrain_masking_block(source)
        assert "_fromPos = eyePos player;" in block
        assert "_targetPos = aimPos _unit_targeted;" in block
        assert "getPosASL _vehicle" not in block
        assert "getPosASL _unit_targeted" not in block
