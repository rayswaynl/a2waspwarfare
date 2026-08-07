#!/usr/bin/env python3
"""Regression contract for fix0807b/hc-quoted-names.

Live RPT (wave0807a): an A2OA launch flag shaped -name="HC-AI-Control-1" bakes literal
double-quote characters into the resolved profile name, so a raw `(name _x) in
WFBE_C_HC_NAMES` test misses every quoted HC. This asserts BOTH halves of the fix stay in
place: the BELT (WFBE_C_HC_NAMES registry widened to also carry the quoted variant of
every name) and the BRACES (WFBE_CO_FNC_IsHcName helper, wired into the highest-value
money/enrollment consumers instead of a raw membership test).
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
]


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def test_hc_names_registry_carries_the_quoted_variant() -> None:
    """The BELT: Init_CommonConstants.sqf appends a '"'+name+'"' twin of every bare
    HC name so every pre-existing raw `in WFBE_C_HC_NAMES` call site is fixed for free."""
    sources = [
        read(root, "Common/Init/Init_CommonConstants.sqf") for root in MISSION_ROOTS
    ]
    for text in sources:
        assert 'if (isNil "WFBE_C_HC_NAMES") then {' in text
        assert "_hcDq = toString [34];" in text
        assert "_hcBareNames = +_hcNameList;" in text
        assert (
            "{ _hcNameList set [count _hcNameList, _hcDq + _x + _hcDq]; } forEach _hcBareNames;"
            in text
        )
    assert sources[0] == sources[1] == sources[2]


def test_is_hc_name_helper_exists_and_is_registered() -> None:
    """The BRACES: WFBE_CO_FNC_IsHcName strips a leading/trailing quote before the
    WFBE_C_HC_NAMES membership test, for any quoting quirk the registry widening does
    not anticipate. Must be Common (both isServer and client callers exist) and
    registered via Compile preprocessFileLineNumbers, per repo convention."""
    helper_sources = [
        read(root, "Common/Functions/Common_IsHcName.sqf") for root in MISSION_ROOTS
    ]
    for text in helper_sources:
        assert "_hcNames = missionNamespace getVariable [\"WFBE_C_HC_NAMES\", []];" in text
        assert "if (_name in _hcNames) exitWith {true};" in text
        # A3SELECT trap: must strip via toArray/toString + scalar `select N`, never a
        # `select [start,count]` slice (banned on A2 OA 1.64 - AGENTS.md / lint A3SELECT).
        # Only the CODE region matters here - the doc comment names the banned pattern
        # in prose (to explain why it is avoided), which is not itself a violation.
        code_region = text.split("*/", 1)[1]
        assert "select [" not in code_region
        assert "(_stripped != _name) && {_stripped in _hcNames}" in text
    assert helper_sources[0] == helper_sources[1] == helper_sources[2]

    init_sources = [read(root, "Common/Init/Init_Common.sqf") for root in MISSION_ROOTS]
    for text in init_sources:
        assert (
            'WFBE_CO_FNC_IsHcName = Compile preprocessFileLineNumbers "Common\\Functions\\Common_IsHcName.sqf";'
            in text
        )


def test_high_value_consumers_call_the_helper() -> None:
    """Money/enrollment call sites switched from a raw `in WFBE_C_HC_NAMES` test to
    `call WFBE_CO_FNC_IsHcName`, per-file expected call count. A regression here (a
    site reverting to the raw form) is still covered by the registry belt above, but
    loses the braces' defense-in-depth against a future quoting quirk."""
    expectations = {
        # relative path -> expected count of "call WFBE_CO_FNC_IsHcName"
        "Server/Functions/Server_OnPlayerConnected.sqf": 2,  # connect nameGate + its own diag_log
        "Server/Functions/Server_BankIncome.sqf": 1,  # BankIncome eligible-recipient split
        "Server/FSM/server_victory_threeway.sqf": 2,  # ROUNDEND stats flush + final DB save
        "Server/FSM/server_town_ai.sqf": 1,  # sortie proximity gate
        "Server/Functions/Server_VoteForCommander.sqf": 1,  # commander-election eligibility
        "Common/Functions/Common_CreditSidePlayers.sqf": 1,  # BankPayout/GuerVbiedBounty toll credit
        "Server/PVFunctions/RequestOnUnitKilled.sqf": 4,  # PvP streak, kill, assist bounty, teamkill penalty
    }
    for relative, expected_count in expectations.items():
        sources = [read(root, relative) for root in MISSION_ROOTS]
        for text in sources:
            assert text.count("call WFBE_CO_FNC_IsHcName") == expected_count, (
                relative,
                expected_count,
                text.count("call WFBE_CO_FNC_IsHcName"),
            )
        assert sources[0] == sources[1] == sources[2]


def test_request_on_unit_killed_bounty_credits_target_the_killer_group_object() -> None:
    """Kill-money mechanism verdict (this lane's live-money investigation): bounty is
    credited to _killer_group - the killer's OWN group, resolved by object reference via
    `group _killer` - never by a name/uid lookup into some other account. This is why a
    normal player's own kill bounty is not zeroed by the HC quoted-name bug: the
    WFBE_C_HC_NAMES/IsHcName exclusion only ever SKIPS a credit when the killer's own
    group is HC-led, which is orthogonal to a real player's own wallet."""
    sources = [
        read(root, "Server/PVFunctions/RequestOnUnitKilled.sqf") for root in MISSION_ROOTS
    ]
    for text in sources:
        assert (
            "if (_killer_uid != \"\" && {_srvPvp > 0} && {!((name (leader _killer_group)) call WFBE_CO_FNC_IsHcName)}) then {"
            in text
        )
        assert "[_killer_group, _srvPvp] Call WFBE_CO_FNC_ChangeTeamFunds;" in text
        assert (
            "if (_killer_uid != \"\" && {_srvBounty > 0} && {!((name (leader _killer_group)) call WFBE_CO_FNC_IsHcName)}) then {"
            in text
        )
        assert "[_killer_group, _srvBounty] Call WFBE_CO_FNC_ChangeTeamFunds;" in text


if __name__ == "__main__":
    test_hc_names_registry_carries_the_quoted_variant()
    test_is_hc_name_helper_exists_and_is_registered()
    test_high_value_consumers_call_the_helper()
    test_request_on_unit_killed_bounty_credits_target_the_killer_group_object()
    print("HC quoted-name registry contract: PASS")
