"""Regression contract for no-HC AICOM template eligibility."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSIGN_TYPES = tuple(
    ROOT / mission_root / "Server/AI/Commander/AI_Commander_AssignTypes.sqf"
    for mission_root in (
        "Missions/[55-2hc]warfarev2_073v48co.chernarus",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
    )
)


def test_no_hc_template_selection_requires_each_class_to_be_producible() -> None:
    """AssignTypes must reject the same stale per-unit tiers that Produce rejects."""
    sources = []
    for source in ASSIGN_TYPES:
        text = source.read_text(encoding="utf-8-sig")
        sources.append(text.encode("utf-8"))
        assert '([_cn, _sideText, _upgrades] Call WFBE_CO_FNC_IsUnitUnlocked) select 0' in text
        assert text.index('([_cn, _sideText, _upgrades] Call WFBE_CO_FNC_IsUnitUnlocked) select 0') < text.index(
            'if (_ok) then {_eligible set [count _eligible, _i]}'
        )

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_no_hc_template_selection_requires_each_class_to_be_producible()
    print("AICOM no-HC per-unit unlock contract: PASS")
