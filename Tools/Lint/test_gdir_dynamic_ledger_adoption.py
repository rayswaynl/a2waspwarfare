#!/usr/bin/env python3
"""Regression coverage for GUER towns acquired after Director startup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _source(mission: Path) -> str:
    return (ROOT / mission / "Server/AI/Server_GuerDirector.sqf").read_text(encoding="utf-8")


def test_guer_director_adopts_newly_guer_held_towns_after_startup() -> None:
    for mission in MISSIONS:
        source = _source(mission)
        assert "GDIR_LEDGER_ADOPT" in source
