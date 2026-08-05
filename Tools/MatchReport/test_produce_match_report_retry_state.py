import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("produce-match-report.ps1")


class MatchReportRetryStateContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SCRIPT.read_text(encoding="utf-8")

    def test_state_is_written_only_after_discord_delivery_attempt(self):
        discord_block = self.source.index("if (-not $SkipDiscord) {")
        state_write = self.source.index(
            'Set-Content -LiteralPath $StateFile -Value "$lastSeq"'
        )

        self.assertGreater(
            state_write,
            discord_block,
            "a failed Discord post must leave the sequence eligible for retry",
        )
        self.assertNotIn(
            'Set-Content -LiteralPath $StateFile -Value "$lastSeq"',
            self.source[:discord_block],
        )

    def test_transient_discord_failure_keeps_state_for_retry(self):
        self.assertIn("$writeState = $true", self.source)
        self.assertIn(
            "if ($code -ge 400 -and $code -lt 500)",
            self.source,
        )
        self.assertIn("$writeState = $false", self.source)
        self.assertIn("will retry", self.source)
        self.assertIn(
            'if ($writeState) { Set-Content -LiteralPath $StateFile -Value "$lastSeq" }',
            self.source,
        )

    def test_render_failure_still_prevents_state_advancement(self):
        render_failure = self.source.index("if ($LASTEXITCODE -ne 0)")
        state_write = self.source.index(
            'if ($writeState) { Set-Content -LiteralPath $StateFile -Value "$lastSeq" }'
        )

        self.assertLess(render_failure, state_write)

    def test_skip_discord_remains_a_successful_terminal_path(self):
        write_state_init = self.source.index("$writeState = $true")
        discord_block = self.source.index("if (-not $SkipDiscord) {")
        state_write = self.source.index(
            'if ($writeState) { Set-Content -LiteralPath $StateFile -Value "$lastSeq" }'
        )

        self.assertLess(write_state_init, discord_block)
        self.assertGreater(state_write, discord_block)


if __name__ == "__main__":
    unittest.main()
