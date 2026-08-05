"""Regression coverage for corrupt FPV first-flight profile values."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_FILES = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Module"
    / "FPV"
    / "fpv_interface.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Client"
    / "Module"
    / "FPV"
    / "fpv_interface.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Client"
    / "Module"
    / "FPV"
    / "fpv_interface.sqf",
)


class FpvProfileNamespaceGuardTests(unittest.TestCase):
    def test_first_flight_value_is_sanitized_before_boolean_negation(self) -> None:
        guard = re.compile(
            r"_firstFlightShown\s*=\s*profileNamespace\s+getVariable\s+"
            r'\["WFBE_FPV_FIRSTFLIGHT_SHOWN",\s*false\]\s*;\s*'
            r'if\s*\(typeName\s+_firstFlightShown\s*!=\s*"BOOL"\)\s*'
            r"then\s*\{\s*_firstFlightShown\s*=\s*false\s*\}\s*;\s*"
            r"if\s*\(!_firstFlightShown\)\s*then\s*\{",
            re.IGNORECASE | re.DOTALL,
        )

        for path in MISSION_FILES:
            source = path.read_text(encoding="utf-8")
            self.assertRegex(
                source,
                r"Private\s*\[[^\]]*['_\"]firstFlightShown['_\"]",
                path.as_posix(),
            )
            self.assertRegex(source, guard, path.as_posix())
            self.assertNotIn(
                'if (!(profileNamespace getVariable ["WFBE_FPV_FIRSTFLIGHT_SHOWN", false]))',
                source,
                path.as_posix(),
            )


if __name__ == "__main__":
    unittest.main()
