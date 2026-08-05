"""Static contract for avoiding impossible remote trash dispatches.

The remote trash path must not hand an owner id of zero (or a negative id) to
the PVF transport.  The transport drops that request, so the cleaner should
record the retry and requeue the object without attempting a network send.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMON = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_TrashObject.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_TrashObject.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_TrashObject.sqf",
]


def _read(paths):
    return [path.read_text(encoding="utf-8-sig") for path in paths]


def test_remote_trash_captures_owner_and_gates_transport_dispatch():
    for text in _read(COMMON):
        assert "_remoteOwner = owner _object;" in text
        remote_branch = text[text.index("WFBE_C_TRASH_REMOTE_DELETE") :]
        assert "if (_remoteOwner > 0) then {" in remote_branch
        send_index = remote_branch.index(
            '[_object, "HandleSpecial", ["cleanup-trash-object", _object]]'
        )
        guard_index = remote_branch.index("if (_remoteOwner > 0) then {")
        assert guard_index < send_index


def test_remote_owner_guard_keeps_retry_bookkeeping_outside_transport_gate():
    for text in _read(COMMON):
        remote_branch = text[text.index("WFBE_C_TRASH_REMOTE_DELETE") :]
        send_index = remote_branch.index("WFBE_CO_FNC_SendToClient")
        reset_index = remote_branch.index('setVariable ["wfbe_trashed", nil]')
        assert send_index < reset_index
        assert remote_branch.count("wfbe_trash_remote_retry_after") >= 2


def test_maintained_mirrors_are_identical():
    common = [path.read_bytes().replace(b"\r\n", b"\n") for path in COMMON]
    assert common[0] == common[1] == common[2]
