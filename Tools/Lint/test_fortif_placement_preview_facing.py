"""Regression contract for the fortification placement/preview/facing fix package
(owner live report 2026-08-04: "The issue is placement, preview, facing direction
indications" for defense/fortification building).

Covers, behaviorally (structure/invariants, not implementation-literal diffs):
  1. WFBE_ANCHOR_PREVIEW_MAP is well-formed, pairwise-distinct, and every representative
     classname is already used elsewhere in the mission tree (no unverified classnames).
  2. coin_interface.sqf's ghost-preview lookup still falls back to the raw anchor
     classname unconditionally, and only OVERRIDES that result behind a numeric flag gate
     placed after the fallback (so flag-off is behaviorally unchanged).
  3. Placement rotation is tick-scaled (multiplies by the poll-sleep interval, not a raw
     per-frame mouse-delta signal) and lives in the "existing preview" branch, gated by
     its own numeric flag.
  4. The no-preview failure path gives the player visible feedback before the silent
     selection-drop, using the item's already-computed WFBE label.
  5. The placement tooltip header sources its label from the same WFBE-label variable
     the buy-menu button uses, not a re-derived stock CfgVehicles displayName.
  6. All edited files stay byte-identical across the Chernarus/Takistan/Zargabad mirrors.
"""

import re
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
CH = MISSION_ROOTS[0]

COIN_INTERFACE = "Client/Module/CoIn/coin_interface.sqf"
COMMON_CONSTANTS = "Common/Init/Init_CommonConstants.sqf"
DEFENSES_INIT = "Server/Init/Init_Defenses.sqf"


def _read(mission_root: Path, rel: str) -> str:
    return (mission_root / rel).read_text(encoding="utf-8-sig")


def _masked(mission_root: Path, rel: str) -> str:
    return mask_comments(_read(mission_root, rel))


def _anchor_preview_pairs(masked_constants: str) -> list[tuple[str, str]]:
    m = re.search(r"WFBE_ANCHOR_PREVIEW_MAP\s*=\s*\[(.*?)\];", masked_constants, re.DOTALL)
    assert m is not None, "WFBE_ANCHOR_PREVIEW_MAP array not found in Init_CommonConstants.sqf"
    body = m.group(1)
    pairs = re.findall(r"\[\s*'([^']+)'\s*,\s*'([^']+)'\s*\]", body)
    assert pairs, "WFBE_ANCHOR_PREVIEW_MAP parsed to zero entries"
    return pairs


# ---------------------------------------------------------------------------
# 1. WFBE_ANCHOR_PREVIEW_MAP structure + flag registration
# ---------------------------------------------------------------------------

def test_anchor_preview_map_flag_registered_append_only():
    """Registered via the repo's isNil-guard idiom with a 0/1 boolean-style default -
    arm-state agnostic (this flag may be armed to 1 in a later commit; the append-only
    REGISTRATION shape is what must never change)."""
    constants = _masked(CH, COMMON_CONSTANTS)
    m = re.search(
        r'if\s*\(isNil\s*"WFBE_C_DEF_PREVIEW_MAP"\)\s*then\s*\{\s*WFBE_C_DEF_PREVIEW_MAP\s*=\s*([01])\s*\}',
        constants,
    )
    assert m is not None, "WFBE_C_DEF_PREVIEW_MAP must be registered append-only style (isNil guard, 0/1 default)"


def test_anchor_preview_map_entries_are_pairwise_distinct():
    constants = _masked(CH, COMMON_CONSTANTS)
    pairs = _anchor_preview_pairs(constants)

    anchors = [a for a, _ in pairs]
    previews = [p for _, p in pairs]

    assert len(anchors) == len(set(anchors)), "duplicate anchor classname in preview map"
    assert len(previews) == len(set(previews)), (
        "preview classnames must be pairwise-distinct so the respawn check "
        "(typeof _preview != _itemclass_preview) still fires when switching items"
    )
    # No representative preview classname may collide with any anchor's own literal
    # classname (including anchors not in this map) - that would also defeat the
    # respawn-detection check for an adjacent buy-menu item.
    assert not (set(previews) & set(anchors)), (
        "a preview classname collides with an anchor classname"
    )


