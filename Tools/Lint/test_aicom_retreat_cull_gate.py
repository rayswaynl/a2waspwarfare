"""Regression contract for AICOM retreat culling.

The absolute distance cap (WFBE_C_AICOM_RETREAT_MAX_DIST) is a terminal safeguard
that must fire only AFTER the commander has issued at least one retreat-and-reform
order.  A newly depleted lone survivor (alive<2) that is already far from its HQ
must still receive that first order rather than being deleted on the very first
Produce evaluation with tries=0 issues=0.  See AI_Commander_Produce.sqf: the gate's
own comment states "we never cull on the very first order"; before this fix the
distance OR-term bypassed that invariant.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCE_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
)

EXPECTED_GATE = "if (_rTries >= _rBudget || {_rIssues >= _rMaxIssues} || {_rIssues >= 1 && {_curDist > _rMaxDist}}) then {"


def test_distance_cap_requires_a_prior_retreat_order():
    raw = []
    for path in PRODUCE_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        raw.append(path.read_bytes())
        assert EXPECTED_GATE in source, "retreat-cull gate not guarded by _rIssues>=1 in %s" % path
        # The un-gated distance term must no longer appear on its own.
        assert "|| {_curDist > _rMaxDist})" not in source, "un-gated distance cull still present in %s" % path

    # Chernarus source and both mirrors must stay byte-identical.
    assert raw[0] == raw[1] == raw[2], "AI_Commander_Produce.sqf differs across terrains"


if __name__ == "__main__":
    test_distance_cap_requires_a_prior_retreat_order()
    print("AICOM retreat-cull gate contract: PASS")
