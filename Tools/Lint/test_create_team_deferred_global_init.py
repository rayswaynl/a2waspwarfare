"""Regression coverage for batching CreateTeam's client-init broadcasts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAM_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_CreateTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_CreateTeam.sqf",
)
UNIT_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_CreateUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_CreateUnit.sqf",
)


def test_create_unit_supports_opt_in_deferred_global_init() -> None:
    for path in UNIT_PATHS:
        source = path.read_text(encoding="utf-8")
        assert '_deferGlobalInit = if (count _this > 6) then {_this select 6} else {false};' in source
        assert 'if (!_deferGlobalInit) then {processInitCommands};' in source


def test_create_team_defers_and_flushes_unit_init_once_after_template() -> None:
    for path in TEAM_PATHS:
        source = path.read_text(encoding="utf-8")
        assert '[_x,_team,_position,_sideID,_global,"FORM",true] Call WFBE_CO_FNC_CreateUnit;' in source
        assert '[_type,_team,_position,_sideID,_global,"FORM",true] Call WFBE_CO_FNC_CreateUnit;' in source
        template_end = source.index("} forEach _list;")
        flush = source.index("processInitCommands};", template_end)
        assert flush < source.index("//--- TEMPLATE INTEGRITY", template_end)
