"""Regression coverage for HQ-strike ownership handoff."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Server/AI/Commander/AI_Commander_Strategy.sqf"


def test_hq_strike_claim_retires_the_abandoned_town_dispatch() -> None:
    """A strike handoff must close town accounting and allocator ownership first."""
    for mission in MISSIONS:
        source = (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")
        claim = source.index('_best setVariable ["wfbe_aicom_strike", true];')
        next_count = source.index("_strikeCount = _strikeCount + 1;", claim)
        handoff = source[claim:next_count]

        expected = (
            '_best setVariable ["wfbe_aicom_townorder", [], false];',
            '_best setVariable ["wfbe_aicom_dispatch_open", false];',
            '_best setVariable ["wfbe_aicom_alloc_target", nil];',
            '_best setVariable ["wfbe_aicom_alloc_tick", nil];',
        )
        assert all(line in handoff for line in expected)


def test_hq_strike_handoff_mirrors_are_byte_identical() -> None:
    contents = [
        (ROOT / mission / RELATIVE).read_bytes()
        for mission in MISSIONS
    ]
    assert contents[0] == contents[1] == contents[2]
