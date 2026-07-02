#!/usr/bin/env python3

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import check_stringtable_refs


class CheckStringtableRefsTests(unittest.TestCase):
    @contextlib.contextmanager
    def make_repo(self):
        temp = tempfile.TemporaryDirectory()
        try:
            root = Path(temp.name)
            mission = root / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
            mission.mkdir(parents=True)
            yield root, mission
        finally:
            temp.cleanup()

    def write_stringtable(
        self,
        mission: Path,
        keys: list[str],
        columns_by_key: dict[str, dict[str, str]] | None = None,
    ) -> None:
        columns_by_key = columns_by_key or {}
        key_xml = "\n".join(
            f'      <Key ID="{key}">'
            + "".join(
                f"<{language}>{text}</{language}>"
                for language, text in {"English": key, **columns_by_key.get(key, {})}.items()
            )
            + "</Key>"
            for key in keys
        )
        (mission / "stringtable.xml").write_text(
            f"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<Project><Package>{key_xml}</Package></Project>\n",
            encoding="utf-8",
        )

    def run_checker(self, root: Path, *args: str) -> tuple[int, str]:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = check_stringtable_refs.main(["--root", str(root), *args])
        return code, stdout.getvalue()

    def test_reports_missing_key_and_ignores_comments(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(mission, ["STR_WF_OK"])
            (mission / "Client").mkdir()
            (mission / "Client" / "ui.sqf").write_text(
                'hint localize "STR_WF_OK";\n'
                '// localize "STR_WF_COMMENT_ONLY";\n'
                'hint localize "STR_WF_MISSING";\n',
                encoding="utf-8",
            )

            code, output = self.run_checker(root)

            self.assertEqual(code, 1)
            self.assertIn("STRMISSING", output)
            self.assertIn("STR_WF_MISSING", output)
            self.assertNotIn("STR_WF_COMMENT_ONLY", output)

    def test_ignores_builtin_expansion_keys_by_default(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(mission, [])
            (mission / "uav.sqf").write_text(
                'localize "STR_EP1_UAV_action_exit";\n',
                encoding="utf-8",
            )

            code, output = self.run_checker(root)

            self.assertEqual(code, 0)
            self.assertIn("findings: 0", output)

    def test_exit_zero_keeps_report_but_not_failure(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(mission, [])
            (mission / "ui.sqf").write_text('hint localize "STR_WF_MISSING";\n', encoding="utf-8")

            code, output = self.run_checker(root, "--exit-zero")

            self.assertEqual(code, 0)
            self.assertIn("STRMISSING", output)
            self.assertIn("STR_WF_MISSING", output)

    def test_orphan_reporting_is_opt_in(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(mission, ["STR_WF_UNUSED"])
            (mission / "empty.sqf").write_text("hint 'ready';\n", encoding="utf-8")

            code_without_orphans, output_without_orphans = self.run_checker(root)
            code_with_orphans, output_with_orphans = self.run_checker(root, "--orphans")

            self.assertEqual(code_without_orphans, 0)
            self.assertIn("findings: 0", output_without_orphans)
            self.assertEqual(code_with_orphans, 1)
            self.assertIn("STRORPHAN", output_with_orphans)
            self.assertIn("STR_WF_UNUSED", output_with_orphans)

    def test_ru_gap_reporting_is_opt_in(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(
                mission,
                ["STR_WF_HAS_RU", "STR_WF_NO_RU"],
                {"STR_WF_HAS_RU": {"Russian": "Gotovo"}},
            )
            (mission / "empty.sqf").write_text("hint 'ready';\n", encoding="utf-8")

            code_without_ru_gaps, output_without_ru_gaps = self.run_checker(root)
            code_with_ru_gaps, output_with_ru_gaps = self.run_checker(root, "--ru-gaps")

            self.assertEqual(code_without_ru_gaps, 0)
            self.assertIn("findings: 0", output_without_ru_gaps)
            self.assertEqual(code_with_ru_gaps, 1)
            self.assertIn("STRLANG", output_with_ru_gaps)
            self.assertIn("STR_WF_NO_RU", output_with_ru_gaps)
            self.assertIn("missing Russian text", output_with_ru_gaps)
            self.assertNotIn("STR_WF_HAS_RU", output_with_ru_gaps)

    def test_language_gap_reporting_catches_blank_text(self) -> None:
        with self.make_repo() as (root, mission):
            self.write_stringtable(
                mission,
                ["STR_WF_BLANK_RU"],
                {"STR_WF_BLANK_RU": {"Russian": "   "}},
            )
            (mission / "empty.sqf").write_text("hint 'ready';\n", encoding="utf-8")

            code, output = self.run_checker(root, "--languages", "Russian")

            self.assertEqual(code, 1)
            self.assertIn("STRLANG", output)
            self.assertIn("STR_WF_BLANK_RU", output)
            self.assertIn("blank Russian text", output)


if __name__ == "__main__":
    unittest.main()
