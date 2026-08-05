from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town_ai.sqf"


def test_failed_town_group_allocation_keeps_the_creation_arrays_aligned():
    text = SOURCE.read_text(encoding="utf-8")

    allocation = re.search(
        r'if \(isNull _ctlNewGrp\) then \{(?P<failed>.*?)\} else \{(?P<created>.*?)\n\s*\};',
        text,
        re.DOTALL,
    )

    assert allocation, "town group allocation must retain explicit failed/success branches"
    assert "[_teams, grpNull] call WFBE_CO_FNC_ArrayPush;" not in allocation.group("failed"), (
        "a failed server-side group must not be forwarded as grpNull to mode-1 delegation, where it escapes"
        " the delegator tracker"
    )
    assert "_plannedGroups = +_groups;" in text
    assert "[_groups, _plannedGroups select _groupIndex] call WFBE_CO_FNC_ArrayPush;" in text
    assert "[_positions, _position] call WFBE_CO_FNC_ArrayPush;" in text
    assert "[_teams, _ctlNewGrp] call WFBE_CO_FNC_ArrayPush;" in text
