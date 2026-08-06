"""Regression contract for the HC AICOM founding-size/lobby-cap boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander_Teams.sqf"
)
PARAMETERS = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp"
)


def test_hc_found_size_is_bounded_by_positive_lobby_ai_max_before_padding() -> None:
    """B57 padding must not override a valid low AI Group Size lobby choice."""
    text = TEAMS.read_text(encoding="utf-8-sig")
    start = text.index('private ["_sizeMin"')
    end = text.index("//--- HF-MAIN MANNED LIGHT MIX", start)
    block = text[start:end]

    assert '"_aiMax"' in block
    assert 'missionNamespace getVariable ["WFBE_C_AI_MAX", _foundSize]' in block
    assert 'if (_aiMax > 0 && {_foundSize > _aiMax}) then {_foundSize = _aiMax};' in block
    assert block.index("_foundSize = _aiMax") < block.index("while {count _template < _foundSize}")


def test_ai_group_size_lobby_range_is_positive_and_includes_default_boundary() -> None:
    """The source contract permits the low positive values that exposed the mismatch."""
    text = PARAMETERS.read_text(encoding="utf-8-sig")

    assert "values[] = {2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,35,40,45,50,60,70,80,90,100};" in text
    assert "default = 4;" in text


if __name__ == "__main__":
    test_hc_found_size_is_bounded_by_positive_lobby_ai_max_before_padding()
    test_ai_group_size_lobby_range_is_positive_and_includes_default_boundary()
