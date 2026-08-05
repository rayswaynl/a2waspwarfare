#!/usr/bin/env python3
"""Regression coverage for naval-CAP pilots surviving a hull loss."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS_NAVAL = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus")
    / "Server/Init/Init_NavalHVT.sqf"
)
CAP_GROUP_SWEEP = re.compile(
    r"\{if \(!isNull _x && \{!isPlayer _x\}\) then "
    r"\{deleteVehicle _x; sleep 0\}\} forEach units _capGrp(?:;|\})"
)


def test_naval_cap_shutdown_reaps_ejected_pilots_before_deleting_group() -> None:
    """Both authoritative CAP shutdowns must sweep non-player group members."""
    text = (ROOT / CHERNARUS_NAVAL).read_text(encoding="utf-8")

    # Reconcile lanes edit Chernarus only; the fold orchestrator regenerates TK/ZG.
    assert len(CAP_GROUP_SWEEP.findall(text)) == 2
    assert text.count("deleteGroup _capGrp") == 2


if __name__ == "__main__":
    test_naval_cap_shutdown_reaps_ejected_pilots_before_deleting_group()
