"""Regression coverage for AICOM pending-slot reaper observability."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf"),
)

PRIVATE_DECLARATION = 'private ["_pendSince","_pendTimeout"];'
TIMEOUT_ASSIGNMENT = (
    '_pendTimeout = missionNamespace getVariable '
    '["WFBE_C_AICOM_PENDING_TIMEOUT", 270];'
)
TIMEOUT_COMPARISON = "if ((time - _pendSince) > _pendTimeout) then {"
STRUCTURED_REAP = "|HCDISPATCH_REAP|pending->"
HUMAN_REAP_LOG = (
    '["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] HC dispatch pending '
    'slot reaped after timeout (pending->%2, age=%3s, timeout=%4s).", _sideText, '
    '_pending, round (time - _pendSince), _pendTimeout]] Call WFBE_CO_FNC_AICOMLog;'
)


def test_pending_reaper_reports_the_cached_timeout_to_aicom_log() -> None:
    for relative_path in TEAMS_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert PRIVATE_DECLARATION in text, f"pending timeout is not private in {relative_path}"
        assert TIMEOUT_ASSIGNMENT in text, f"pending timeout is not cached in {relative_path}"
        assert TIMEOUT_COMPARISON in text, f"reaper does not use cached timeout in {relative_path}"
        assert HUMAN_REAP_LOG in text, f"human reaper log is missing in {relative_path}"

        assert text.index(TIMEOUT_ASSIGNMENT) < text.index(TIMEOUT_COMPARISON)
        assert text.index(STRUCTURED_REAP) < text.index(HUMAN_REAP_LOG)
