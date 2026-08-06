from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "GUI" / "GUI_Menu_TeamV2.sqf"


def test_nested_item_loops_preserve_the_outer_preset_index():
    text = SOURCE.read_text(encoding="utf-8")

    assert text.count("_presetIndex = _forEachIndex;") == 3
    assert "ctrlSetText [_badgeIDCs select _presetIndex, _badge];" in text
    assert "ctrlEnable [_applyIDCs select _presetIndex, _canApply];" in text
    assert "ctrlEnable [_rebuyIDCs select _presetIndex, _canApply];" in text


def test_nested_item_loop_preserves_the_outer_template_index():
    text = SOURCE.read_text(encoding="utf-8")

    assert "_udTemplateIndex = _forEachIndex;" in text
    assert "ctrlSetText [_udNameIDCs select _udTemplateIndex, _udSN];" in text
    assert "ctrlSetText [_udActiveIDCs select _udTemplateIndex" in text
