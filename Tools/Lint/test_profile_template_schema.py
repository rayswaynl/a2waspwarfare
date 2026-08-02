"""Regression checks for persisted Team V2 template shape guards."""

from pathlib import Path


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_ProfileVariables.sqf"
)


def test_profile_template_slots_require_nested_arrays_before_restore():
    source = SOURCE.read_text(encoding="utf-8")
    assert source.count('typeName (_profile_var select _x) == "ARRAY"') == 2
    assert source.count('count (_profile_var select _x) == 0') == 2
    assert source.count('count (_profile_var select _x) == 5') == 2
    assert source.count('typeName ((_profile_var select _x) select 0) == "ARRAY"') == 2
    assert source.count('typeName ((_profile_var select _x) select 1) == "ARRAY"') == 2
    assert source.count('typeName ((_profile_var select _x) select 2) == "STRING"') == 2
    assert source.count('typeName ((_profile_var select _x) select 3) == "ARRAY"') == 2
    assert source.count('typeName ((_profile_var select _x) select 4) == "ARRAY"') == 2


if __name__ == "__main__":
    test_profile_template_slots_require_nested_arrays_before_restore()
    print("PASS: persisted Team V2 template slots are schema-guarded")
