from pathlib import Path


CRATER_CLEANER = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "FSM"
    / "client_crater_cleaner.sqf"
)


def test_client_crater_cleaner_uses_one_spatial_query_for_both_crater_classes():
    source = CRATER_CLEANER.read_text(encoding="utf-8-sig")
    scan = source.split("} forEach ", 1)[1]

    assert scan.count("nearestObjects") == 1
    assert '["CraterLong","CraterLong_small"]' in scan.replace(" ", "")


if __name__ == "__main__":
    test_client_crater_cleaner_uses_one_spatial_query_for_both_crater_classes()
    print("Client crater spatial query contract: PASS")
