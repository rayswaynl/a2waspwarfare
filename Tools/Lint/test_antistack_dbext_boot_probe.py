from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INIT_SERVERS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Init/Init_Server.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Init/Init_Server.sqf",
)


def test_antistack_database_extension_boot_probe_is_loud_and_read_only():
    for init_server in INIT_SERVERS:
        text = init_server.read_text(encoding="utf-8")

        assert '"A2WaspDatabase" callExtension "101,DBEXT_PROBE"' in text
        assert 'diag_log format ["DBEXT|v1|present=%1", _dbExtPresent];' in text
