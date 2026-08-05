"""Regression checks for hq.bikb sentence macro expansion."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
HQ_BIKB_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/kb/hq.bikb",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/kb/hq.bikb",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/kb/hq.bikb",
)


class HqBikbPreprocessorTests(unittest.TestCase):
    def test_literal_subtitle_uses_non_localizing_macro(self):
        """A quoted subtitle must not be token-pasted behind a $STR prefix."""
        expected_call = 'SENTENCE_TEXT(HC_OrderReceived,"Order Received")'

        for path in HQ_BIKB_PATHS:
            with self.subTest(path=path):
                text = path.read_text(encoding="utf-8")
                self.assertIn("#define SENTENCE_TEXT(NAME,TEXT)", text)
                self.assertIn("text = TEXT;", text)
                self.assertIn(expected_call, text)
                self.assertNotIn('SENTENCE_KEY(HC_OrderReceived,"Order Received")', text)
                self.assertNotIn('$"Order Received"', text)


if __name__ == "__main__":
    unittest.main()
