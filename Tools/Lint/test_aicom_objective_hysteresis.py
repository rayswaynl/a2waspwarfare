"""Regression contract for the authoritative AICOM2 objective dwell."""

from pathlib import Path
import re

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
CONSTANTS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Init" / "Init_CommonConstants.sqf"
ALLOCATE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "AI" / "Commander" / "AI_Commander_Allocate.sqf"


def _code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


def _first_init_default(text: str, name: str) -> int:
    match = re.search(
        rf'if \(isNil "{re.escape(name)}"\)\s+then\s+\{{\s*'
        rf'{re.escape(name)}\s*=\s*([0-9]+)',
        text,
    )
    assert match, f"missing first-init default for {name}"
    return int(match.group(1))


def test_live_allocator_dwell_matches_strategy_front_dwell() -> None:
    """The armed allocator must not erase Strategy's objective commitment window."""
    constants = _code(CONSTANTS)
    front_dwell = _first_init_default(constants, "WFBE_C_AICOM_FRONT_DWELL")
    fist_dwell = _first_init_default(constants, "WFBE_C_AICOM2_FIST_DWELL")

    assert front_dwell > 0
    assert fist_dwell == front_dwell


def test_live_allocator_dwell_releases_a_blacklisted_primary() -> None:
    """A Strategy stall-blacklist must invalidate the separate Allocate dwell state."""
    allocate = _code(ALLOCATE)
    dwell = allocate[allocate.index("_fdWin = ") : allocate.index("if (_fdValid")]

    assert "wfbe_aicom_spearhead_bl" in dwell
    assert "_fdBlHit" in dwell
    assert "(_x select 1) > time" in dwell
    assert "{!_fdBlHit}" in dwell
