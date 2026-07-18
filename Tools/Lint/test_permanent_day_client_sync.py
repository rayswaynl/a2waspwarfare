#!/usr/bin/env python3
"""Regression checks for server-authoritative permanent-day client/JIP sync."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
INIT = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/initJIPCompatible.sqf"


class PermanentDayClientSyncTests(unittest.TestCase):
    def test_remote_clients_receive_disabled_cycle_dates(self) -> None:
        source = INIT.read_text(encoding="utf-8")
        handler = source[source.index('"WFBE_DAYNIGHT_DATE" addPublicVariableEventHandler') : source.index("//--- B74.2.5")]

        self.assertIn(
            'if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) then {',
            handler,
            "the date receiver does not preserve accelerated-cycle smoothing",
        )
        self.assertIn(
            'if (_server_drift > 0.05) then {setDate _server_date};',
            handler,
            "disabled-cycle permanent day does not hard-sync meaningful drift",
        )
        self.assertNotIn(
            'if (!isDedicated && ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1)) then {',
            source,
            "the receiver is still absent when the accelerated cycle is disabled",
        )

    def test_disabled_cycle_jip_does_not_advance_by_mission_uptime(self) -> None:
        source = INIT.read_text(encoding="utf-8")

        self.assertIn(
            'if (_permSync) then {',
            source,
            "the disabled-cycle JIP branch does not distinguish permanent day",
        )
        self.assertIn(
            'if (!_permSync && {local player}) then {skipTime (time / 3600)};',
            source,
            "permanent-day clients still add mission uptime to their local clock",
        )

    def test_server_republishes_absolute_date_from_clamp(self) -> None:
        source = INIT.read_text(encoding="utf-8")
        clamp = source[source.index("DAYLIGHT| clamp armed") : source.index("WFBE_Parameters_Ready")]

        self.assertIn("WFBE_DAYNIGHT_DATE = date;", clamp)
        self.assertIn('publicVariable "WFBE_DAYNIGHT_DATE";', clamp)


if __name__ == "__main__":
    unittest.main()
