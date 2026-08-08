#!/usr/bin/env python3
"""Regression contract for wave0804b FIX 3 (placement rejected inside HQ circle).

WFBE_C_DEF_PREVIEW_MAP (armed 2026-08-04) made typeOf _preview a REAL WDDM
composition-child classname for the seven WDDM anchors, which then tripped the
itemcategory==2 same-classname / DEFENSENAMES proximity checks (Init_Client.sqf,
WFBE_C_STRUCTURES_PLACEMENT_METHOD) against any pre-existing WDDM composition nearby
(HQ walls, weapon-position walls, an adjacent composition segment), rejecting
placement well inside the HQ build circle.

The fix exempts ONLY the two same-classname/DEFENSENAMES proximity checks for
WFBE_ANCHOR_PREVIEW_CLASSES classnames - real density/spacing control for WDDM
compositions stays server-side (WFBE_C_WDDM_COMP_CAP / fortification cap in
RequestDefense.sqf).

fable/placement-preview-fix (owner 2026-08-08: "ALL NEW structure previews render RED,
game does not allow placement") gave the factory-clearance ring check its OWN, separate,
narrower relaxation for just the 5 large Fortification Pack pieces
(WFBE_FORTIF_PACK_PREVIEW_CLASSES) - see the test_factory_ring_* tests below. It is no
longer literally unconditional, but every item outside that 5-item subset (statics,
Hedgehog Line, Flak Tower, legacy Fortification walls/camo nets) still gets the exact
original factory-footprint-scaled clearance.
"""

from __future__ import annotations

import re
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


def test_factory_ring_check_has_no_broad_anchor_exemption_of_its_own() -> None:
    """fable/placement-preview-fix (owner 2026-08-08: "ALL NEW structure previews render
    RED, game does not allow placement") gave the factory-clearance ring block (~1808-1831)
    its OWN, narrower relaxation - see test_factory_ring_relaxation_* below. That narrower
    relaxation must use WFBE_FORTIF_PACK_PREVIEW_CLASSES (5 items: the large linear
    Fortification Pack pieces), never the broad 7-item WFBE_ANCHOR_PREVIEW_CLASSES the two
    proximity checks above are exempted with - Hedgehog Line and Flak Tower must keep the
    original factory-scaled clearance."""
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")

    factory_ring_idx = code.index(
        '_factories =\t nearestObjects[_preview,["Warfare_HQ_base_unfolded","WarfareBBaseStructure","Base_WarfareBContructionSite"],25];'
    )
    # The ring block ends where the itemcategory==2 else-branch (non-fortification path) begins.
    ring_block_end = code.index("}else{", factory_ring_idx)
    ring_block = code[factory_ring_idx:ring_block_end]

    assert "WFBE_ANCHOR_PREVIEW_CLASSES" not in ring_block
    assert "WFBE_FORTIF_PACK_PREVIEW_CLASSES" in ring_block


def test_factory_ring_relaxation_keeps_the_original_clearance_for_everything_else() -> None:
    """The relaxation must be additive: items NOT in WFBE_FORTIF_PACK_PREVIEW_CLASSES (every
    static defense, Hedgehog Line, Flak Tower, and any future Fortification-category item)
    keep the exact original factory-footprint-scaled clearance check, byte-identical."""
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")

    factory_ring_idx = code.index(
        '_factories =\t nearestObjects[_preview,["Warfare_HQ_base_unfolded","WarfareBBaseStructure","Base_WarfareBContructionSite"],25];'
    )
    ring_block_end = code.index("}else{", factory_ring_idx)
    ring_block = code[factory_ring_idx:ring_block_end]

    guard_idx = ring_block.index('if ((typeOf _preview) in WFBE_FORTIF_PACK_PREVIEW_CLASSES) then {')
    assert 'if(_preview distance _factory < (missionNamespace getVariable ["WFBE_C_FORTIF_PACK_FACTORY_CLEARANCE", 3])) then {_color = _colorRed};' in ring_block[guard_idx:]
    assert 'if(_preview distance _factory < _p*(_lx min _ly)) then {_color = _colorRed};' in ring_block[guard_idx:]


def test_fortif_pack_factory_clearance_flag_registered_append_only_and_small() -> None:
    """Registered via the repo's isNil-guard idiom; the default must be a small, fixed
    metres value (a literal geometry-overlap guard), never the factory-footprint-scaled
    formula it replaces for these 5 items."""
    constants = INIT_COMMON_CONSTANTS.read_text(encoding="utf-8-sig")
    m = re.search(
        r'if\s*\(isNil\s*"WFBE_C_FORTIF_PACK_FACTORY_CLEARANCE"\)\s*then\s*\{\s*WFBE_C_FORTIF_PACK_FACTORY_CLEARANCE\s*=\s*([\d.]+)\s*\}',
        constants,
    )
    assert m is not None, "WFBE_C_FORTIF_PACK_FACTORY_CLEARANCE must be registered append-only style (isNil guard)"
    value = float(m.group(1))
    assert 0 < value <= 10, "clearance must be a small geometry-overlap guard, not a base-avoidance buffer"


def test_fortif_pack_preview_classes_is_the_documented_five_item_subset() -> None:
    """WFBE_FORTIF_PACK_PREVIEW_CLASSES must contain exactly the 5 large Fortification Pack
    representative classnames (Wall Row, Wall Corner, LoS Screen, HESCO Line, Gate Complex)
    and deliberately exclude the 2 compact, pre-existing anchors (Hedgehog Line, Flak Tower)."""
    constants = INIT_COMMON_CONSTANTS.read_text(encoding="utf-8-sig")
    m = re.search(r"WFBE_FORTIF_PACK_PREVIEW_CLASSES\s*=\s*\[(.*?)\];", constants)
    assert m is not None, "WFBE_FORTIF_PACK_PREVIEW_CLASSES array not found in Init_CommonConstants.sqf"
    classes = set(re.findall(r"'([^']+)'", m.group(1)))

    expected = {
        "Concrete_Wall_EP1",
        "Base_WarfareBBarrier5x",
        "Base_WarfareBBarrier10x",
        "Land_HBarrier_large",
        "Land_CncBlock_Stripes",
    }
    assert classes == expected, "unexpected WFBE_FORTIF_PACK_PREVIEW_CLASSES membership: %s" % (classes ^ expected)
    assert "Hedgehog_EP1" not in classes and "Land_Ind_IlluminantTower" not in classes


def test_exemption_comment_documents_the_server_side_backstop() -> None:
    code = INIT_CLIENT.read_text(encoding="utf-8-sig")
    guard_idx = code.index('if !((typeOf _preview) in WFBE_ANCHOR_PREVIEW_CLASSES) then {')
    preceding_comment = code[max(0, guard_idx - 1200) : guard_idx]
    assert "WFBE_C_WDDM_COMP_CAP" in preceding_comment
    assert "RequestDefense.sqf" in preceding_comment


if __name__ == "__main__":
    test_anchor_preview_classes_built_with_foreach_not_apply()
    test_exemption_wraps_only_the_two_proximity_checks_not_the_factory_ring()
    test_factory_ring_check_has_no_broad_anchor_exemption_of_its_own()
    test_factory_ring_relaxation_keeps_the_original_clearance_for_everything_else()
    test_fortif_pack_factory_clearance_flag_registered_append_only_and_small()
    test_fortif_pack_preview_classes_is_the_documented_five_item_subset()
    test_exemption_comment_documents_the_server_side_backstop()
    print("fortification preview-class proximity exemption regression check passed")
