"""Guard the client skill animation waiters against scheduler hot-spins."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL_FILES = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Module"
    / "Skill"
)
SKILLS = ("Skill_Engineer.sqf", "Skill_LR.sqf", "Skill_SpecOps.sqf")


class SkillAnimationWaitTests(unittest.TestCase):
    def test_animation_waiters_yield_between_state_checks(self) -> None:
        for skill_name in SKILLS:
            source = (SKILL_FILES / skill_name).read_text(encoding="utf-8-sig")
            waits = re.findall(
                r"waitUntil\s*\{(.*?)\};",
                source,
                flags=re.IGNORECASE | re.DOTALL,
            )
            animation_waits = [
                body for body in waits if "animationState player" in body
            ]

            self.assertEqual(
                len(animation_waits),
                1,
                msg=f"expected one animation wait in {skill_name}",
            )
            self.assertRegex(
                animation_waits[0],
                r"^\s*sleep\s+0\.05\s*;",
                msg=f"animation wait must yield in {skill_name}",
            )


if __name__ == "__main__":
    unittest.main()
