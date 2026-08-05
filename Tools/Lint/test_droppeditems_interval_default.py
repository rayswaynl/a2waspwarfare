from pathlib import Path
import re


ROOT = Path(__file__).parents[2]
PARAMETER_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Rsc/Parameters.hpp",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Rsc/Parameters.hpp",
)


def _dropped_items_block(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r'class WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD\s*\{(?P<body>.*?)\n\s*\};',
        text,
        re.DOTALL,
    )
    assert match, f"missing dropped-items interval block: {path}"
    return match.group("body")


def test_dropped_items_cleaner_default_is_the_ten_minute_cadence():
    for path in PARAMETER_PATHS:
        body = _dropped_items_block(path)
        values = re.search(r"values\[\]\s*=\s*\{([^}]*)\};", body)
        default = re.search(r"default\s*=\s*(\d+)\s*;", body)
        assert values and "600" in values.group(1), path
        assert default and default.group(1) == "600", path

