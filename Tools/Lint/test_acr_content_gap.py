"""Static contract for the default-off ACR content-gap registration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative_path: str) -> str:
    return (MISSION / relative_path).read_text(encoding="utf-8")


def test_acr_content_gap_is_default_off_and_registers_verified_statics():
    constants = read("Common/Init/Init_CommonConstants.sqf")
    core = read("Common/Config/Core/Core_ACR.sqf")

    assert 'WFBE_C_ACR_CONTENT_GAP = 0' in constants
    assert 'WFBE_C_ACR_CONTENT_GAP", 0]) > 0' in core
    for classname in ("AGS_CZ_EP1", "2b14_82mm_CZ_EP1", "DSHKM_CZ_EP1"):
        assert classname in core


def test_acr_gear_metadata_is_exposed_only_when_content_gap_flag_is_on():
    expected = {
        "Loadout/Loadout_US.sqf": ("CZ805_A1_ACR", "CZ805_A1_GL_ACR", "CZ805_A2_ACR", "CZ805_B_GL_ACR", "CZ_750_S1_ACR"),
        "Loadout/Loadout_RU.sqf": ("CZ805_A2_SD_ACR", "evo_sd_ACR", "Evo_mrad_ACR", "CZ_75_SP_01_PHANTOM_SD"),
        "Loadout/Loadout_GUE.sqf": ("Evo_ACR", "CZ_75_SP_01_PHANTOM"),
    }

    for relative_path, classnames in expected.items():
        source = read(f"Common/Config/{relative_path}")
        assert 'WFBE_C_ACR_CONTENT_GAP", 0]) > 0' in source
        for classname in classnames:
            assert classname in source


def test_acr_airframes_remain_on_the_existing_easa_catalog():
    easa = read("Client/Module/EASA/EASA_Init.sqf")
    assert "_easaVehi = _easaVehi + ['L159_ACR'];" in easa
    assert "_easaVehi = _easaVehi + ['Mi24_D_CZ_ACR'];" in easa
