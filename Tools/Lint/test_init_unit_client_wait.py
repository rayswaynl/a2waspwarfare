from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Unit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_Unit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_Unit.sqf",
)


def test_client_init_wait_is_bounded_in_every_terrain_mirror() -> None:
    for path in MIRRORS:
        source = path.read_text(encoding="utf-8")

        assert "waitUntil {clientInitComplete};" not in source
        assert "_clientInitDeadline = diag_tickTime + 90;" in source
        assert (
            'waitUntil { uiSleep 0.25; (!isNil "clientInitComplete" && {clientInitComplete}) '
            '|| {diag_tickTime > _clientInitDeadline} };'
        ) in source
        assert "Init_Unit.sqf: clientInitComplete timeout" in source
        assert 'if (isNil "clientInitComplete" || {!clientInitComplete}) exitWith {' in source


if __name__ == "__main__":
    test_client_init_wait_is_bounded_in_every_terrain_mirror()
    print("Init_Unit client-init wait regression checks passed")