# Anchors whose preview deliberately is NOT a literal child of the composition the
# anchor resolves to. Every entry needs the exact preview classname AND a reason;
# the classname must still be proven content used elsewhere in Init_Defenses.sqf.
REPRESENTATIVE_OK = {
    "Land_Ind_TankSmall": (
        "Land_Ind_IlluminantTower",
        "flak preview host comes from WFBE_C_DEF_FLAKTOWER_STRUCTURE, not a composition array",
    ),
    "Misc_cargo_cont_net2": (
        "Base_WarfareBBarrier5x",
        "composition is 10x Concrete_Wall_EP1, which is already Wall Row's preview - "
        "the pairwise-distinctness rule forbids reuse, so a validated wall segment stands in",
    ),
    "Misc_concrete_High": (
        "Land_CncBlock_Stripes",
        "Land_BarGate2 is A2-only/unverified in this tree (see the Bank-gate precedent "
        "in Init_Defenses.sqf); the proven gate-mouth block stands in",
    ),
}


def test_anchor_preview_targets_resolve_to_their_own_composition_or_allowlist():
    """Each preview classname must be a REAL child of the composition its anchor
    resolves to via WFBE_POSITION_TEMPLATE_MAP - or sit in the explicit, justified
    REPRESENTATIVE_OK allowlist (and still be proven content that Init_Defenses.sqf
    spawns elsewhere). Guards against name-coincidence picks from unrelated
    composition arrays, which a whole-file substring check cannot catch."""
    constants = _masked(CH, COMMON_CONSTANTS)
    defenses = _masked(CH, DEFENSES_INIT)
    pairs = _anchor_preview_pairs(constants)

    template_of = dict(
        re.findall(r"\[\s*'([^']+)'\s*,\s*'(WFBE_NEURODEF_[A-Z0-9_]+)'", defenses)
    )

    for anchor, preview in pairs:
        if anchor in REPRESENTATIVE_OK:
            required, why = REPRESENTATIVE_OK[anchor]
            assert preview == required, (
                "anchor %r is allowlisted with preview %r (%s) but the map now uses %r - "
                "either fix the map or update the allowlist WITH justification"
                % (anchor, required, why, preview)
            )
            assert ("'%s'" % preview) in defenses, (
                "allowlisted preview %r is not proven content - it never appears in "
                "Init_Defenses.sqf" % preview
            )
            continue
        tmpl = template_of.get(anchor)
        assert tmpl is not None, (
            "anchor %r has no WFBE_POSITION_TEMPLATE_MAP binding in Init_Defenses.sqf - "
            "cannot prove its preview classname" % anchor
        )
        # compositions are defined either as `X = [...];` or as
        # `missionNamespace setVariable ['X', [...]];`
        m = re.search(re.escape(tmpl) + r"\s*=\s*\[(.*?)\];", defenses, re.DOTALL)
        if m is None:
            m = re.search(
                r"setVariable\s*\[\s*'" + re.escape(tmpl) + r"'\s*,\s*\[(.*?)\]\s*\]\s*;",
                defenses,
                re.DOTALL,
            )
        assert m is not None, "composition array %s not found in Init_Defenses.sqf" % tmpl
        assert ("'%s'" % preview) in m.group(1), (
            "preview %r (anchor %r) is NOT a child of its own composition %s - "
            "name-coincidence pick from an unrelated array?" % (preview, anchor, tmpl)
        )


