from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
SERVER_INIT = Path("Server/Init/Init_Server.sqf")
CORE_COMPLETION_MARKER = (
    '["INITIALIZATION", Format ["Init_Server.sqf: Core server initialization ended at [%1]", time]] '
    "Call WFBE_CO_FNC_LogContent;"
)
FINAL_COMPLETION_MARKER = (
    '["INITIALIZATION", Format ["Init_Server.sqf: Server initialization ended at [%1]", time]] '
    "Call WFBE_CO_FNC_LogContent;"
)


def test_maintained_server_entrypoint_has_one_core_and_one_final_completion_marker() -> None:
    for mission in MAINTAINED_MISSIONS:
        source = (ROOT / mission / SERVER_INIT).read_text(encoding="utf-8-sig")

        assert source.count(CORE_COMPLETION_MARKER) == 1, mission
        assert source.count(FINAL_COMPLETION_MARKER) == 1, mission
        assert source.index(CORE_COMPLETION_MARKER) < source.index(FINAL_COMPLETION_MARKER), mission
