from pathlib import Path


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions"
NAMED_EXITS = {
    "Common_HandleAAMissiles.sqf": ("OUT", 1),
    "Common_HandleSEADMissile.sqf": ("OUT", 3),
    "Common_PlaceSafe.sqf": ("PlaceSafe", 1),
}


def test_every_breakto_target_is_registered_before_its_first_exit() -> None:
    """A breakTo can only target a scopeName that is already on its call stack."""
    for filename, (scope, expected_breaks) in NAMED_EXITS.items():
        source = (ROOT / filename).read_text(encoding="utf-8-sig")
        scope_offset = source.index(f'scopeName "{scope}"')
        break_offsets = [
            offset
            for offset in range(len(source))
            if source.startswith(f'breakTo "{scope}"', offset)
        ]

        assert len(break_offsets) == expected_breaks
        assert all(scope_offset < offset for offset in break_offsets), filename
