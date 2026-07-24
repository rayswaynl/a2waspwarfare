"""Regression coverage for HC-local corpse and wreck cleanup dispatch."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMON_CONSTANTS_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf"),
)
TRASH_OBJECT_PATH = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_TrashObject.sqf"
)

REMOTE_DELETE_DEFAULT = (
    'if (isNil "WFBE_C_TRASH_REMOTE_DELETE") then {WFBE_C_TRASH_REMOTE_DELETE = 1};'
)
REMOTE_DELETE_DISPATCH = (
    '[_object, "HandleSpecial", ["cleanup-trash-object", _object]] '
    'Call WFBE_CO_FNC_SendToClient;'
)


def test_hc_local_trash_cleanup_is_armed_in_every_maintained_mission() -> None:
    for relative_path in COMMON_CONSTANTS_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        assert REMOTE_DELETE_DEFAULT in text, (
            f"HC-local corpse/wreck cleanup is not armed in {relative_path}"
        )

    trash_object = (ROOT / TRASH_OBJECT_PATH).read_text(encoding="utf-8")
    assert REMOTE_DELETE_DISPATCH in trash_object, (
        "Common_TrashObject no longer dispatches a non-local delete to the owning machine"
    )
