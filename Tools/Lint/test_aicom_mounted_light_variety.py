"""Regression coverage for HF-main mounted-light transport variety."""

from pathlib import Path


SOURCE = Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf")


def test_mounted_light_fill_rotates_over_an_eligible_pool() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    start = text.index("//--- HF-MAIN MANNED LIGHT MIX")
    end = text.index("//--- Build83 INF-TRANSPORT-TRUCK WIRE", start)
    block = text[start:end]
    assert "_mountPool = [];" in block
    assert "_mountPool set [count _mountPool, _x];" in block
    assert "_mountPool select (_mountPoolIdx mod (count _mountPool))" in block
    assert "_template = _template + [_mountClass];" in block
    assert "_mountAddedClasses set [count _mountAddedClasses, _mountClass];" in block
    assert "if (_mountClass == \"\")" not in block
    assert "if (count _mountPool == 0) then {\n\t\t\t\tif (count _templates > 0)" not in block


if __name__ == "__main__":
    test_mounted_light_fill_rotates_over_an_eligible_pool()
    print("PASS: HF-main mounted-light fill pools and rotates eligible transports")
