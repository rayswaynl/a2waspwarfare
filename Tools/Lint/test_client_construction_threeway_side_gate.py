from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Init" / "Init_Client.sqf"


def test_construction_gate_uses_all_playable_enemy_sides():
    text = SOURCE.read_text(encoding="utf-8")

    assert "_enemySides = [west, east, resistance] - [sideJoined];" in text
    assert "_eArea = [_preview,((_eside) Call WFBE_CO_FNC_GetSideLogic)" not in text
    assert "side (_objects select 0) in _enemySides" in text
    assert "side _x in _enemySides" in text


if __name__ == "__main__":
    test_construction_gate_uses_all_playable_enemy_sides()
    print("PASS: construction placement gate recognizes every playable hostile side")