def test_anchor_preview_map_covers_the_known_decoy_anchors():
    """Behavior check on WHICH anchors are covered, not on the exact mapping values:
    every anchor the owner's report identified as a cheap decoy prop (cargo containers,
    industrial tank, concrete slab) must have an entry."""
    constants = _masked(CH, COMMON_CONSTANTS)
    pairs = dict(_anchor_preview_pairs(constants))

    decoy_anchors = {
        "Misc_cargo_cont_small",
        "Land_Ind_TankSmall",
        "Misc_cargo_cont_net1",
        "Misc_cargo_cont_net2",
        "Misc_cargo_cont_net3",
        "Misc_cargo_cont_tiny",
        "Misc_concrete_High",
    }
    missing = decoy_anchors - set(pairs.keys())
    assert not missing, "decoy anchors missing a preview-map entry: %s" % sorted(missing)


# ---------------------------------------------------------------------------
# 2. coin_interface.sqf preview lookup: fallback preserved, override flag-gated
# ---------------------------------------------------------------------------

def test_preview_lookup_keeps_the_original_fallback_before_any_override():
    code = _masked(CH, COIN_INTERFACE)

    fallback_match = re.search(
        r'_itemclass_preview\s*=\s*getText\s*\(configFile\s*>>\s*"CfgVehicles"\s*>>\s*_itemclass\s*>>\s*"ghostpreview"\);'
        r'\s*if\s*\(_itemclass_preview\s*==\s*""\)\s*then\s*\{\s*_itemclass_preview\s*=\s*_itemclass\s*\};',
        code,
    )
    assert fallback_match is not None, (
        "original ghostpreview getText + empty-string fallback must remain intact "
        "so flag-off behavior is byte-identical"
    )

    override_match = re.search(
        r'if\s*\(\(missionNamespace getVariable\s*\["WFBE_C_DEF_PREVIEW_MAP",\s*0\]\)\s*>\s*0\)\s*then\s*\{',
        code,
    )
    assert override_match is not None, "preview-map override must be gated by a numeric (>0) flag check"
    assert override_match.start() > fallback_match.end(), (
        "the preview-map override must run AFTER the original fallback assignment, "
        "never before it, so it only ever overrides an already-computed value"
    )

    # The override must look the current _itemclass up generically against the shared
    # map (select 0 / select 1), not hardcode any specific anchor/preview classname.
    override_body = code[override_match.end():override_match.end() + 400]
    assert "_x select 0" in override_body and "_itemclass" in override_body
    assert "_x select 1" in override_body
    assert "WFBE_ANCHOR_PREVIEW_MAP" in override_body


def test_preview_lookup_override_is_a_pure_addition_not_a_replacement():
    """The preview-building/spawn code downstream (createVehicleLocal, cleanup sites)
    must be untouched - the fix is a single lookup-value override, nothing else."""
    code = _masked(CH, COIN_INTERFACE)
    assert code.count("createVehicleLocal (screenToWorld [0.5,0.5])") == 1
    assert code.count("_preview = _itemclass_preview createVehicleLocal") == 1


# ---------------------------------------------------------------------------
# 3. Tick-increment rotation, flag-gated, tick-scaled (never mouse-delta)
# ---------------------------------------------------------------------------

def test_rotation_flag_registered_append_only_with_tunable_rate():
    """Registered via the repo's isNil-guard idiom with a 0/1 boolean-style default -
    arm-state agnostic (this flag may be armed to 1 in a later commit; the append-only
    REGISTRATION shape is what must never change)."""
    constants = _masked(CH, COMMON_CONSTANTS)
    m = re.search(
        r'if\s*\(isNil\s*"WFBE_C_DEF_PLACE_ROTATE"\)\s*then\s*\{\s*WFBE_C_DEF_PLACE_ROTATE\s*=\s*([01])\s*\}',
        constants,
    )
    assert m is not None, "WFBE_C_DEF_PLACE_ROTATE must be registered append-only style (isNil guard, 0/1 default)"

    rate_match = re.search(
        r'if\s*\(isNil\s*"WFBE_C_DEF_PLACE_ROTATE_DEG_SEC"\)\s*then\s*\{\s*WFBE_C_DEF_PLACE_ROTATE_DEG_SEC\s*=\s*([\d.]+)\s*\}',
        constants,
    )
    assert rate_match is not None, "rotation rate tunable must be registered"
    assert float(rate_match.group(1)) > 0, "rotation rate must be a positive degrees/second value"


