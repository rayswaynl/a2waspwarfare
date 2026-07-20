#!/usr/bin/env python3
"""Regression checks for the naval deck-camp repair deadlock fix (kimi/072020-naval-deckcamp-repair).

Bug: naval HVT deck camps are "HeliHEmpty" stand-in logics (Init_NavalHVT.sqf), but every
repair-camp consumer scanned nearEntities [WFBE_Logic_Camp] (="LocationLogicCamp") only, so a
destroyed deck camp was unrepairable -> its sideID stayed frozen (server_town_camp.sqf skips dead
bunkers) -> the mode-2 all-camps town-capture gate deadlocked the carrier town forever. The
server-side revive additionally re-placed the bunker at ATL z=0 (sea surface inside the hull).
Fix: dual-class discovery scans + a wfbe_camp_deckz marker that reseats the revived bunker via
setPosASL. All three terrains are asserted (LoadoutManager mirrors CH -> TK/ZG).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)

DISCOVERY_FILES = (
    "Client/Action/Action_RepairCamp.sqf",
    "Client/Action/Action_RepairCampEngineer.sqf",
    "Client/Functions/Client_CanRepairCampNearby.sqf",
)

DUAL_SCAN = 'nearEntities [[WFBE_Logic_Camp, "HeliHEmpty"], _range]'
DECK_MARKER_SET = 'setVariable ["wfbe_camp_deckz", _deckZ]'
DECK_MARKER_READ = '_logic getVariable "wfbe_camp_deckz"'
DECK_RESEAT = '_townModel setPosASL [_campXY select 0, _campXY select 1, _logic getVariable "wfbe_camp_deckz"]'


def test_dual_class_repair_discovery_on_all_terrains() -> None:
    for terrain in TERRAINS:
        for relative in DISCOVERY_FILES:
            source = (ROOT / terrain / relative).read_text(encoding="utf-8")
            assert DUAL_SCAN in source, f"{terrain}/{relative}: missing dual-class nearEntities scan"
            assert source.count(DUAL_SCAN) == 1, f"{terrain}/{relative}: unexpected extra scan sites"


def test_deckz_marker_written_at_deck_camp_creation() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Init/Init_NavalHVT.sqf").read_text(encoding="utf-8")
        assert DECK_MARKER_SET in source, f"{terrain}: deck camps not tagged with wfbe_camp_deckz"


def test_revive_reseats_tagged_camps_on_deck() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Functions/Server_HandleSpecial.sqf").read_text(encoding="utf-8")
        assert DECK_MARKER_READ in source, f"{terrain}: repair-camp revive does not read wfbe_camp_deckz"
        assert DECK_RESEAT in source, f"{terrain}: repair-camp revive missing setPosASL deck reseat"
        # Land-camp ATL ground-snap must remain as the else-branch.
        assert "_townModel setPos [_campXY select 0, _campXY select 1, 0];" in source, (
            f"{terrain}: land-camp ATL placement lost"
        )


if __name__ == "__main__":
    test_dual_class_repair_discovery_on_all_terrains()
    test_deckz_marker_written_at_deck_camp_creation()
    test_revive_reseats_tagged_camps_on_deck()
    print("naval deck-camp repair regression checks passed")
