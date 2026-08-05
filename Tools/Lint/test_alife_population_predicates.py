"""Regression contracts for live population predicates used by capture holds."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RADIUS_HOLD = Path("Common") / "Functions" / "Common_RadiusHold.sqf"


class LivePopulationPredicateTests(unittest.TestCase):
    def test_radius_hold_excludes_dead_men_and_empty_hulls_before_count_side(self) -> None:
        """A corpse or abandoned hull must not hold or contest an objective."""
        for mission in MISSIONS:
            source = (mission / RADIUS_HOLD).read_text(encoding="utf-8-sig")
            start = source.index("//--- Presence scan:")
            end = source.index("_westN = west countSide", start)
            scan = source[start:end]

            self.assertIn('"_objects","_capObjects"', source)
            self.assertIn("_capObjects = [];", scan)
            self.assertIn('if (_x isKindOf "Man") then {', scan)
            self.assertIn(
                "if (alive _x) then {_capObjects = _capObjects + [_x]};",
                scan,
            )
            self.assertIn(
                "if (alive _x && {count crew _x > 0}) then {_capObjects = _capObjects + [_x]};",
                scan,
            )
            self.assertIn("_objects = _capObjects;", scan)


if __name__ == "__main__":
    unittest.main()
