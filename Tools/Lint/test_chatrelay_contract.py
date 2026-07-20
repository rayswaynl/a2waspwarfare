"""Static contract for the game-to-Discord chat relay transport.

The UI callback must be an A2 string handler that resolves a global function;
its state cannot depend on a closure created by the display watcher.  The
server record is intentionally plain so the file producer receives the exact
RPT fields, not SQF ``str``-quoted string values.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
CLIENT = Path("Client/Functions/Client_ChatRelayTap.sqf")
SERVER = Path("Server/Init/Init_Server.sqf")


class ChatRelayContractTests(unittest.TestCase):
    def test_ui_handler_is_global_string_callback_with_ui_state(self):
        for mission in MISSIONS:
            text = (mission / CLIENT).read_text(encoding="utf-8")
            self.assertIn("WFBE_CL_FNC_ChatRelayKeyDown = {", text)
            self.assertIn(
                'displayAddEventHandler ["KeyDown", "_this call WFBE_CL_FNC_ChatRelayKeyDown"]',
                text,
            )
            self.assertIn('uiNamespace getVariable ["WFBE_CHATRELAY_LAST_TEXT", ""]', text)
            self.assertIn('uiNamespace setVariable ["WFBE_CHATRELAY_LAST_TIME", time]', text)
            self.assertNotIn('displayAddEventHandler ["KeyDown", _keyHandler]', text)

    def test_server_emits_plain_uid_and_side_strings(self):
        for mission in MISSIONS:
            text = (mission / SERVER).read_text(encoding="utf-8")
            self.assertIn('typeName (_d select 0) == "STRING"', text)
            self.assertIn('typeName (_d select 2) == "STRING"', text)
            self.assertIn('"CHATRELAY|v1|uid=" + (_d select 0)', text)
            self.assertIn('"|side=" + (_d select 2)', text)
            self.assertNotIn('"CHATRELAY|v1|uid=" + str (_d select 0)', text)
            self.assertNotIn('"|side=" + str (_d select 2)', text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
