#!/usr/bin/env python3
"""Regression contract for Veteran Company reinforcement skill parity."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_RunCommanderTeam.sqf"


def test_veteran_skill_is_persisted_and_reapplied_to_topups() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    founding = source.index('{_x setSkill _skillSend} forEach _units;')
    topup = source.index('_topUnit = [_topClass, _team, _topPos, _sideID] Call WFBE_CO_FNC_CreateUnit;')

    assert '_team setVariable ["wfbe_aicom_veteran_skill", _skillSend, true];' in source[founding:topup]
    assert '_topUnit setSkill _topSkill' in source[topup:]


if __name__ == "__main__":
    test_veteran_skill_is_persisted_and_reapplied_to_topups()
