from pathlib import Path


PREP_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Module/Arty/ARTY_mobileMissionPrep.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Module/Arty/ARTY_mobileMissionPrep.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Module/Arty/ARTY_mobileMissionPrep.sqf"
    ),
)


def test_artillery_prep_yields_while_waiting_for_the_vehicle_to_stop():
    for path in PREP_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        assert "waitUntil {sleep 0.05; speed _vehicle < 1};" in source, path
        assert "waitUntil {speed _vehicle < 1};" not in source, path


if __name__ == "__main__":
    test_artillery_prep_yields_while_waiting_for_the_vehicle_to_stop()
