from pathlib import Path


SALVAGE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "FSM"
    / "updatesalvage.sqf"
)


def test_salvage_wreck_collection_uses_in_place_array_push():
    source = SALVAGE.read_text(encoding="utf-8-sig")
    collect = source.split("_wrecks = [];", 1)[1].split("_perfWrecks = count _wrecks", 1)[0]

    assert collect.count("WFBE_CO_FNC_ArrayPush") == 1
    assert "_wrecks = _wrecks + [_x]" not in collect


if __name__ == "__main__":
    test_salvage_wreck_collection_uses_in_place_array_push()
    print("Salvage wreck array-growth contract: PASS")
