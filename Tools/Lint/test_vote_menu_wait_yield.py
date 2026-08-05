from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MENU_FILES = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "GUI" / "GUI_Menu.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Client" / "GUI" / "GUI_Menu.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Client" / "GUI" / "GUI_Menu.sqf",
)

YIELDED_WAIT = 'waitUntil {sleep 0.05; (WFBE_Client_Logic getVariable "wfbe_votetime") > 0 || !dialog || !alive player};'
LEGACY_WAIT = 'waitUntil {(WFBE_Client_Logic getVariable "wfbe_votetime") > 0 || !dialog || !alive player};'


def test_vote_menu_server_handoff_waits_yield():
    for path in MENU_FILES:
        source = path.read_text(encoding="utf-8-sig")
        assert source.count(YIELDED_WAIT) == 2
        assert source.count(LEGACY_WAIT) == 0
