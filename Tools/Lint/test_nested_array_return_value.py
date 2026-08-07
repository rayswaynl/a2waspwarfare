from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_FindVariableInNestedArray.sqf"
)


def test_nested_array_lookup_writes_the_matching_index_from_a_loop_scope() -> None:
    """The helper must return an index, not the nil result of a forEach command."""
    source = SOURCE.read_text(encoding="utf-8-sig")

    assert '_index = -1;' in source
    assert 'for "_i" from 0 to ((count _array) - 1) do {' in source
    assert 'if (_value in (_array select _i)) exitWith {_index = _i};' in source
    assert '} forEach _array;' not in source
    assert source.rstrip().endswith("_index;")
