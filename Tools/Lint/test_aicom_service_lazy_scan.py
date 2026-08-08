from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_FILES = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Common/Functions/Common_AICOMServiceTick.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Common/Functions/Common_AICOMServiceTick.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Common/Functions/Common_AICOMServiceTick.sqf"
    ),
)

ENROUTE_BRANCH = 'if (_state == "enroute") then {'
THREAT_SCAN = (
    '_enemyNear = {alive _x && {side _x == _enemySide}} count '
    '((getPos _ldr) nearEntities [["Man","LandVehicle","Air"], _safeDist]);'
)
ABORT_GUARD = 'if (_enemyNear > 0 || {time > _deadline}) exitWith {'
IDLE_BRANCH = "\n} else {\n\t//--- ============ IDLE: decide whether to detour ============"


def test_service_threat_scan_is_enroute_only_in_all_maintained_mirrors():
    for relative_path in SERVICE_FILES:
        source = (ROOT / relative_path).read_text(encoding="utf-8")

        assert source.count(THREAT_SCAN) == 1, relative_path
        branch = source.index(ENROUTE_BRANCH)
        scan = source.index(THREAT_SCAN)
        abort = source.index(ABORT_GUARD)
        idle = source.index(IDLE_BRANCH)

        assert branch < scan < abort < idle, (
            f"{relative_path}: the 600 m threat scan must stay inside "
            "the en-route branch and before its abort guard"
        )
        assert source[idle:].count(THREAT_SCAN) == 0, relative_path
