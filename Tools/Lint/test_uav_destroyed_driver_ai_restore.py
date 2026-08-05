"""Regression coverage for UAV driver AI restoration after hull loss."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INTERFACE_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/UAV/uav_interface.sqf"),
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/UAV/uav_interface_oa.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/UAV/uav_interface.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/UAV/uav_interface_oa.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/UAV/uav_interface.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/UAV/uav_interface_oa.sqf"),
)

DRIVER_CAPTURE = "_driver = driver _uav;"
DRIVER_RESTORE = (
    'if (!isNull _driver && {alive _driver}) then '
    '{{_driver enableAI _x} forEach ["TARGET","AUTOTARGET"]};'
)


def test_destroyed_uav_restores_the_captured_living_driver_ai() -> None:
    for relative_path in INTERFACE_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert "'_driver'" in text, f"driver is not private in {relative_path}"
        assert DRIVER_CAPTURE in text, f"driver is not captured in {relative_path}"
        assert DRIVER_RESTORE in text, f"driver AI is not restored after hull loss in {relative_path}"
        assert text.index(DRIVER_CAPTURE) < text.index("waituntil"), relative_path
        assert text.index("waituntil") < text.index(DRIVER_RESTORE), relative_path
