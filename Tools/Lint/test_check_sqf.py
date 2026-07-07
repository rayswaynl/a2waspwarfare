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


if __name__ == "__main__":
    unittest.main()
