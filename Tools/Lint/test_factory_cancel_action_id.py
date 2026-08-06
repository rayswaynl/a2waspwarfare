"""Regression contract for factory queue cancel-action cleanup.

The client stores an action ID on the factory object while a unit is queued.
The runtime RPT showed the subsequent cleanup comparing an undefined value
when that object variable was nil, so the cleanup must normalize the value
before using it as an action ID on every LoadoutManager mirror.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_factory_cancel_cleanup_normalizes_action_id_before_comparison() -> None:
    guard = 'if (isNil "_myActionID" || {typeName _myActionID != "SCALAR"}) then {_myActionID = -1};'

    for terrain in TERRAINS:
        source = (ROOT / terrain / "Client/Functions/Client_BuildUnit.sqf").read_text(encoding="utf-8")
        start = source.index("//--- QoL cancel: remove the per-player cancel action")
        end = source.index("//--- E1:", start)
        cleanup = source[start:end]

        assert guard in cleanup, f"{terrain}: action ID must be nil/type-safe before comparison"
        assert cleanup.index(guard) < cleanup.index("if (_myActionID >= 0) then {")
        assert '_building setVariable [_myActionKey, -1];' in cleanup, (
            f"{terrain}: resolved action key must retain the numeric sentinel"
        )


if __name__ == "__main__":
    test_factory_cancel_cleanup_normalizes_action_id_before_comparison()
    print("factory cancel action-ID regression contract: PASS")
