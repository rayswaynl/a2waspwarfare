#!/usr/bin/env python3

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
ASSIGN_PATHS = tuple(
    root / "Server/AI/Commander/AI_Commander_AssignTowns.sqf"
    for root in MISSION_ROOTS
)
STRATEGY_PATHS = tuple(
    root / "Server/AI/Commander/AI_Commander_Strategy.sqf"
    for root in MISSION_ROOTS
)
PLAYER_ARTY_PATHS = tuple(
    root / "Server/AI/Commander/AI_Commander_PlayerArty.sqf"
    for root in MISSION_ROOTS
)
COMMANDER_PATHS = tuple(
    root / "Server/AI/Commander/AI_Commander.sqf" for root in MISSION_ROOTS
)

REQUEST_KEY = "wfbe_aicom_grudge_barrage_request"
AI_ARTY_GATE = (
    'if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) '
    '> 0) && {(missionNamespace getVariable "WFBE_C_ARTILLERY") > 0}) then {'
)
REQUEST_READ = (
    '_grudgeArtyReq = _logik getVariable '
    '"wfbe_aicom_grudge_barrage_request";'
)
REQUEST_USE = "_grudgeArtyUse = _grudgeArtyFresh && {!_riArtyFresh};"
SCHEMA_GUARD = (
    'if (!isNil "_grudgeArtyReq" && '
    '{typeName _grudgeArtyReq == "ARRAY"} && '
    '{count _grudgeArtyReq == 2}) then {'
)
TTL_GUARD = (
    '(time - _grudgeArtyT0) < (missionNamespace getVariable '
    '["WFBE_C_AICOM_ARTY_REQUEST_TTL", 120])'
)
SCALAR_TTL_GUARD = (
    'if ((typeName _grudgeArtyX == "SCALAR") && '
    '{typeName _grudgeArtyY == "SCALAR"} && {'
    + TTL_GUARD
    + '}) then {_grudgeArtyFresh = true};'
)
FIRE_GATE = (
    'if ((time - (_logik getVariable ["wfbe_aicom_arty_last", -1e6]) '
    "> _cd) || _riArtyFresh || _grudgeArtyUse) then {"
)
TARGET_OVERRIDE = (
    "if (_grudgeArtyUse) then {_artyTgt = _grudgeArtyPos};"
)
REQUEST_CLEAR = (
    '_logik setVariable ["wfbe_aicom_grudge_barrage_request", []];'
)
CONSUME_BLOCK = (
    'if (_grudgeArtyUse) then {\n'
    '\t\t_logik setVariable ["wfbe_aicom_grudge_barrage_request", []];\n'
    '\t\t_logik setVariable ["wfbe_aicom_arty_last", time];\n'
    '\t};'
)
LOCAL_PRODUCER = (
    '_logik setVariable ["wfbe_aicom_grudge_barrage_request", '
    '[getPos _target, time]];'
)
PUBLIC_PRODUCER = (
    '_logik setVariable ["wfbe_aicom_grudge_barrage_request", '
    '[getPos _target, time], true];'
)
STRATEGY_CALL = "(_side) Call WFBE_SE_FNC_AI_Com_Strategy; _ltStrat = time;"
PLAYER_ARTY_CALL = (
    'if (!isNil "WFBE_SE_FNC_AI_Com_PlayerArty") then '
    "{(_side) Call WFBE_SE_FNC_AI_Com_PlayerArty};"
)


class AicomGrudgeBarrageConsumerTests(unittest.TestCase):
    def test_strategy_consumes_dedicated_request_once_under_ai_arty_gate(self) -> None:
        for path in STRATEGY_PATHS:
            source = path.read_text(encoding="utf-8")
            arty_start = source.index("//--- 4) ARTILLERY:")
            arty_end = source.index(
                'if !(isNil "PerformanceAudit_Record")', arty_start
            )
            arty_block = source[arty_start:arty_end]

            with self.subTest(path=path):
                self.assertEqual(arty_block.count(REQUEST_READ), 1)
                self.assertEqual(arty_block.count(REQUEST_KEY), 2)
                self.assertEqual(arty_block.count(SCHEMA_GUARD), 1)
                self.assertEqual(arty_block.count(TTL_GUARD), 1)
                self.assertEqual(arty_block.count(SCALAR_TTL_GUARD), 1)
                self.assertEqual(arty_block.count(REQUEST_USE), 1)
                self.assertEqual(arty_block.count(FIRE_GATE), 1)
                self.assertEqual(arty_block.count(TARGET_OVERRIDE), 1)
                self.assertEqual(arty_block.count(REQUEST_CLEAR), 1)
                self.assertEqual(arty_block.count(CONSUME_BLOCK), 1)
                self.assertLess(
                    arty_block.index(AI_ARTY_GATE),
                    arty_block.index(REQUEST_READ),
                )
                self.assertLess(
                    arty_block.index(REQUEST_READ),
                    arty_block.index(TARGET_OVERRIDE),
                )
                self.assertLess(
                    arty_block.index(TARGET_OVERRIDE),
                    arty_block.index(REQUEST_CLEAR),
                )

    def test_grudge_request_is_server_local_and_not_player_arty_input(self) -> None:
        for assign_path, player_path in zip(ASSIGN_PATHS, PLAYER_ARTY_PATHS):
            assign_source = assign_path.read_text(encoding="utf-8")
            player_source = player_path.read_text(encoding="utf-8")

            with self.subTest(path=assign_path):
                self.assertEqual(assign_source.count(LOCAL_PRODUCER), 1)
                self.assertNotIn(PUBLIC_PRODUCER, assign_source)
                self.assertNotIn(REQUEST_KEY, player_source)

    def test_strategy_arbitrates_requests_before_player_arty_fallback(self) -> None:
        for path in COMMANDER_PATHS:
            source = path.read_text(encoding="utf-8")

            with self.subTest(path=path):
                self.assertEqual(source.count(STRATEGY_CALL), 1)
                self.assertEqual(source.count(PLAYER_ARTY_CALL), 1)
                self.assertLess(
                    source.index(STRATEGY_CALL), source.index(PLAYER_ARTY_CALL)
                )

    def test_three_maintained_mirrors_stay_identical(self) -> None:
        for paths in (
            ASSIGN_PATHS,
            STRATEGY_PATHS,
            PLAYER_ARTY_PATHS,
            COMMANDER_PATHS,
        ):
            sources = [path.read_text(encoding="utf-8") for path in paths]
            self.assertEqual(sources[1:], [sources[0], sources[0]])


if __name__ == "__main__":
    unittest.main()
