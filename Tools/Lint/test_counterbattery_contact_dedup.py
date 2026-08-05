from pathlib import Path


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_CounterBattery.sqf"
)


def test_counterbattery_sends_at_most_one_contact_per_detecting_side():
    """Several same-side CBR sites may see one firing; clients receive one contact packet."""
    source = SOURCE.read_text(encoding="utf-8-sig")

    scan_label = source.index("//--- Scan each registered CBR for range match.")
    scan_start = source.rindex("if (count _cbrs > 0) then {", 0, scan_label)
    scan_end = source.index("//--- Prune dead entries from registry", scan_start)
    scan = source[scan_start:scan_end]

    assert "_detected = false;" in scan
    assert "if (_d <= _r && {!_detected}) then" in scan
    assert "_detected = true;" in scan


if __name__ == "__main__":
    test_counterbattery_sends_at_most_one_contact_per_detecting_side()
