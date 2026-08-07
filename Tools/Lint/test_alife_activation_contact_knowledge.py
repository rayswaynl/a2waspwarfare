#!/usr/bin/env python3
"""Regression contract for A-Life garrison knowledge seeded from activation contacts."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_town_garrison_reveal_uses_activation_contacts_not_a_second_area_sweep() -> None:
    source = (CH / "Common" / "Functions" / "Common_CreateTownUnits.sqf").read_text(encoding="utf-8")

    assert '_activationContacts = if (count _this > 6)' in source
    assert 'forEach _activationContacts' in source
    assert '_revealPos nearEntities _revealRange' not in source


def test_explicit_empty_contact_snapshot_does_not_fall_back_to_area_reveal() -> None:
    source = (CH / "Common" / "Functions" / "Common_RevealArea.sqf").read_text(encoding="utf-8")

    assert '_contactsProvided = count _this > 3;' in source
    assert 'if (_contactsProvided) then {_contacts} else {_pos nearEntities _range}' in source


def test_activation_contacts_cross_every_town_ai_creation_boundary() -> None:
    town_ai = (CH / "Server" / "FSM" / "server_town_ai.sqf").read_text(encoding="utf-8")
    delegate = (CH / "Server" / "Functions" / "Server_FNC_Delegation.sqf").read_text(encoding="utf-8")
    headless = (CH / "Server" / "Functions" / "Server_DelegateAITownHeadless.sqf").read_text(encoding="utf-8")
    receiver = (CH / "Client" / "Functions" / "Client_DelegateTownAI.sqf").read_text(encoding="utf-8")
    static = (CH / "Server" / "Functions" / "Server_OperateTownDefensesUnits.sqf").read_text(encoding="utf-8")

    assert '[_town, _side, _groups, _positions, _teams, _detectedFiltered] Call WFBE_SE_FNC_DelegateAITown' in town_ai
    assert '[_town, _side, _groups, _positions, _hcTeams, _detectedFiltered] Call WFBE_CO_FNC_DelegateAITownHeadless' in town_ai
    assert '[_town, _side, _groups, _positions, _teams, [], _detectedFiltered] Call WFBE_CO_FNC_CreateTownUnits' in town_ai
    assert '[_town, _side, "spawn", _detectedFiltered] Call WFBE_SE_FNC_OperateTownDefensesUnits' in town_ai
    assert "_contacts = if (count _this > 5) then {_this select 5} else {[]};" in delegate
    assert "_contacts = if (count _this > 5) then {_this select 5} else {[]};" in headless
    assert "_contacts = if (count _this > 6) then {_this select 6} else {[]};" in receiver
    assert '[], _contacts] call WFBE_CO_FNC_CreateTownUnits' in receiver
    assert '[_team, _town getVariable "range", _town, _activationContacts] Call RevealArea;' in static


def test_knowledge_seeding_mirrors_match_chernarus() -> None:
    changed_paths = (
        Path("Client") / "Functions" / "Client_DelegateTownAI.sqf",
        Path("Common") / "Functions" / "Common_CreateTownUnits.sqf",
        Path("Common") / "Functions" / "Common_RevealArea.sqf",
        Path("Server") / "FSM" / "server_town_ai.sqf",
        Path("Server") / "Functions" / "Server_DelegateAITownHeadless.sqf",
        Path("Server") / "Functions" / "Server_FNC_Delegation.sqf",
        Path("Server") / "Functions" / "Server_OperateTownDefensesUnits.sqf",
    )
    for relative_path in changed_paths:
        digest = sha256((CH / relative_path).read_bytes()).hexdigest()
        for mirror in MIRRORS:
            assert sha256((mirror / relative_path).read_bytes()).hexdigest() == digest
