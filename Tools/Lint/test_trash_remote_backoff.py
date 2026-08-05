"""Static contract for bounded remote TrashObject retries.

The remote delete path is fire-and-forget.  A rejected or unreachable owner
must therefore back off before the collector re-spawns another TrashObject
worker, otherwise one dead object can emit a dispatch every minute forever.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMON = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_TrashObject.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_TrashObject.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_TrashObject.sqf",
]
COLLECTOR = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_collector_garbage.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_collector_garbage.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/server_collector_garbage.sqf",
]


def _read(paths):
    return [path.read_text(encoding="utf-8-sig") for path in paths]


def test_common_trash_records_and_caps_remote_retry_backoff():
    texts = _read(COMMON)
    for text in texts:
        assert "wfbe_trash_remote_attempts" in text
        assert "wfbe_trash_remote_retry_after" in text
        assert "diag_tickTime" in text
        assert "_remoteBackoff" in text
        assert "min" in text
        remote_branch = text[text.index("WFBE_C_TRASH_REMOTE_DELETE") :]
        assert remote_branch.index("wfbe_trash_remote_retry_after") < remote_branch.index('setVariable ["wfbe_trashed", nil]')


def test_collector_does_not_requeue_during_remote_retry_cooldown():
    texts = _read(COLLECTOR)
    for text in texts:
        assert "wfbe_trash_remote_retry_after" in text
        assert "diag_tickTime >=" in text


def test_backoff_schedule_is_exponential_and_capped():
    texts = _read(COMMON)
    for text in texts:
        assert "_remoteBackoff = ((_delay max 60) * (2 ^ ((_remoteAttempt - 1) min 4)));" in text
        assert "if (_remoteBackoff > 900) then {_remoteBackoff = 900};" in text
        assert 'setVariable ["wfbe_trash_remote_attempts", _remoteAttempt]' in text
        assert 'setVariable ["wfbe_trash_remote_retry_after", diag_tickTime + _remoteBackoff]' in text
        assert 'setVariable ["wfbe_trash_remote_attempts", nil]' in text
        assert 'setVariable ["wfbe_trash_remote_retry_after", nil]' in text


def test_maintained_mirrors_are_identical():
    common = [path.read_bytes().replace(b"\r\n", b"\n") for path in COMMON]
    collector = [path.read_bytes().replace(b"\r\n", b"\n") for path in COLLECTOR]
    assert common[0] == common[1] == common[2]
    assert collector[0] == collector[1] == collector[2]
