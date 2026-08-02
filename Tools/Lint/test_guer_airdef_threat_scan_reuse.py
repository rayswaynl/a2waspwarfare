"""Regression coverage for GUER air-defense threat-scan reuse."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AIRDEF_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_GuerAirDef.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_GuerAirDef.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_GuerAirDef.sqf"),
)

ENEMY_COUNT = (
    '_enemies = {alive _x && {((side _x) == west) || {(side _x) == east}}} count '
    '((getPos _town) nearEntities [["Man","LandVehicle","Air","Ship"], '
    '((_town getVariable ["range", 600]) max 600)]);'
)
THREAT_GUARD = (
    'if (!((missionNamespace getVariable '
    '["WFBE_C_GUER_AIRDEF_THREAT_ONLY", 0]) > 0)) then {'
)
ASSIGNMENT_GATE = "_enemies > 0"


def test_guer_airdef_reuses_threat_scan_for_loadout_selection() -> None:
    for relative_path in AIRDEF_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert text.count(ENEMY_COUNT) == 2, f"expected gate/fallback scans only in {relative_path}"
        assert ASSIGNMENT_GATE in text, f"threat gate does not retain the cached count in {relative_path}"
        assert THREAT_GUARD in text, f"legacy fallback scan guard is missing in {relative_path}"

        gate = text.index(ASSIGNMENT_GATE)
        fallback = text.index(THREAT_GUARD)
        assert gate < fallback < text.index(ENEMY_COUNT, fallback)
