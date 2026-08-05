#!/usr/bin/env python3
"""Regression tests for context-aware A3 marker linting.

Run with:
    python Tools/Lint/test_a3_marker_context.py
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


class A3MarkerContextTests(unittest.TestCase):
    def test_marker_type_argument_is_reported(self) -> None:
        codes = lint_codes('_marker setMarkerType "b_inf";\n')
        self.assertIn("A3MARKER", codes)

    def test_local_marker_type_argument_is_reported(self) -> None:
        codes = lint_codes('_marker setMarkerTypeLocal "o_inf";\n')
        self.assertIn("A3MARKER", codes)

    def test_ammo_class_strings_are_not_reported_as_marker_types(self) -> None:
        codes = lint_codes(
            'switch (_ammo) do {\n'
            '    case "B_20mm_AA": {};\n'
            '    case "B_30mm_HE": {};\n'
            '    case "O_30mm_HE": {};\n'
            '};\n'
        )
        self.assertNotIn("A3MARKER", codes)

    def test_unrelated_quoted_class_name_is_not_reported(self) -> None:
        codes = lint_codes('_className = "N_supplyCrate_F";\n')
        self.assertNotIn("A3MARKER", codes)

    def test_marker_command_in_comment_is_not_reported(self) -> None:
        codes = lint_codes('// _marker setMarkerType "b_inf";\n')
        self.assertNotIn("A3MARKER", codes)


if __name__ == "__main__":
    unittest.main()
