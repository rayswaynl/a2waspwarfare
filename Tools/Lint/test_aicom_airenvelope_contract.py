"""Keep the air-envelope default and launch comments aligned with runtime behavior."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_airenvelope_comments_describe_the_enabled_default() -> None:
    for mission in MISSIONS:
        manager = _read(
            mission,
            "Common/Functions/Common_AICOM_SmallArmsAirEnvelope.sqf",
        )
        constants = _read(mission, "Common/Init/Init_CommonConstants.sqf")
        server = _read(mission, "Server/Init/Init_Server.sqf")
        headless = _read(mission, "Headless/Init/Init_HC.sqf")

        assert (
            "Flag: WFBE_C_SMALLARMS_AIR_ENVELOPE "
            "(default 1 = ON; set 0 to disable; flag-off loop never starts, no spawn"
        ) in manager
        assert "Master gate. 0 = OFF = byte-identical to HEAD; 1 = ON (default)." in manager
        assert (
            'WFBE_C_SMALLARMS_AIR_ENVELOPE = 1}; '
            "//--- master gate: 0=off, 1=on (default)."
        ) in constants
        assert "default is 1 (ON)" in constants
        assert "WFBE_C_SMALLARMS_AIR_ENVELOPE, default 1 = ON; set 0 to disable" in server
        assert "WFBE_C_SMALLARMS_AIR_ENVELOPE (default 1 = ON; set 0 to disable)" in headless

        for source in (manager, constants, server, headless):
            assert "WFBE_C_SMALLARMS_AIR_ENVELOPE, default 0 = OFF" not in source
            assert "WFBE_C_SMALLARMS_AIR_ENVELOPE (default 0 = OFF" not in source


def test_airenvelope_contract_files_remain_mirrored() -> None:
    relatives = (
        "Common/Functions/Common_AICOM_SmallArmsAirEnvelope.sqf",
        "Common/Init/Init_CommonConstants.sqf",
        "Server/Init/Init_Server.sqf",
        "Headless/Init/Init_HC.sqf",
    )
    for relative in relatives:
        contents = [(ROOT / mission / relative).read_bytes() for mission in MISSIONS]
        assert contents[0] == contents[1] == contents[2]
