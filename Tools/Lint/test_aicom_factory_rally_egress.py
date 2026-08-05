"""Static contract for AI refill egress when a factory has no rally variable."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _server_buy_unit(mission_root: Path) -> str:
    return (ROOT / mission_root / "Server/Functions/Server_BuyUnit.sqf").read_text(
        encoding="utf-8"
    )


def _require(block: str, pattern: str, label: str) -> None:
    if re.search(pattern, block, re.MULTILINE | re.DOTALL) is None:
        raise AssertionError(label)


def _check_mission(mission_root: Path) -> None:
    source = _server_buy_unit(mission_root)
    if source.count('getVariable "wfbe_aicom_factory_rally"') != 2:
        raise AssertionError(f"{mission_root}: expected infantry and vehicle rally reads")

    infantry = re.search(
        r'if \(_unitType isKindOf "Man"\) then \{(?P<body>.*?)\n\} else \{',
        source,
        re.MULTILINE | re.DOTALL,
    )
    if infantry is None:
        raise AssertionError(f"{mission_root}: infantry production branch not found")
    infantry_body = infantry.group("body")

    vehicle = re.search(
        r'_vehicle allowCrewInImmobile true;(?P<body>.*?)\n\t//--- fable/aicom-carrier-velocity',
        source,
        re.MULTILINE | re.DOTALL,
    )
    if vehicle is None:
        raise AssertionError(f"{mission_root}: vehicle egress branch not found")
    vehicle_body = vehicle.group("body")

    infantry_fallback = (
        r'_aiRally = _building getVariable "wfbe_aicom_factory_rally";\s+'
        r'if \(isNil "_aiRally" \|\| \{typeName _aiRally != "ARRAY"\} '
        r'\|\| \{count _aiRally < 2\}\) then \{\s+'
        r'_aiLeader = leader _team;\s+'
        r'if \(!isNull _aiLeader && \{alive _aiLeader\} '
        r'&& \{\(_aiLeader distance _building\) > 200\}\) then '
        r'\{_aiRally = getPosATL _aiLeader;\};\s+\};'
    )
    vehicle_fallback = (
        r'_aiRally = _building getVariable "wfbe_aicom_factory_rally";\s+'
        r'if \(isNil "_aiRally" \|\| \{typeName _aiRally != "ARRAY"\} '
        r'\|\| \{count _aiRally < 2\}\) then \{\s+'
        r'_aiLeader = leader _team;\s+'
        r'if \(!isNull _aiLeader && \{alive _aiLeader\} '
        r'&& \{_vehicle isKindOf "LandVehicle"\} '
        r'&& \{\(_aiLeader distance _building\) > 200\}\) then '
        r'\{_aiRally = getPosATL _aiLeader;\};\s+\};'
    )
    final_guard = (
        r'if \(!isNil "_aiRally" && \{typeName _aiRally == "ARRAY"\} '
        r'&& \{count _aiRally >= 2\} && \{!isPlayer \(leader _team\)\} '
    )

    _require(infantry_body, r'private \["_aiRally",\s*"_aiLeader"\];',
             f"{mission_root}: infantry declares rally fallback locals")
    _require(infantry_body, infantry_fallback,
             f"{mission_root}: infantry falls back only to a distant live team leader")
    _require(infantry_body, final_guard + r'&& \{!isNull _soldier\}\) then \{\s+_soldier commandMove _aiRally;',
             f"{mission_root}: infantry keeps the AI-only commandMove guard")

    _require(vehicle_body, r'private \["_aiRally",\s*"_aiLeader"\];',
             f"{mission_root}: vehicle declares rally fallback locals")
    _require(vehicle_body, vehicle_fallback,
             f"{mission_root}: vehicle fallback is ground-only and factory-clear")
    _require(vehicle_body, final_guard + r'&& \{!isNull \(driver _vehicle\)\}\) then \{\s+\(driver _vehicle\) commandMove _aiRally;',
             f"{mission_root}: vehicle keeps the AI-only driver commandMove guard")


def test_factory_rally_fallback_contract() -> None:
    for mission_root in MISSION_ROOTS:
        _check_mission(mission_root)


if __name__ == "__main__":
    test_factory_rally_fallback_contract()
    print("PASS factory rally fallback contract")
