"""Regression contract for reusing the RHUD upgrade snapshot within one tick."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Client_UpdateRHUD.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Client" / "Client_UpdateRHUD.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Client" / "Client_UpdateRHUD.sqf",
)


def test_rhud_arty_reuses_the_upgrade_snapshot_from_the_main_tick() -> None:
    sources = [path.read_text(encoding="utf-8-sig") for path in MIRRORS]

    for source in sources:
        assert "_ups = _this select 0;" in source
        assert "([_ups] call _RHUDUpdateArty)" in source
        assert source.count("Call WFBE_CO_FNC_GetSideUpgrades") == 1

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_rhud_arty_reuses_the_upgrade_snapshot_from_the_main_tick()
    print("RHUD upgrade snapshot contract: PASS")
