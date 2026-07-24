#!/usr/bin/env python3
"""Static contract for the 60-second client FPS/near-AI telemetry extension.

The mission has no SQF interpreter in CI, so this suite pins the wire contract and
the OA-safe bounded query shape.  A live client/server RPT observation is still
required before treating this instrumentation as runtime-proven.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CLIENT = MISSION / "Client" / "Functions" / "Client_FpsReport.sqf"
SERVER = MISSION / "Server" / "Init" / "Init_Server.sqf"
PARAMETERS = MISSION / "Rsc" / "Parameters.hpp"
MIRRORS = [
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]


def code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


class ClientPerfTelemetryContract(unittest.TestCase):
    def test_60_second_cadence_remains_the_default(self) -> None:
        parameters = code(PARAMETERS)
        block = parameters[parameters.index("class WFBE_C_CLIENT_FPS_REPORT_INTERVAL"):]
        self.assertIn("default = 60;", block)

    def test_client_samples_bounded_near_ai_counts_and_reports_scan_cost(self) -> None:
        client = code(CLIENT)
        self.assertIn('nearEntities [["CAManBase","LandVehicle","Air"], 300]', client)
        self.assertIn('nearEntities [["CAManBase","LandVehicle","Air"], 1000]', client)
        self.assertIn('_entity = _x;', client)
        self.assertIn('if (_entity isKindOf "CAManBase") then {', client)
        self.assertIn('if (!isPlayer _entity) then {_nearAI300 = _nearAI300 + 1};', client)
        self.assertIn('if (!isPlayer _entity) then {_nearAI1000 = _nearAI1000 + 1};', client)
        self.assertIn('({!isPlayer _x} count (crew _entity)) > 0', client)
        self.assertIn("diag_tickTime", client)
        self.assertIn("_nearAI300", client)
        self.assertIn("_nearAI1000", client)
        self.assertIn("_nearMs", client)

    def test_payload_extends_existing_fpsreport_route_without_a_second_bus(self) -> None:
        client = code(CLIENT)
        self.assertIn(
            "WFBE_FPS_REPORT = [getPlayerUID player, name player, round _avg, round _min, round viewDistance, _nearAI300, _nearAI1000, _nearMs];",
            client,
        )
        self.assertIn("publicVariableServer \"WFBE_FPS_REPORT\"", client)
        self.assertNotIn("WFBE_CLIENTPERF_REPORT", client)

    def test_server_emits_all_clientperf_context_fields_from_one_payload(self) -> None:
        server = code(SERVER)
        report = server[server.index('"WFBE_FPS_REPORT" addPublicVariableEventHandler'):]
        self.assertIn('"FPSREPORT|v1|uid="', report)
        self.assertIn('"|vd=" + str (_d select 4)', report)
        self.assertIn('"|nearAI300=" + str (_d select 5)', report)
        self.assertIn('"|nearAI1000=" + str (_d select 6)', report)
        self.assertIn('"|nearMs=" + str (_d select 7)', report)
        self.assertNotIn('"CLIENTPERF|', report)

    def test_receiver_rejects_malformed_payload_before_selecting_fields(self) -> None:
        server = code(SERVER)
        report = server[server.index('"WFBE_FPS_REPORT" addPublicVariableEventHandler'):]
        self.assertIn('if ((typeName _d) != "ARRAY") exitWith {};', report)
        self.assertIn('if ((count _d) < 8) exitWith {};', report)
        self.assertLess(report.index('if ((count _d) < 8) exitWith {};'), report.index('_players ='))

    def test_telemetry_blocks_are_mirrored_byte_for_byte(self) -> None:
        client = CLIENT.read_bytes()
        source_server = SERVER.read_text(encoding="utf-8-sig")
        start = source_server.index("//--- Client FPS telemetry receiver")
        end = source_server.index("//--- B74.2", start)
        receiver = source_server[start:end]
        for mirror in MIRRORS:
            self.assertEqual(client, (mirror / "Client" / "Functions" / "Client_FpsReport.sqf").read_bytes())
            server = (mirror / "Server" / "Init" / "Init_Server.sqf").read_text(encoding="utf-8-sig")
            mirror_start = server.index("//--- Client FPS telemetry receiver")
            mirror_end = server.index("//--- B74.2", mirror_start)
            self.assertEqual(receiver, server[mirror_start:mirror_end])


if __name__ == "__main__":
    unittest.main()
