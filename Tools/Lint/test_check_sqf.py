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

    def test_group_getvariable_array_form_is_reported(self) -> None:
        codes = lint_codes('_team getVariable ["wfbe_aicom_order", []];\n')
        self.assertIn("GROUPGETVAR", codes)

    def test_string_find_preserves_string_context_but_ignores_comments(self) -> None:
        codes = lint_codes('// "abc" find "b"\n_hit = "abc" find "b";\n')
        self.assertEqual(codes.count("A3STRING"), 1)

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
                "+params [\"_unit\"];\n"
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


if __name__ == "__main__":
    unittest.main()
