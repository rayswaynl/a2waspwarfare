#!/usr/bin/env python3
"""Regression checks for Field Hospital locality-safe healing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _source(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8")


def test_field_hospital_dispatches_healing_to_unit_owners() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Server/Functions/AI_Commander_Wildcard.sqf")
        assert '"aicom-field-hospital"' in source
        assert "Call WFBE_CO_FNC_SendToClients" in source
        assert "_x setDamage 0" not in source[source.index('case 11:'):source.index('case 13:')]


def test_field_hospital_receiver_filters_for_local_eligible_units() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/PVFunctions/HandleSpecial.sqf")
        start = source.index('case "aicom-field-hospital"')
        end = source.index('\n\tcase ', start + 1)
        handler = source[start:end]
        assert "local _x" in handler
        assert "alive _x" in handler
        assert "!isPlayer _x" in handler
        assert "_x setDamage 0" in handler