def test_rotation_is_tick_scaled_not_mouse_delta_and_lives_in_existing_preview_branch():
    code = _masked(CH, COIN_INTERFACE)

    # Locate the branch boundaries: "_new" preview-creation branch closes with
    # "} else {" followed by the zone-distance check where rotation must live.
    # (mask_comments blanks comment TEXT, so anchor on real code, not the
    # "Check zone" comment itself.)
    branch_split = re.search(r"\}\s*else\s*\{", code)
    assert branch_split is not None
    check_zone = re.search(
        r"\(\[position _preview,_startPos\] call BIS_fnc_distance2D\) > _limitH",
        code,
    )
    assert check_zone is not None
    assert check_zone.start() > branch_split.start(), "unexpected branch layout in coin_interface.sqf"

    between = code[branch_split.end():check_zone.start()]

    rotate_gate = re.search(
        r'if\s*\(\(\(missionNamespace getVariable\s*\["WFBE_C_DEF_PLACE_ROTATE",\s*0\]\)\s*>\s*0\)\s*&&\s*_ctrl\)\s*then\s*\{',
        between,
    )
    assert rotate_gate is not None, (
        "rotation must be numeric-flag gated AND require the Ctrl key state (_ctrl), "
        "and must live between the existing-preview branch open and the Check zone comment"
    )

    rotate_body = between[rotate_gate.end():rotate_gate.end() + 300]
    assert "setDir" in rotate_body and "getDir _preview" in rotate_body
    assert "_pollSleep" in rotate_body, "rotation increment must scale by the tick interval (tick-increment, not per-frame mouse-delta)"
    # Never a raw mouse-axis/delta signal - this loop has no such input available.
    for banned in ("mouseDelta", "MouseX", "MouseY", "inputController", "ctrlMapMouse"):
        assert banned.lower() not in rotate_body.lower(), (
            "rotation must not depend on a mouse-delta style input (%s found)" % banned
        )


def test_rotation_forces_a_live_tooltip_refresh_and_readout_is_flag_and_state_gated():
    code = _masked(CH, COIN_INTERFACE)

    rotate_gate = re.search(
        r'if\s*\(\(\(missionNamespace getVariable\s*\["WFBE_C_DEF_PLACE_ROTATE",\s*0\]\)\s*>\s*0\)\s*&&\s*_ctrl\)\s*then\s*\{([^}]*)\}',
        code,
    )
    assert rotate_gate is not None
    assert 'WF_RequestUpdate' in rotate_gate.group(1) and "true" in rotate_gate.group(1), (
        "rotation tick must force WF_RequestUpdate so the cached tooltip text rebuilds "
        "this tick instead of showing a stale heading"
    )

    text1_match = re.search(r"_text1\s*=\s*if\s*\(count _params > 0\).*?;", code, re.DOTALL)
    assert text1_match is not None
    text1 = text1_match.group(0)
    assert "WFBE_C_DEF_PLACE_ROTATE" in text1, "live heading readout must be gated by the same rotation flag"
    assert '_tooltipType == "preview"' in text1, "heading readout must only read _preview while a preview genuinely exists this tick"
    assert "getDir _preview" in text1


# ---------------------------------------------------------------------------
# 4. No-preview failure gives visible player feedback
# ---------------------------------------------------------------------------

