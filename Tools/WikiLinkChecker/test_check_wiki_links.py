#!/usr/bin/env python3
"""Focused regression tests for check_wiki_links.py."""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import check_wiki_links


def write_page(root: Path, name: str, text: str) -> None:
    (root / name).write_text(text, encoding="utf-8")


def run_checker(root: Path, *args: str) -> tuple[int, str]:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        code = check_wiki_links.main([str(root), *args])
    return code, output.getvalue()


class WikiLinkCheckerTests(unittest.TestCase):
    def test_valid_markdown_and_wiki_links_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_page(root, "Home.md", "[Operations](Operations#radio-check)\n[[Operations]]\n")
            write_page(root, "Operations.md", "# Radio Check\n")

            code, output = run_checker(root, "--no-orphans")

        self.assertEqual(code, 0)
        self.assertIn("no findings", output)

    def test_deadlink_fails_by_default_but_exit_zero_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_page(root, "Home.md", "[Missing](Missing-Page)\n")

            default_code, default_output = run_checker(root, "--no-orphans")
            report_code, report_output = run_checker(root, "--no-orphans", "--exit-zero")

        self.assertEqual(default_code, 1)
        self.assertIn("DEADLINK", default_output)
        self.assertEqual(report_code, 0)
        self.assertIn("DEADLINK", report_output)

    def test_bad_anchor_fails_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_page(root, "Home.md", "[Operations](Operations#missing-section)\n")
            write_page(root, "Operations.md", "# Radio Check\n")

            code, output = run_checker(root, "--no-orphans")

        self.assertEqual(code, 1)
        self.assertIn("BADANCHOR", output)


if __name__ == "__main__":
    unittest.main()
