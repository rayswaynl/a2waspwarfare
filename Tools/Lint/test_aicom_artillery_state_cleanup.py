#!/usr/bin/env python3
"""Contract for clearing the AICOM artillery echelon firing state on abort paths.

AI_Commander_Strategy.sqf stamps an echelon gun as ``firing`` before spawning
Common_FireArtillery.sqf.  That worker has two pre-shot exits which tear the
mission down without reaching its normal tail cleanup: an invalid range and a
friendly-fire recheck after the aim delay.  Both exits must return a live gun to
the registered state, and the maintained terrain copies must stay identical.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
FIRE_ARTILLERY = Path("Common") / "Functions" / "Common_FireArtillery.sqf"
STRATEGY = Path("Server") / "AI" / "Commander" / "AI_Commander_Strategy.sqf"
STATE_RESET = (
    'if ((_artillery getVariable ["wfbe_arty_state", ""]) == "firing") then '
    '{_artillery setVariable ["wfbe_arty_state", "registered"]};'
)


def code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


def compact(text: str) -> str:
    return " ".join(text.split())


class AICOMArtilleryStateCleanup(unittest.TestCase):
    def test_pre_shot_abort_paths_clear_firing_state_in_all_terrain_copies(self) -> None:
        for root in TERRAIN_ROOTS:
            source = code(root / FIRE_ARTILLERY)

            out_of_range_start = source.index(
                "if (_distance < 0 || _distance + _minRange > _maxRange) exitWith"
            )
            out_of_range_end = source.index("\n};", out_of_range_start) + 3
            self._assert_reset_after_restricted_clear(
                source[out_of_range_start:out_of_range_end],
                f"{root.name}: out-of-range abort",
            )

            friendly_abort_start = source.index("if (_ffNear > 0) exitWith")
            friendly_abort_end = source.index(
                "\n};\n\nfor '_i'", friendly_abort_start
            ) + 3
            self._assert_reset_after_restricted_clear(
                source[friendly_abort_start:friendly_abort_end],
                f"{root.name}: friendly-fire abort",
            )

    def test_strategy_stamps_firing_after_dispatch_for_the_cleanup_contract(self) -> None:
        strategy = code(TERRAIN_ROOTS[0] / STRATEGY)
        dispatch = "[_p, _artyTgt, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;"
        stamp = 'if (_ech2) then {_p setVariable ["wfbe_arty_state", "firing"]};'
        dispatch_at = strategy.index(dispatch)
        stamp_at = strategy.index(stamp, dispatch_at)
        self.assertGreater(stamp_at, dispatch_at)

    def _assert_reset_after_restricted_clear(self, block: str, label: str) -> None:
        normalized = compact(block)
        restricted = 'setVariable ["restricted",false]'
        reset = compact(STATE_RESET)
        self.assertIn(restricted, normalized, label)
        self.assertIn(reset, normalized[normalized.index(restricted):], label)


if __name__ == "__main__":
    unittest.main()
