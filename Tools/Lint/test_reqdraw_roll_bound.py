from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WILDCARD_FILES = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/AI_Commander_Wildcard.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/AI_Commander_Wildcard.sqf",
    ROOT
    / "Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Server/Functions/AI_Commander_Wildcard.sqf",
)


def test_reqdraw_entropy_overshoot_is_bounded_before_weight_selection():
    total_weight = 23.0
    overshoot = 22.999999 + 0.999999 * 0.0001
    assert overshoot >= total_weight

    bounded_roll = min(overshoot, total_weight - 0.00001)
    assert bounded_roll < total_weight
    expected_roll = (
        "_roll    = ((random _cumSum) + _entropy * 0.0001) "
        "min (_cumSum - 0.00001);"
    )
    legacy_roll = "_roll    = (random _cumSum) + _entropy * 0.0001;"

    for path in WILDCARD_FILES:
        source = path.read_text(encoding="utf-8")
        block_start = source.index("//--- Weighted roll + eligibility re-draw")
        block_end = source.index("//--- Final fallback:", block_start)
        roll_block = source[block_start:block_end]
        block_lines = [line.strip() for line in roll_block.splitlines()]
        roll_assignments = [
            line for line in block_lines if line.startswith("_roll")
        ]

        assert roll_assignments == [expected_roll], (
            f"{path.relative_to(ROOT)} lets entropy push REQDRAW past its "
            "total weight and fall through to forbidden paid-draw W1"
        )
        assert legacy_roll not in roll_assignments
        assert block_lines.index(expected_roll) < block_lines.index(
            "_i = 0; _chosen = 0; _cumSum2 = 0;"
        )
