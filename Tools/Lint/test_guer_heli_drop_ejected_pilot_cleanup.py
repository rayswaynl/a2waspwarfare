from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Support" / "Support_GuerHeliDrop.sqf"


def test_guer_heli_drop_cleanup_reaps_dismounted_group_members_before_hull():
    text = SOURCE.read_text(encoding="utf-8")
    cleanup = text[text.index("//--- In any case, cleanup the transporter"):]

    group_sweep = "forEach (units _grp)"
    hull_delete = "deleteVehicle _vehicle;"
    group_delete = "deleteGroup _grp"

    assert group_sweep in cleanup
    assert cleanup.index(group_sweep) < cleanup.index(hull_delete) < cleanup.index(group_delete)
    assert "!isPlayer _x" in cleanup
