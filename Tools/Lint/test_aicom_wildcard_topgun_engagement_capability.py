"""Regression contract for W22 selecting an actually armed fixed-wing asset."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard.sqf"

W22_ATTACK_CLASSES = (
    '["A10","A10_US_EP1","AV8B","AV8B2","F35B","L159_ACR",'
    '"L39_TK_EP1","Su25_CDF","Su25_Ins","Su25_TK_EP1","Su34",'
    '"Su39","ibrPRACS_MiG21mol"]'
)
W22_SELECTION = (
    '{ if (_w22PlaneClass == "" && {isClass (configFile >> "CfgVehicles" >> _x)} '
    '&& {_x isKindOf "Plane"} && {_x in _w22AttackClasses}) then '
    '{_w22PlaneClass = _x} } forEach _w22AirList;'
)


def test_w22_eligibility_and_dispatch_reject_transport_planes():
    """W22 must not turn a lift/paracargo plane into an air-superiority draw."""
    source_bytes = []
    for mission_root in MISSION_ROOTS:
        path = mission_root / WILDCARD_PATH
        source = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        assert W22_ATTACK_CLASSES in source
        assert source.count(W22_SELECTION) == 2
        assert source.index(W22_ATTACK_CLASSES) < source.index(W22_SELECTION)

        # These roster entries are transport/lift assets, not W22 attack candidates.
        attack_slice = source[source.index(W22_ATTACK_CLASSES) : source.index(W22_ATTACK_CLASSES) + len(W22_ATTACK_CLASSES)]
        assert "C130J_US_EP1" not in attack_slice
        assert "An2_TK_EP1" not in attack_slice

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == "__main__":
    test_w22_eligibility_and_dispatch_reject_transport_planes()
    print("AICOM W22 engagement-capability contract: PASS")
