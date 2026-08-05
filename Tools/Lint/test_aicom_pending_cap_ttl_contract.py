"""Contract for the AICOM pending-cap reservation lifetime."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
CONSTANT_FILES = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf",
)


def _constant(text: str, name: str) -> int:
    match = re.search(rf"{re.escape(name)}\s*=\s*(\d+)", text)
    assert match, f"missing {name} assignment"
    return int(match.group(1))


def test_pending_cap_reservation_outlives_hc_pending_reaper() -> None:
    """A valid HC dispatch must stay counted until its pending slot can be reaped."""

    for path in CONSTANT_FILES:
        text = path.read_text(encoding="utf-8")
        cap_ttl = _constant(text, "WFBE_C_AICOM_CAP_PENDING_TTL")
        pending_timeout = _constant(text, "WFBE_C_AICOM_PENDING_TIMEOUT")
        assert cap_ttl >= pending_timeout, (
            f"{path}: cap pending TTL {cap_ttl}s is shorter than HC pending timeout "
            f"{pending_timeout}s"
        )
