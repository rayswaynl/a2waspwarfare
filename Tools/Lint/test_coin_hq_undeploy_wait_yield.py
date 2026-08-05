from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COIN_INTERFACE_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Module" / "CoIn" / "coin_interface.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Client" / "Module" / "CoIn" / "coin_interface.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Client" / "Module" / "CoIn" / "coin_interface.sqf",
)

EXPECTED_WAITER = (
    "waitUntil {sleep 0.05; !((sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus) "
    "|| time - _start > 15};"
)
LEGACY_WAITER = (
    "waitUntil {!((sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus) "
    "|| time - _start > 15};"
)


def test_hq_undeploy_cleanup_wait_yields():
    for path in COIN_INTERFACE_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        assert "[] Spawn {" in source
        assert EXPECTED_WAITER in source
        assert LEGACY_WAITER not in source
        assert source.index("[] Spawn {") < source.index(EXPECTED_WAITER)
