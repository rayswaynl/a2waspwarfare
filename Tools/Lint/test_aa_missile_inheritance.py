from pathlib import Path


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
AA_CLASSIFIERS = (
    ROOT / "Common" / "Functions" / "Common_RemoveAAMissiles.sqf",
    ROOT / "Client" / "Module" / "EASA" / "EASA_Init.sqf",
)


def test_aa_missile_classifiers_walk_full_cfgammo_lineage():
    """A lockable ammo subclass below MissileBase must still classify as AA."""
    for path in AA_CLASSIFIERS:
        source = path.read_text(encoding="utf-8-sig")
        assert 'while {isClass _ammoCfg && {configName _ammoCfg != "CfgAmmo"} && {!_isMissile}} do {' in source
        assert 'configName(inheritsFrom(configFile >> "CfgAmmo" >> _ammo)) == "MissileBase"' not in source
