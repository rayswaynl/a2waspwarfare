import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Module/IRS/IRS_HandleMissile.sqf",
)


def test_irs_deflection_distance_loop_yields_to_the_scheduler():
    loop_pattern = re.compile(
        r"while \{\(_missile distance _vehicle\) > \(round _calculated\)\} do \{(?P<body>.*?)\n\t\};",
        re.DOTALL,
    )

    for relative_path in RELATIVE_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8-sig")
        match = loop_pattern.search(source)
        assert match, relative_path
        assert re.search(r"\bsleep\s+0\.01\s*;", match.group("body")), relative_path
