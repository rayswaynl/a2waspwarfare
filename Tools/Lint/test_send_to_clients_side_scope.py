"""Regression contract for side-scoped Client PVF transport.

``SendToClients`` used to broadcast every PVF with ``publicVariable`` and
relied on the receiver's local side guard.  That hid the UI on the other
sides, but still delivered sensitive payloads such as recon coordinates.
Side destinations must instead be sent only to connected human players on
that side; nil destinations remain deliberate public broadcasts.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_SendToClients.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_SendToClients.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_SendToClients.sqf"),
)


def test_side_destinations_are_transport_targeted_and_mirrored():
    sources = [(ROOT / relative).read_bytes() for relative in PATHS]
    assert sources[0] == sources[1] == sources[2]

    text = sources[0].decode("utf-8-sig")
    side_start = text.index('if (typeName _destination == "SIDE") then {')
    global_start = text.index('} else {', side_start)
    side_block = text[side_start:global_start]
    global_block = text[global_start:]

    assert "forEach playableUnits" in side_block
    assert "isPlayer _recipient" in side_block
    assert "side _recipient == _destination" in side_block
    assert "publicVariableClient" in side_block
    assert "publicVariable 'WFBE_PVF_%1'" not in side_block
    assert "publicVariable 'WFBE_PVF_%1'" in global_block


if __name__ == "__main__":
    test_side_destinations_are_transport_targeted_and_mirrored()
    print("SendToClients side transport scope: PASS")
