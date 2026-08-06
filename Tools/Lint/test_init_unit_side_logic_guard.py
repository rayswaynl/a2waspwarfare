from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Unit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_Unit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_Unit.sqf",
)


def test_missing_side_logic_cannot_enter_unbounded_upgrade_wait() -> None:
    logic_lookup = "_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;"
    null_guard = "if (isNull _logik) exitWith {};"
    upgrade_wait = 'waitUntil {!isNil {_logik getVariable "wfbe_upgrades"}};'

    for path in MIRRORS:
        source = path.read_text(encoding="utf-8")

        assert logic_lookup in source
        assert null_guard in source
        assert upgrade_wait in source
        assert source.index(logic_lookup) < source.index(null_guard) < source.index(upgrade_wait)


if __name__ == "__main__":
    test_missing_side_logic_cannot_enter_unbounded_upgrade_wait()
    print("Init_Unit missing-side-logic regression checks passed")
