"""Regression contract for the A2-safe shared weighted-draw upper bound.

The entropy offset is intentionally tiny, but it is positive.  Without a
post-offset clamp, a draw at the top of the random range can exceed the
cumulative weight and incorrectly use the first-entry fallback.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DRAW = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_WeightedDraw.sqf"
)


def draw_index(weights: list[int], roll: float) -> int | None:
    cumulative = 0
    for index, weight in enumerate(weights):
        cumulative += weight
        if roll < cumulative:
            return index
    return None


def test_entropy_offset_cannot_escape_the_positive_weight_interval():
    # This is the exact edge that previously fell through to the first-entry
    # fallback, even when that entry had zero weight.
    total = 1
    unbounded_roll = total + 0.0001
    bounded_roll = min(unbounded_roll, total - 0.00001)

    assert draw_index([0, 1], unbounded_roll) is None
    assert draw_index([0, 1], bounded_roll) == 1


def test_sqf_clamps_the_entropy_adjusted_roll_before_walking_weights():
    source = DRAW.read_text(encoding="utf-8-sig")
    assert (
        "_roll = ((random _cumSum) + _entropy * 0.0001) min (_cumSum - 0.00001);"
        in source
    )


if __name__ == "__main__":
    test_entropy_offset_cannot_escape_the_positive_weight_interval()
    test_sqf_clamps_the_entropy_adjusted_roll_before_walking_weights()
    print("PASS: weighted-draw entropy roll is bounded below cumulative weight")
