from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CIPHER_INIT = REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Module" / "CIPHER" / "CIPHER_Init.sqf"


def test_empty_sorters_keep_their_two_array_return_contract():
    source = CIPHER_INIT.read_text(encoding="utf-8")

    functions = (
        ("CIPHER_SortArray", "CIPHER_SortArrayIndex"),
        ("CIPHER_SortArrayIndex", None),
    )
    for function_name, next_function in functions:
        function = source.split(function_name + " = {", 1)[1]
        if next_function:
            function = function.split(next_function + " = {", 1)[0]
        assert "if (count _list == 0) exitWith {[[], []]};" in function
