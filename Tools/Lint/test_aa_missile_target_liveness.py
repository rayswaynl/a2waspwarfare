"""Regression contract for A-Life deletion during custom missile guidance."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HANDLER = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_HandleAAMissiles.sqf"
)


def test_custom_guidance_stops_when_its_original_target_is_deleted():
    source = HANDLER.read_text(encoding="utf-8-sig")
    loop = "While {!isNull _rkt && {!isNull _trg} && {alive _trg}} do {"

    assert loop in source
    assert source.index(loop) < source.index("getPosASL _trg")
