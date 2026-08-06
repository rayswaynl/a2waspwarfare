#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 3 (placement rejected inside HQ circle).

WFBE_C_DEF_PREVIEW_MAP (armed 2026-08-04) made typeOf _preview a REAL WDDM
composition-child classname for the seven WDDM anchors, which then tripped the
itemcategory==2 same-classname / DEFENSENAMES proximity checks (Init_Client.sqf,
WFBE_C_STRUCTURES_PLACEMENT_METHOD) against any pre-existing WDDM composition nearby
(HQ walls, weapon-position walls, an adjacent composition segment), rejecting
placement well inside the HQ build circle.

The fix exempts ONLY the two same-classname/DEFENSENAMES proximity checks for
WFBE_ANCHOR_PREVIEW_CLASSES classnames - the factory-clearance ring check must remain
unconditional (it is the last line of defense against placing on top of the HQ/base
structures themselves), and real density/spacing control for WDDM compositions stays
server-side (WFBE_C_WDDM_COMP_CAP / fortification cap in RequestDefense.sqf).
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
INIT_CLIENT = CHERNARUS / "Client" / "Init" / "Init_Client.sqf"
INIT_COMMON_CONSTANTS = CHERNARUS / "Common" / "Init" / "Init_CommonConstants.sqf"


def test_anchor_preview_classes_built_with_foreach_not_apply() -> None:
    """A2 OA has no `apply` command - the flat classname list must use forEach."""
    code = INIT_COMMON_CONSTANTS.read_text(encoding="utf-8-sig")

    map_idx = code.index("WFBE_ANCHOR_PREVIEW_MAP = [")
    map_close_idx = code.index("];", map_idx)
    classes_init_idx = code.index("WFBE_ANCHOR_PREVIEW_CLASSES = [];", map_close_idx)
    build_idx = code.index(
        '{WFBE_ANCHOR_PREVIEW_CLASSES = WFBE_ANCHOR_PREVIEW_CLASSES + [_x select 1]} forEach WFBE_ANCHOR_PREVIEW_MAP;',
        classes_init_idx,
    )

    assert map_idx < map_close_idx < classes_init_idx < build_idx
    assert " apply " not in code[classes_init_idx:build_idx + 200]


def test_exemption_wraps_only_the_two_proximity_checks_not_the_factory_ring() -> None:
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")

    category2_idx = code.index("if (_itemcategory == 2) then {")
    guard_open_idx = code.index(
        'if !((typeOf _preview) in WFBE_ANCHOR_PREVIEW_CLASSES) then {', category2_idx
    )
    walls_check_idx = code.index(
        "_walls = nearestObjects [_preview,[typeOf _preview],2];", guard_open_idx
    )
    walls_reject_idx = code.index(
        "if(count _walls > 1) then {_color = _colorRed} else{_color = _colorGreen};", walls_check_idx
    )
    defensenames_check_idx = code.index(
        'if(count (nearestObjects [_preview,missionNamespace getVariable (Format["WFBE_%1DEFENSENAMES",sideJoined])',
        walls_reject_idx,
    )
    # The guard-closing brace is the next bare "};" after the DEFENSENAMES check line.
    defensenames_line_end = code.index("\n", defensenames_check_idx)
    guard_close_idx = code.index("};", defensenames_line_end)

    factory_ring_idx = code.index(
        '_factories =\t nearestObjects[_preview,["Warfare_HQ_base_unfolded","WarfareBBaseStructure","Base_WarfareBContructionSite"],25];',
        guard_close_idx,
    )

    assert (
        category2_idx
        < guard_open_idx
        < walls_check_idx
        < walls_reject_idx
        < defensenames_check_idx
        < guard_close_idx
        < factory_ring_idx
    ), "the two proximity checks must be inside the exemption guard and the factory ring must be outside/after it"


def test_factory_ring_check_has_no_preview_class_exemption_of_its_own() -> None:
    """The factory-clearance ring block (~1808-1831) must stay unconditional - no
    `WFBE_ANCHOR_PREVIEW_CLASSES` reference anywhere inside it."""
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")

    factory_ring_idx = code.index(
        '_factories =\t nearestObjects[_preview,["Warfare_HQ_base_unfolded","WarfareBBaseStructure","Base_WarfareBContructionSite"],25];'
    )
    # The ring block ends where the itemcategory==2 else-branch (non-fortification path) begins.
    ring_block_end = code.index("}else{", factory_ring_idx)
    ring_block = code[factory_ring_idx:ring_block_end]

    assert "WFBE_ANCHOR_PREVIEW_CLASSES" not in ring_block


def test_exemption_comment_documents_the_server_side_backstop() -> None:
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")
    guard_idx = code.index('if !((typeOf _preview) in WFBE_ANCHOR_PREVIEW_CLASSES) then {')
    preceding_comment = code[max(0, guard_idx - 1200) : guard_idx]
    assert "WFBE_C_WDDM_COMP_CAP" in preceding_comment
    assert "RequestDefense.sqf" in preceding_comment


if __name__ == "__main__":
    test_anchor_preview_classes_built_with_foreach_not_apply()
    test_exemption_wraps_only_the_two_proximity_checks_not_the_factory_ring()
    test_factory_ring_check_has_no_preview_class_exemption_of_its_own()
    test_exemption_comment_documents_the_server_side_backstop()
    print("fortification preview-class proximity exemption regression check passed")