def test_no_preview_failure_hints_the_player_before_the_silent_reset():
    code = _masked(CH, COIN_INTERFACE)

    isnull_block = re.search(r"if\s*\(isnull _preview\)\s*then\s*\{(.*?)\n\t\t\t\t\};", code, re.DOTALL)
    assert isnull_block is not None, "could not locate the isnull-preview exception block"
    body = isnull_block.group(1)

    diag_pos = body.find("diag_log")
    hint_pos = re.search(r"\bhint(Silent)?\b", body)
    reset_pos = body.find('_logic setVariable ["BIS_COIN_params",[]]')

    assert diag_pos != -1, "existing diag_log line must be preserved (diagnosability)"
    assert hint_pos is not None, "no-preview failure must produce a player-visible hint/hintSilent"
    assert reset_pos != -1, "existing selection reset must be preserved (flow must still continue)"

    assert diag_pos < hint_pos.start() < reset_pos, (
        "expected order: diag_log (RPT) -> player hint -> selection reset"
    )

    # The hint text must reference the item's WFBE label var, not a bare literal string.
    hint_line_end = body.find(";", hint_pos.start())
    hint_line = body[hint_pos.start():hint_line_end]
    assert "_itemname" in hint_line, "player-facing hint should name the item via _itemname"


# ---------------------------------------------------------------------------
# 5. Tooltip header uses the WFBE label, not a re-derived stock displayName
# ---------------------------------------------------------------------------

def test_tooltip_header_uses_itemname_not_type_displayname():
    code = _masked(CH, COIN_INTERFACE)

    header_block = re.search(
        r'if\s*\(_tooltipType != "empty"\)\s*then\s*\{\s*_textHeader\s*=\s*format\s*\[(.*?)\];',
        code,
        re.DOTALL,
    )
    assert header_block is not None, "could not locate the placement tooltip header format[] call"
    args = header_block.group(1)

    assert "_itemname" in args, "tooltip header must source its label from _itemname (the WFBE buy-menu label)"
    assert 'getText (configFile >> "cfgvehicles" >> _type >> "displayname")' not in args, (
        "tooltip header must not re-derive the stock CfgVehicles displayName"
    )

    # Icon/picture resolution is a separate, deliberately-untouched concern - must still
    # key off _type (the raw anchor classname), not _itemname.
    assert 'configFile >> "cfgvehicles" >> _type >> "icon"' in code
    assert 'configFile >> "cfgvehicles" >> _type >> "picture"' in code


def test_itemname_is_computed_before_the_tooltip_header_uses_it():
    code = _masked(CH, COIN_INTERFACE)
    itemname_def = code.find("_itemname = if (count _params > 3)")
    header_use = code.find('_textHeader = format [')
    assert itemname_def != -1 and header_use != -1
    assert itemname_def < header_use, "_itemname must already be assigned earlier in the same tick"


# ---------------------------------------------------------------------------
# 6. Mirror parity across the three maintained terrains
# ---------------------------------------------------------------------------

def test_edited_files_are_byte_identical_across_terrains():
    for rel in (COIN_INTERFACE, COMMON_CONSTANTS):
        digests = [_read(root, rel) for root in MISSION_ROOTS]
        assert digests[0] == digests[1] == digests[2], "%s drifted between mirrors" % rel


if __name__ == "__main__":
    test_anchor_preview_map_flag_registered_append_only()
    test_anchor_preview_map_entries_are_pairwise_distinct()
    test_anchor_preview_map_targets_are_already_used_in_the_mission_tree()
    test_anchor_preview_map_covers_the_known_decoy_anchors()
    test_preview_lookup_keeps_the_original_fallback_before_any_override()
    test_preview_lookup_override_is_a_pure_addition_not_a_replacement()
    test_rotation_flag_registered_append_only_with_tunable_rate()
    test_rotation_is_tick_scaled_not_mouse_delta_and_lives_in_existing_preview_branch()
    test_rotation_forces_a_live_tooltip_refresh_and_readout_is_flag_and_state_gated()
    test_no_preview_failure_hints_the_player_before_the_silent_reset()
    test_tooltip_header_uses_itemname_not_type_displayname()
    test_itemname_is_computed_before_the_tooltip_header_uses_it()
    test_edited_files_are_byte_identical_across_terrains()
    print("fortif placement/preview/facing contract: PASS")
