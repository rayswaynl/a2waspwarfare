"""Regression contract for mission.sqm abstract Civilian placeholders.

Arma 2 logs an entity-creation warning when a mission.sqm entry names the
abstract ``Civilian`` side class.  The maintained terrains must not carry
those reserved placeholders, while their real headless-client slots remain.
"""

from pathlib import Path
import re
import unittest


REPO = Path(__file__).resolve().parents[2]
MISSIONS = (
    REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "mission.sqm",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "mission.sqm",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "mission.sqm",
)
ABSTRACT_CIVILIAN = 'vehicle="Civilian";'


def group_item_numbers(text: str) -> tuple[int, list[int]]:
    """Return the declared group count and direct Groups Item indices."""
    declared_match = re.search(r'class Groups\s*\{\s*items=(\d+);', text, re.DOTALL)
    if declared_match is None:
        raise AssertionError("mission.sqm has no class Groups items declaration")

    stack: list[str] = []
    pending: str | None = None
    direct_items: list[int] = []
    for raw in text.replace("\r\n", "\n").splitlines():
        stripped = raw.strip()
        class_match = re.fullmatch(r"class ([A-Za-z0-9_]+)", stripped)
        if class_match:
            pending = class_match.group(1)
            continue
        if stripped == "{":
            if pending and stack and stack[-1] == "Groups":
                item_match = re.fullmatch(r"Item(\d+)", pending)
                if item_match:
                    direct_items.append(int(item_match.group(1)))
            stack.append(pending or "(anonymous)")
            pending = None
        elif stripped in ("};", "}") and stack:
            stack.pop()
    return int(declared_match.group(1)), direct_items


class AbstractCivilianSlotTests(unittest.TestCase):
    def test_no_maintained_terrain_instantiates_abstract_civilian(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission):
                text = mission.read_text(encoding="cp1252")
                self.assertNotIn(ABSTRACT_CIVILIAN, text)

    def test_real_headless_client_slots_remain(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission):
                text = mission.read_text(encoding="cp1252")
                self.assertGreaterEqual(text.count('description="Headless Client '), 2)

    def test_group_items_remain_contiguous_after_placeholder_removal(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission):
                declared, item_numbers = group_item_numbers(
                    mission.read_text(encoding="cp1252")
                )
                self.assertEqual(sorted(item_numbers), list(range(declared)))


if __name__ == "__main__":
    unittest.main()
