#!/usr/bin/env python3
"""Case-list well-formedness for the Server_HandleSpecial dispatch switch.

Picklist 4 phase 1 (card wasp-55feature-switch-phase1-20260722): the single switch
routes ~55 unrelated features, so a mangled case list breaks features that look
unrelated with no trace. These checks keep the case list well-formed and keep the
phase-1 traceability guards (LineNumbers compile + default guard) from regressing.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)

HANDLESPECIAL = "Server/Functions/Server_HandleSpecial.sqf"
INIT_SERVER = "Server/Init/Init_Server.sqf"

# String-labelled cases only; the expression cases (`case (_struct isKindOf ...)`)
# belong to the inner structure-cost switch and are not dispatch entry points.
CASE_RE = re.compile(r'^\s*case\s+"([^"]+)"\s*:', re.M)

# Floor at the 2026-07-22 count: shrinkage means a case was lost (bad merge/edit);
# intentional removals must lower this floor in the same PR that removes the case.
CASE_FLOOR = 56


def _cases(mission: Path) -> list:
    source = (ROOT / mission / HANDLESPECIAL).read_text(encoding="utf-8")
    return CASE_RE.findall(source)


def test_case_labels_are_wellformed_and_unique() -> None:
    for mission in MISSIONS:
        cases = _cases(mission)
        assert len(cases) >= CASE_FLOOR, (
            f"{mission}: case list shrank to {len(cases)} (floor {CASE_FLOOR}); "
            "a dispatch case was lost"
        )
        dupes = sorted({c for c in cases if cases.count(c) > 1})
        assert not dupes, f"{mission}: duplicate case labels {dupes} (later case is dead code)"
        for label in cases:
            assert re.fullmatch(r"[A-Za-z0-9_-]+", label), (
                f"{mission}: malformed case label {label!r}"
            )


def test_mirrors_share_identical_case_list() -> None:
    baseline = _cases(MISSIONS[0])
    for mission in MISSIONS[1:]:
        assert _cases(mission) == baseline, (
            f"{mission}: case list drifted from the Chernarus source"
        )


def test_switch_keeps_toplevel_default_guard() -> None:
    for mission in MISSIONS:
        source = (ROOT / mission / HANDLESPECIAL).read_text(encoding="utf-8")
        assert "unknown request type" in source, (
            f"{mission}: unknown-request default guard missing from Server_HandleSpecial.sqf"
        )


def test_dispatch_compile_keeps_linenumbers() -> None:
    needle = (
        "HandleSpecial = Compile preprocessFileLineNumbers "
        '"Server\\Functions\\Server_HandleSpecial.sqf";'
    )
    for mission in MISSIONS:
        source = (ROOT / mission / INIT_SERVER).read_text(encoding="utf-8")
        assert needle in source, (
            f"{mission}: HandleSpecial compile regressed from preprocessFileLineNumbers "
            "(parse errors would go anonymous again)"
        )
