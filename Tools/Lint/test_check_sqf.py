#!/usr/bin/env python3
"""Focused regression tests for check_sqf.py.

Run with:
    python Tools/Lint/test_check_sqf.py
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import check_sqf


def lint_codes(source: str) -> list[str]:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        path = root / "sample.sqf"
        path.write_text(source, encoding="utf-8")
        index = check_sqf.build_token_index(root)
        return [finding.code for finding in check_sqf.lint_text(path, source, root, index)]


def lint_codes_flaggate(source: str, added_line_nos: set[int], filename: str = "sample.sqf") -> list[str]:
    """Call lint_flaggate directly and return codes found."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        path = (root / filename).resolve()
        return [f.code for f in check_sqf.lint_flaggate(path, source, added_line_nos)]


class CheckSqfTests(unittest.TestCase):
    def test_a3_prompt_traps_are_case_insensitive(self) -> None:
        codes = lint_codes("_xs pushback 1;\n_d = player distance2d target;\n")
        self.assertGreaterEqual(codes.count("A3CMD"), 2)

    def test_a3_syntax_forms_are_reported(self) -> None:
        codes = lint_codes(
            '"b_inf" setMarkerTypeLocal "b_inf";\n'
            "[player] reveal enemy;\n"
            "_xs = _xs select [0, 2];\n"
            "_xs sort {_x select 0};\n"
        )
        self.assertIn("A3MARKER", codes)
        self.assertIn("A3REVEAL", codes)
        self.assertIn("A3SELECT", codes)
        self.assertIn("A3SORT", codes)

    def test_a3select_code_operand_shapes_are_reported(self) -> None:
        """Lane w807e-L16: A3SELECT previously only matched 'select [' (the
        substring-slice shape) and missed a CODE block used as select's
        operand on either side - the exact shape that killed
        GUI_Menu_Service.sqf's town-service support scan
        ('{alive _x} select (nearEntities[...])')."""
        codes = lint_codes(
            "_checks = {alive _x} select ((getPos _x) nearEntities[_typeRepair, 50]);\n"
            "_alive = _units select {alive _x};\n"
        )
        self.assertEqual(codes.count("A3SELECT"), 2)

    def test_a3select_parenthesized_index_is_not_flagged(self) -> None:
        """Valid A2 idiom: select with a computed/parenthesized scalar index
        must not be flagged - only a CODE block on either side of select is
        the trap."""
        codes = lint_codes(
            "_val = _array select (_i + 1);\n"
            "_val2 = [{doA}, {doB}] select _bool;\n"
        )
        self.assertNotIn("A3SELECT", codes)

    def test_bis_fnc_calls_are_reported_outside_comments_and_strings(self) -> None:
        codes = lint_codes(
            "// _ignored = _xs call BIS_fnc_arrayPush;\n"
            '_alsoIgnored = "call BIS_fnc_areEqual";\n'
            "_pick = _xs call BIS_fnc_selectRandom;\n"
            "_same = [_a, _b] CALL bis_fnc_areEqual;\n"
        )
        self.assertEqual(codes.count("A3BISFNC"), 2)

    def test_group_getvariable_array_form_is_reported(self) -> None:
        codes = lint_codes('_team getVariable ["wfbe_aicom_order", []];\n')
        self.assertIn("GROUPGETVAR", codes)

    def test_string_find_preserves_string_context_but_ignores_comments(self) -> None:
        codes = lint_codes('// "abc" find "b"\n_hit = "abc" find "b";\n')
        self.assertEqual(codes.count("A3STRING"), 1)

    def test_string_typed_constant_numeric_gate_is_reported(self) -> None:
        codes = lint_codes(
            'if ((missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", 0]) > 0) then {};\n'
            "if ((missionNamespace getVariable ['WFBE_C_GUER_KA137_FLARE_LAUNCHER', false])) then {};\n"
            'if ((missionNamespace getVariable [WFBE_C_SPECIAL_CLASS, 0]) > 0) then {};\n'
        )
        self.assertEqual(codes.count("A3NUMGATE"), 3)

    def test_string_typed_constant_numeric_gate_ignores_comments_and_safe_defaults(self) -> None:
        codes = lint_codes(
            '// missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", 0]\n'
            'if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) then {};\n'
            'if ((missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"]) != "") then {};\n'
        )
        self.assertNotIn("A3NUMGATE", codes)

    def test_namespace_three_arg_setvariable_is_reported(self) -> None:
        codes = lint_codes('missionNamespace setVariable ["WFBE_ICBM_STATE", _state, true];\n')
        self.assertIn("NSSETVAR3", codes)

    def test_namespace_setvariable_detection_is_case_insensitive_and_multiline(self) -> None:
        codes = lint_codes(
            'uinamespace setvariable ["wfbe_hud", _hud, false];\n'
            'profileNamespace setVariable [\n\t"wfbe_pref",\n\t_value,\n\ttrue\n];\n'
        )
        self.assertEqual(codes.count("NSSETVAR3"), 2)

    def test_object_three_arg_setvariable_is_not_reported(self) -> None:
        codes = lint_codes('_vehicle setVariable ["wfbe_owner", _uid, true];\n')
        self.assertNotIn("NSSETVAR3", codes)

    def test_namespace_two_arg_with_nested_array_value_is_not_reported(self) -> None:
        codes = lint_codes('missionNamespace setVariable ["k", [_a, _b]];\n')
        self.assertNotIn("NSSETVAR3", codes)

    def test_namespace_two_arg_with_format_value_is_not_reported(self) -> None:
        codes = lint_codes('missionNamespace setVariable ["k", Format ["%1", _v]];\n')
        self.assertNotIn("NSSETVAR3", codes)

    def test_namespace_two_arg_with_parenthesized_expression_value_is_not_reported(self) -> None:
        codes = lint_codes('missionNamespace setVariable ["k", (_a + _b)];\n')
        self.assertNotIn("NSSETVAR3", codes)

    def test_parse_added_lines_from_diff_tracks_new_line_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            diff = (
                "diff --git a/sample.sqf b/sample.sqf\n"
                "--- a/sample.sqf\n"
                "+++ b/sample.sqf\n"
                "@@ -1,2 +1,4 @@\n"
                " private _x;\n"
                '+params ["_unit"];\n'
                " _unit = player;\n"
                "+_items pushBack _unit;\n"
            )
            added = check_sqf.parse_added_lines_from_diff(diff, root)

        self.assertEqual(added[(root / "sample.sqf").resolve()], {2, 4})

    def test_added_line_filter_drops_legacy_findings(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "sample.sqf"
            source = 'params ["_old"];\n_items pushBack player;\n'
            path.write_text(source, encoding="utf-8")
            findings = check_sqf.lint_text(path, source, root, check_sqf.build_token_index(root))
            filtered = check_sqf.filter_findings_to_added_lines(findings, {path.resolve(): {2}})

        self.assertEqual([finding.code for finding in filtered], ["A3CMD"])
    # ── MILMARKER ───────────────────────────────────────────
    def test_milmarker_unknown_type_is_flagged(self) -> None:
        codes = lint_codes('_m setMarkerType "mil_air";')
        self.assertIn("MILMARKER", codes)

    def test_milmarker_valid_type_not_flagged(self) -> None:
        codes = lint_codes('_m setMarkerType "mil_circle";')
        self.assertNotIn("MILMARKER", codes)

    def test_milmarker_case_insensitive_valid(self) -> None:
        codes = lint_codes('_m setMarkerType "MIL_DOT";')
        self.assertNotIn("MILMARKER", codes)

    def test_milmarker_in_comment_not_flagged(self) -> None:
        source = '// the old "mil_air" bug' + chr(10) + '_m setMarkerType "mil_dot";'
        codes = lint_codes(source)
        self.assertNotIn("MILMARKER", codes)

    # ── MARKERTYPE ──────────────────────────────────────────
    def test_markertype_unknown_type_is_flagged(self) -> None:
        codes = lint_codes('_m setMarkerTypeLocal "Depoot";')
        self.assertIn("MARKERTYPE", codes)

    def test_markertype_valid_type_not_flagged(self) -> None:
        codes = lint_codes('_m setMarkerTypeLocal "Depot";')
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_case_insensitive_valid(self) -> None:
        codes = lint_codes('_m setMarkerTypeLocal "STRONGPOINT";')
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_defers_to_milmarker_for_mil_prefix(self) -> None:
        # An invalid mil_ type is MILMARKER's job; MARKERTYPE must not double-report it.
        codes = lint_codes('_m setMarkerType "mil_air";')
        self.assertIn("MILMARKER", codes)
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_defers_to_a3marker_for_nato_prefix(self) -> None:
        # b_/o_/n_ NATO markers are A3MARKER's job; MARKERTYPE must not double-report them.
        codes = lint_codes('_m setMarkerTypeLocal "b_inf";')
        self.assertIn("A3MARKER", codes)
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_getvariable_default_typo_is_flagged(self) -> None:
        codes = lint_codes(
            '_x setMarkerType (missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_TYPE", "mil_circlee"]);'
        )
        # The typo is mil_-prefixed, so MILMARKER's own bare-literal scan catches it too;
        # MARKERTYPE must defer rather than double-report.
        self.assertIn("MILMARKER", codes)
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_getvariable_default_non_mil_typo_is_flagged(self) -> None:
        codes = lint_codes(
            '_x setMarkerType (missionNamespace getVariable ["WFBE_C_TEST_MARKER_TYPE", "Depoot"]);'
        )
        self.assertIn("MARKERTYPE", codes)

    def test_markertype_const_assignment_typo_is_flagged(self) -> None:
        codes = lint_codes('WFBE_C_TEST_MARKER_TYPE = "Depoot";')
        self.assertIn("MARKERTYPE", codes)

    def test_markertype_variable_indirection_is_out_of_reach(self) -> None:
        # Documents a known, accepted limitation: a literal assigned to a plain local
        # variable before use is not visible to this rule (see Tools/Lint/README.md).
        codes = lint_codes('_type = "NotARealMarkerType"; _m setMarkerTypeLocal _type;')
        self.assertNotIn("MARKERTYPE", codes)

    def test_markertype_in_comment_not_flagged(self) -> None:
        source = '// the old "Depoot" bug' + chr(10) + '_m setMarkerTypeLocal "Depot";'
        codes = lint_codes(source)
        self.assertNotIn("MARKERTYPE", codes)

    # ── MARKERCOLOR ─────────────────────────────────────────
    def test_markercolor_unknown_color_is_flagged(self) -> None:
        codes = lint_codes('_m setMarkerColorLocal "ColorKhakiy";')
        self.assertIn("MARKERCOLOR", codes)

    def test_markercolor_valid_color_not_flagged(self) -> None:
        codes = lint_codes('_m setMarkerColorLocal "ColorRed";')
        self.assertNotIn("MARKERCOLOR", codes)

    def test_markercolor_khaki_is_allowlisted(self) -> None:
        # Carried forward from a prior classname audit's unconfirmed flag - see Tools/Lint/README.md.
        codes = lint_codes('_m setMarkerColorLocal "ColorKhaki";')
        self.assertNotIn("MARKERCOLOR", codes)

    def test_markercolor_unrelated_ppeffect_not_flagged(self) -> None:
        # ppEffectCreate ["ColorCorrections", ...] is a post-process effect, not a marker
        # color, and is never a direct setMarkerColor(Local) argument - must stay silent.
        codes = lint_codes('_ppColor = ppEffectCreate ["ColorCorrections", 1999];')
        self.assertNotIn("MARKERCOLOR", codes)

    # ── A3PRIVATE ─────────────────────────────────────────────────────────────
    def test_a3private_inline_is_flagged(self) -> None:
        codes = lint_codes('private _myVar = 0;\n')
        self.assertIn("A3PRIVATE", codes)

    def test_a3private_list_form_not_flagged(self) -> None:
        codes = lint_codes('private ["_myVar"];\n_myVar = 0;\n')
        self.assertNotIn("A3PRIVATE", codes)

    def test_a3private_in_comment_not_flagged(self) -> None:
        # comment-masked: "private _x = 1" inside a comment must not fire
        codes = lint_codes('// private _x = 1\n_x = 1;\n')
        self.assertNotIn("A3PRIVATE", codes)

    def test_a3private_in_string_not_flagged(self) -> None:
        codes = lint_codes('"private _x = 1";\n')
        self.assertNotIn("A3PRIVATE", codes)

    def test_a3private_multiple_in_same_file(self) -> None:
        codes = lint_codes('private _a = 1;\nprivate _b = 2;\n')
        self.assertGreaterEqual(codes.count("A3PRIVATE"), 2)

    # ── A3HASH ────────────────────────────────────────────────────────────────
    def test_a3hash_array_selector_is_flagged(self) -> None:
        codes = lint_codes('_val = _arr # 0;\n')
        self.assertIn("A3HASH", codes)

    def test_a3hash_paren_selector_is_flagged(self) -> None:
        codes = lint_codes('_val = (getArray ...) # 2;\n')
        self.assertIn("A3HASH", codes)

    def test_a3hash_bracket_selector_is_flagged(self) -> None:
        codes = lint_codes('_val = _arr # _idx;\n')
        self.assertIn("A3HASH", codes)

    def test_a3hash_preprocessor_define_not_flagged(self) -> None:
        codes = lint_codes('#define MY_CONST 1\n')
        self.assertNotIn("A3HASH", codes)

    def test_a3hash_preprocessor_include_not_flagged(self) -> None:
        codes = lint_codes('#include "common.hpp"\n')
        self.assertNotIn("A3HASH", codes)

    def test_a3hash_preprocessor_ifdef_not_flagged(self) -> None:
        codes = lint_codes('#ifdef WF_DEBUG\n_x = 1;\n#endif\n')
        self.assertNotIn("A3HASH", codes)

    def test_a3hash_double_hash_token_paste_not_flagged(self) -> None:
        # ## inside a macro body should not fire
        codes = lint_codes('#define CONCAT(a,b) a##b\n')
        self.assertNotIn("A3HASH", codes)

    def test_a3hash_in_comment_not_flagged(self) -> None:
        codes = lint_codes('// _arr # 0 means select element 0\n_val = 1;\n')
        self.assertNotIn("A3HASH", codes)

    # ── A3_TRAPS additions ────────────────────────────────────────────────────
    def test_new_a3_traps_are_flagged(self) -> None:
        src = (
            '_x = _map getOrDefault ["key", 0];\n'
            '_map deleteAt "key";\n'
            'player setUnitLoadout _load;\n'
            '_load = getUnitLoadout player;\n'
            '_x = selectRandomWeighted [1,2,3,[0.1,0.2,0.7]];\n'
            '_m = _str regexFind ["\\d+"];\n'
            'remoteExecCall ["fn", 0];\n'
        )
        codes = lint_codes(src)
        self.assertGreaterEqual(codes.count("A3CMD"), 7)

    # ── A3_TRAPS: allPlayers gap closure (PR #1915 review) ─────────────────────
    def test_allplayers_and_siblings_are_flagged(self) -> None:
        """allPlayers shipped in PR #1915 uncaught; close it and its A3-only
        siblings surfaced by the same audit (BI wiki 'Introduced with Arma 3',
        no A2/OA scripting-commands category entry)."""
        src = (
            "_x = allPlayers;\n"
            "_y = allUnitsUAV;\n"
            "_z = allDeadMen;\n"
            "_w = allSites;\n"
            "_v = allMines;\n"
            "_u = curatorCamera;\n"
            '_t = getUnitTrait [player, "engineer"];\n'
            'setUnitTrait [player, "engineer", true];\n'
            "_s = addForce [[0,0,1],[0,0,0]];\n"
            "_r = getPlayerScores player;\n"
        )
        codes = lint_codes(src)
        self.assertEqual(codes.count("A3CMD"), 10)

    def test_alldead_is_not_flagged_a2oa_safe_sibling_of_alldeadmen(self) -> None:
        """`allDead` (A2 OA 1.57+) must never be confused with the A3-only
        `allDeadMen` (Arma 3 0.50) - only the latter is a trap."""
        codes = lint_codes("_d = allDead;\n")
        self.assertNotIn("A3CMD", codes)

    def test_playernumber_idioms_are_not_flagged_a2oa_safe(self) -> None:
        """playersNumber / playableUnits predate Arma 3 and are the A2/OA-safe
        replacements for allPlayers; they must never be flagged."""
        codes = lint_codes('_n = playersNumber west;\n_p = playableUnits;\n')
        self.assertNotIn("A3CMD", codes)

    def test_allplayers_noqa_suppresses(self) -> None:
        codes = lint_codes("_x = allPlayers;  // noqa: A3CMD\n")
        self.assertNotIn("A3CMD", codes)

    # ── BAREEXIT ────────────────────────────────────────────────────────────────
    def test_bareexit_bare_statement_start_is_flagged(self) -> None:
        codes = lint_codes("if (true) then { exitWith {1} };\n")
        self.assertIn("BAREEXIT", codes)

    def test_bareexit_after_semicolon_is_flagged(self) -> None:
        codes = lint_codes("_x = 1; exitWith {_x};\n")
        self.assertIn("BAREEXIT", codes)

    def test_bareexit_directly_after_if_paren_is_not_flagged(self) -> None:
        codes = lint_codes("if (_x > 0) exitWith {_x};\n")
        self.assertNotIn("BAREEXIT", codes)

    def test_bareexit_in_comment_not_flagged(self) -> None:
        codes = lint_codes("// exitWith {1}\n_x = 1;\n")
        self.assertNotIn("BAREEXIT", codes)

    # ── PUBVARSV ──────────────────────────────────────────────────────────────
    def test_pubvarsv_in_server_file_is_flagged(self) -> None:
        """publicVariableServer inside a /Server/ path should fire PUBVARSV."""
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = check_sqf.Path(tmp)
            server_dir = root / "Missions" / "test.chernarus" / "Server" / "Functions"
            server_dir.mkdir(parents=True)
            path = server_dir / "Server_Foo.sqf"
            src = 'publicVariableServer "ATTACK_WAVE_DETAILS";\n'
            path.write_text(src, encoding="utf-8")
            index = check_sqf.build_token_index(root)
            findings = check_sqf.lint_text(path, src, root, index)
            codes = [f.code for f in findings]
        self.assertIn("PUBVARSV", codes)

    def test_pubvarsv_not_flagged_outside_server(self) -> None:
        """publicVariableServer in a client file must NOT fire PUBVARSV."""
        codes = lint_codes('publicVariableServer "WFBE_CLIENT_CONNECTED";\n')
        self.assertNotIn("PUBVARSV", codes)

    def test_pubvarsv_in_comment_in_server_file_not_flagged(self) -> None:
        """publicVariableServer only in a comment inside a Server/ path must not fire."""
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = check_sqf.Path(tmp)
            server_dir = root / "Server" / "Functions"
            server_dir.mkdir(parents=True)
            path = server_dir / "Server_Foo.sqf"
            src = '// publicVariableServer "ATTACK_WAVE_DETAILS" — old code, do not use\n_x = 1;\n'
            path.write_text(src, encoding="utf-8")
            index = check_sqf.build_token_index(root)
            findings = check_sqf.lint_text(path, src, root, index)
            codes = [f.code for f in findings]
        self.assertNotIn("PUBVARSV", codes)

    # ── BOOLCMP narrowed scope ─────────────────────────────────────────────────
    def test_boolcmp_equals_true_is_flagged(self) -> None:
        codes = lint_codes('if (_flag == true) then {};\n')
        self.assertIn("BOOLCMP", codes)

    def test_boolcmp_not_equals_false_is_flagged(self) -> None:
        codes = lint_codes('if (_state != false) then {};\n')
        self.assertIn("BOOLCMP", codes)

    def test_boolcmp_numeric_comparison_not_flagged(self) -> None:
        # Comparing numbers should no longer trigger BOOLCMP
        codes = lint_codes('if (_count == 0) then {};\n')
        self.assertNotIn("BOOLCMP", codes)

    def test_boolcmp_string_comparison_not_flagged(self) -> None:
        codes = lint_codes('if (_mode == "active") then {};\n')
        self.assertNotIn("BOOLCMP", codes)

    def test_boolcmp_waituntil_equals_true_is_flagged(self) -> None:
        codes = lint_codes('waitUntil { _done == true };\n')
        self.assertIn("BOOLCMP", codes)

    # ── NOQA per-line suppression ─────────────────────────────────────────────

    def test_noqa_coded_a3cmd_suppresses_params(self) -> None:
        # params; // noqa: A3CMD -> no A3CMD
        codes = lint_codes('params;  // noqa: A3CMD\n')
        self.assertNotIn("A3CMD", codes)

    def test_noqa_bare_suppresses_all_findings(self) -> None:
        # params; // noqa -> no findings at all on that line
        codes = lint_codes('params;  // noqa\n')
        self.assertNotIn("A3CMD", codes)

    def test_noqa_wrong_code_does_not_suppress_a3cmd(self) -> None:
        # params; // noqa: BRACKET -> A3CMD still fires (wrong code named)
        codes = lint_codes('params;  // noqa: BRACKET\n')
        self.assertIn("A3CMD", codes)

    def test_noqa_wrong_code_emits_deadnoqa(self) -> None:
        # params; // noqa: BRACKET -> DEADNOQA fires because BRACKET didn't fire
        codes = lint_codes('params;  // noqa: BRACKET\n')
        self.assertIn("DEADNOQA", codes)

    def test_noqa_coded_a3private_suppresses_inline_private(self) -> None:
        # private _x = 0; // noqa: A3PRIVATE -> no A3PRIVATE
        codes = lint_codes('private _x = 0;  // noqa: A3PRIVATE\n')
        self.assertNotIn("A3PRIVATE", codes)

    def test_noqa_absent_line_still_fires_normally(self) -> None:
        # regression: a line with no noqa still fires normally
        codes = lint_codes('params;\n')
        self.assertIn("A3CMD", codes)

    def test_noqa_correct_suppression_does_not_emit_deadnoqa(self) -> None:
        # params; // noqa: A3CMD -> A3CMD suppressed, no DEADNOQA
        codes = lint_codes('params;  // noqa: A3CMD\n')
        self.assertNotIn("DEADNOQA", codes)

    def test_noqa_bare_never_emits_deadnoqa(self) -> None:
        # bare // noqa -> never DEADNOQA even when no finding fires
        codes = lint_codes('_x = 1;  // noqa\n')
        self.assertNotIn("DEADNOQA", codes)

    def test_noqa_works_in_hpp_file(self) -> None:
        """// noqa: A3CMD suppresses A3CMD in .hpp files too."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "Parameters.hpp"
            src = '\tclass Params {  // noqa: A3CMD\n}\n'
            path.write_text(src, encoding="utf-8")
            index = check_sqf.build_token_index(root)
            findings = check_sqf.lint_text(path, src, root, index)
            codes = [f.code for f in findings]
        self.assertNotIn("A3CMD", codes)


    # ── FLAGGATE diff-mode rule ───────────────────────────────────────────────

    def test_flaggate_unguarded_read_fires(self) -> None:
        # Bare missionNamespace getVariable ["WFBE_C_FOO", 0] without guard -> FLAGGATE
        src = '_v = missionNamespace getVariable ["WFBE_C_FOO", 0];\n'
        codes = lint_codes_flaggate(src, {1})
        self.assertIn("FLAGGATE", codes)

    def test_flaggate_guarded_gt_zero_suppresses(self) -> None:
        # > 0 guard on same line -> no FLAGGATE
        src = 'if (missionNamespace getVariable ["WFBE_C_FOO", 0] > 0) then {};\n'
        codes = lint_codes_flaggate(src, {1})
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_silent_in_full_tree_mode(self) -> None:
        # FLAGGATE must NOT fire from lint_text alone (no diff mode, no added_line_nos)
        src = '_v = missionNamespace getVariable ["WFBE_C_FOO", 0];\n'
        codes = lint_codes(src)
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_silent_for_non_added_line(self) -> None:
        # Same bare read but line NOT in added_line_nos -> no FLAGGATE
        src = '_v = missionNamespace getVariable ["WFBE_C_FOO", 0];\n'
        codes = lint_codes_flaggate(src, set())
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_silent_for_non_wfbe_c_var(self) -> None:
        # getVariable with a non-WFBE_C_ key should not fire FLAGGATE
        src = '_v = missionNamespace getVariable ["someOtherVar", 0];\n'
        codes = lint_codes_flaggate(src, {1})
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_silent_in_init_commonconstants(self) -> None:
        # Init_CommonConstants.sqf is excluded (flag definitions live there)
        src = 'if (isNil "WFBE_C_FOO") then { missionNamespace getVariable ["WFBE_C_FOO", 0] };\n'
        codes = lint_codes_flaggate(src, {1}, filename="Init_CommonConstants.sqf")
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_ne_guard_suppresses(self) -> None:
        # != 0 guard on same line -> no FLAGGATE
        src = 'if (missionNamespace getVariable ["WFBE_C_FOO", 0] != 0) then {};\n'
        codes = lint_codes_flaggate(src, {1})
        self.assertNotIn("FLAGGATE", codes)

    def test_flaggate_eq1_guard_suppresses(self) -> None:
        # == 1 guard on same line -> no FLAGGATE
        src = 'if (missionNamespace getVariable ["WFBE_C_FOO", 0] == 1) then {};\n'
        codes = lint_codes_flaggate(src, {1})
        self.assertNotIn("FLAGGATE", codes)

    # ── TRAILCOMMA trailing comma before ] ────────────────────────────────────

    def test_trailcomma_same_line_is_flagged(self) -> None:
        codes = lint_codes('_arr = [1, 2,];\n')
        self.assertIn("TRAILCOMMA", codes)

    def test_trailcomma_newline_before_close_is_flagged(self) -> None:
        codes = lint_codes('_arr = [\n\t1,\n\t2,\n];\n')
        self.assertIn("TRAILCOMMA", codes)

    def test_trailcomma_line_comment_between_is_flagged(self) -> None:
        # PR #801 incident shape: comma left on the new last element, //--- comment,
        # then the closing bracket. Preprocessor strips the comment -> runtime ",]".
        src = '_map = [\n\t["fort", true],\t//--- last element\n];\n'
        codes = lint_codes(src)
        self.assertIn("TRAILCOMMA", codes)

    def test_trailcomma_block_comment_between_is_flagged(self) -> None:
        codes = lint_codes('_arr = [1, 2, /* tail */ ];\n')
        self.assertIn("TRAILCOMMA", codes)

    def test_trailcomma_valid_array_not_flagged(self) -> None:
        codes = lint_codes('_arr = [1, 2];\n_nested = [[1, 2], [3, 4]];\n')
        self.assertNotIn("TRAILCOMMA", codes)

    def test_trailcomma_string_last_element_not_flagged(self) -> None:
        # Masking must not blank the string to whitespace: [1, "two"] is valid.
        codes = lint_codes('_a = [1, "two"];\n_b = ["x", \'y\'];\n_c = [1, ""];\n_d = [1, "a""b"];\n')
        self.assertNotIn("TRAILCOMMA", codes)

    def test_trailcomma_in_string_not_flagged(self) -> None:
        codes = lint_codes('_s = "a,]";\n_t = \'b,]\';\n_u = "a, ]";\n')
        self.assertNotIn("TRAILCOMMA", codes)

    def test_trailcomma_in_comment_only_not_flagged(self) -> None:
        codes = lint_codes('// old shape was [1, 2,]\n/* and [3,] too */\n_x = 1;\n')
        self.assertNotIn("TRAILCOMMA", codes)

    def test_trailcomma_noqa_suppresses(self) -> None:
        codes = lint_codes('_arr = [1, 2,];  // noqa: TRAILCOMMA\n')
        self.assertNotIn("TRAILCOMMA", codes)

    # ── DBLBOM double / stray UTF-8 BOM ───────────────────────────────────────

    def test_dblbom_double_leading_bom_is_flagged(self) -> None:
        # The 2026-07-07 RC20/RC22 incident shape: EF BB BF EF BB BF at byte 0
        # nil'd the whole constants layer via a line-1 parse failure.
        codes = lint_codes("\ufeff\ufeffWFBE_C_FOO = 1;\n")
        self.assertIn("DBLBOM", codes)

    def test_dblbom_single_leading_bom_not_flagged(self) -> None:
        # A single leading BOM is the tolerated legacy state (27 files carry one).
        codes = lint_codes("\ufeff_x = 1;\n")
        self.assertNotIn("DBLBOM", codes)

    def test_dblbom_no_bom_not_flagged(self) -> None:
        codes = lint_codes("_x = 1;\n")
        self.assertNotIn("DBLBOM", codes)

    def test_dblbom_triple_leading_bom_flags_each_extra(self) -> None:
        codes = lint_codes("\ufeff\ufeff\ufeff_x = 1;\n")
        self.assertEqual(codes.count("DBLBOM"), 2)

    def test_dblbom_mid_file_bom_is_flagged_with_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "sample.sqf"
            src = "_x = 1;\n\ufeff_y = 2;\n"
            path.write_text(src, encoding="utf-8")
            findings = [f for f in check_sqf.lint_text(path, src, root, {}) if f.code == "DBLBOM"]
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].line, 2)

    def test_dblbom_bom_inside_string_literal_is_flagged(self) -> None:
        # Must scan RAW text: comment/string masking would blank a BOM hiding
        # inside a literal, but the physical bytes still corrupt the file.
        codes = lint_codes('_s = "a\ufeffb";\n')
        self.assertIn("DBLBOM", codes)

    def test_dblbom_in_hpp_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "Parameters.hpp"
            src = "\ufeff\ufeffclass Params {};\n"
            path.write_text(src, encoding="utf-8")
            findings = check_sqf.lint_text(path, src, root, {})
        self.assertIn("DBLBOM", [f.code for f in findings])

    def test_dblbom_noqa_suppresses(self) -> None:
        codes = lint_codes("\ufeff\ufeff_x = 1;  // noqa: DBLBOM\n")
        self.assertNotIn("DBLBOM", codes)

    # \u2500\u2500 QUOTEPARITY unterminated double-quoted string \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

    def test_quoteparity_clean_line_not_flagged(self) -> None:
        codes = lint_codes('_x = "hello world";\n')
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_doubled_escape_not_flagged(self) -> None:
        # A2's in-string escaped quote ("") must not be read as close+reopen.
        codes = lint_codes('_x = "She said ""Hi"" to him";\n')
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_line_comment_holding_quote_not_flagged(self) -> None:
        # The lone " inside a // comment never reaches string-tracking because
        # // consumes to EOL first.
        codes = lint_codes('_x = 1; // note: uses " like this\n')
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_block_comment_multiline_quote_not_flagged(self) -> None:
        # A /* ... */ block spanning multiple lines with a lone " inside must
        # stay inert: the in_block branch is checked before string-open logic.
        codes = lint_codes('_x = 1;\n/* comment\n uses " character\n spanning lines */\n_y = 2;\n')
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_unbalanced_is_flagged(self) -> None:
        # A genuinely unterminated " string must FAIL - this is the automation
        # of the rule that killed wave0807a2.
        codes = lint_codes('_x = "unterminated string;\n_y = 2;\n')
        self.assertIn("QUOTEPARITY", codes)

    def test_quoteparity_only_quote_inside_comment_not_flagged(self) -> None:
        # The only quote in the file lives inside a // comment; the file has
        # no real open " string, so QUOTEPARITY must stay silent.
        codes = lint_codes('// the value was "unset"\n_x = 1;\n')
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_dquote_inside_squote_string_not_flagged(self) -> None:
        # A " inside a '...'-delimited string is ordinary content, not a
        # delimiter - both quote types are tracked so this stays inert.
        codes = lint_codes("_x = 'He said \" hi \"';\n")
        self.assertNotIn("QUOTEPARITY", codes)

    def test_quoteparity_reports_open_quote_position(self) -> None:
        # The finding must point at the opening " of the never-closed string,
        # not at EOF or the following line.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "sample.sqf"
            src = '_x = "unterminated string;\n_y = 2;\n'
            path.write_text(src, encoding="utf-8")
            findings = [f for f in check_sqf.lint_text(path, src, root, {}) if f.code == "QUOTEPARITY"]
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].line, 1)
        self.assertEqual(findings[0].col, 6)

    def test_quoteparity_noqa_suppresses(self) -> None:
        codes = lint_codes('_x = "unterminated string;  // noqa: QUOTEPARITY\n_y = 2;\n')
        self.assertNotIn("QUOTEPARITY", codes)


class BuyMenuUpgradeRefreshTests(unittest.TestCase):
    """The open shop must rebuild its catalogue after a replicated tech change."""

    PATHS = (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_BuyUnits.sqf"),
        Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_Menu_BuyUnits.sqf"),
        Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_Menu_BuyUnits.sqf"),
    )
    SNAPSHOT = "_shopUpgradesSeen = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;"
    # 2026-08-03: the original contract asserted `if (!(_shopUpgrades in [_shopUpgradesSeen]))`.
    # On A2 OA `in` compares arrays BY REFERENCE, so that test was true on every loop pass and the
    # shop rebuilt continuously - the player's selection snapped back to the top of the list on
    # every click (owner-reported live regression). The contract is now the value comparison.
    REFRESH = "if ((str _shopUpgrades) != (str _shopUpgradesSeen)) then {_shopUpgradesSeen = _shopUpgrades + []; _update = true};"
    FORBIDDEN_REFRESH = "_shopUpgrades in [_shopUpgradesSeen]"

    def test_shop_rebuilds_after_side_upgrade_changes(self) -> None:
        root = Path(__file__).resolve().parents[2]
        for relative_path in self.PATHS:
            source = (root / relative_path).read_text(encoding="utf-8")
            self.assertIn(self.SNAPSHOT, source, relative_path)
            self.assertIn(self.REFRESH, source, relative_path)
            # Reference-comparison form must never come back: it forces a rebuild every pass.
            self.assertNotIn(self.FORBIDDEN_REFRESH, source, relative_path)
            self.assertLess(source.index(self.REFRESH), source.index("//--- Update tabs."), relative_path)


class JipCivLatchOrderTests(unittest.TestCase):
    CONNECT_PATHS = (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_OnPlayerConnected.sqf"),
        Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_OnPlayerConnected.sqf"),
        Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_OnPlayerConnected.sqf"),
        Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Server/Functions/Server_OnPlayerConnected.sqf"),
    )
    LATCH_GUARD = 'if (!isNil "_jipLatch" && {(time - _jipLatch) < 15}) exitWith {'
    CIV_DEFER = 'if (str _sideJoined == "CIV") exitWith {'
    LATCH_WRITE = 'missionNamespace setVariable [format["WFBE_JIP_LATCH%1", _uid], time];'
    FIRST_JOIN = "if (isNil '_get') exitWith {"

    def test_unresolved_side_bails_before_writing_jip_latch(self) -> None:
        root = Path(__file__).resolve().parents[2]

        for relative_path in self.CONNECT_PATHS:
            text = (root / relative_path).read_text(encoding="utf-8")
            anchors = (
                self.LATCH_GUARD,
                self.CIV_DEFER,
                self.LATCH_WRITE,
                self.FIRST_JOIN,
            )

            for anchor in anchors:
                self.assertEqual(text.count(anchor), 1, f"unexpected anchor count in {relative_path}")

            positions = tuple(text.index(anchor) for anchor in anchors)
            self.assertEqual(
                positions,
                tuple(sorted(positions)),
                f"JIP latch order is unsafe in {relative_path}",
            )


if __name__ == "__main__":
    unittest.main()
