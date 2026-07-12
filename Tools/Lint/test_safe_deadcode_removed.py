"""Regression coverage for helpers retired after their final callers were removed."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ORPHAN_FILENAMES = (
    "Common_HandleATReloadVehicle.sqf",
    "IRS_PlayWarningSound.sqf",
    "IRS_ShowWarning.sqf",
)
ORPHAN_SYMBOLS = (
    "HandleATReloadVehicle",
    "IRS_PlayWarningSound",
    "IRS_ShowWarning",
)


def test_retired_helpers_and_sqf_references_are_absent() -> None:
    for filename in ORPHAN_FILENAMES:
        matches = sorted(path.relative_to(ROOT) for path in ROOT.rglob(filename))
        assert not matches, f"retired helper still exists: {matches}"

    references: dict[str, list[Path]] = {symbol: [] for symbol in ORPHAN_SYMBOLS}
    for path in ROOT.rglob("*.sqf"):
        text = path.read_text(encoding="utf-8", errors="replace")
        for symbol in ORPHAN_SYMBOLS:
            if symbol in text:
                references[symbol].append(path.relative_to(ROOT))

    assert not any(references.values()), f"retired SQF references remain: {references}"
