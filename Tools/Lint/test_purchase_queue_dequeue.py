#!/usr/bin/env python3
"""Regression checks for the Purchase Units queue-cancel layout and action."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
DIALOGS = CHERNARUS / "Rsc/Dialogs.hpp"
STRINGS = CHERNARUS / "stringtable.xml"
GUI = CHERNARUS / "Client/GUI/GUI_Menu_BuyUnits.sqf"


def control_block(dialogs: str, class_name: str, next_class: str) -> str:
    match = re.search(
        rf"class {re.escape(class_name)}\b.*?(?=\n\s*class {re.escape(next_class)}\b)",
        dialogs,
        re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Could not find {class_name} control block")
    return match.group(0)


def number_property(block: str, property_name: str) -> float:
    match = re.search(rf"\b{re.escape(property_name)}\s*=\s*([0-9.]+)\s*;", block)
    if match is None:
        raise AssertionError(f"Could not find {property_name} property")
    return float(match.group(1))


class PurchaseQueueDequeueTests(unittest.TestCase):
    def test_cancel_control_uses_localized_label_and_header_safe_geometry(self) -> None:
        dialogs = DIALOGS.read_text(encoding="utf-8-sig")
        cancel = control_block(dialogs, "CA_Cancel_Queue", "CA_Faction_Label")
        queue = control_block(dialogs, "CA_Queu_SubTitle", "CA_Cancel_Queue")
        cash = control_block(dialogs, "CA_Cash_SubTitle", "CA_Details")

        self.assertIn("text = $STR_WF_UNITS_CancelOrder;", cancel)
        self.assertIn("style = ST_CENTER;", cancel)
        self.assertIn("<English>Cancel order</English>", STRINGS.read_text(encoding="utf-8-sig"))
        self.assertIn("<Russian>Отменить заказ</Russian>", STRINGS.read_text(encoding="utf-8-sig"))

        for aspect_ratio in (4 / 3, 16 / 10, 16 / 9, 21 / 9):
            for ui_scale in (0.75, 1.0, 1.25):
                with self.subTest(aspect_ratio=aspect_ratio, ui_scale=ui_scale):
                    factor = aspect_ratio * ui_scale
                    queue_right = (number_property(queue, "x") + number_property(queue, "w")) * factor
                    cancel_left = number_property(cancel, "x") * factor
                    cancel_right = (number_property(cancel, "x") + number_property(cancel, "w")) * factor
                    cash_left = number_property(cash, "x") * factor
                    self.assertLessEqual(queue_right, cancel_left)
                    self.assertLessEqual(cancel_right, cash_left)

        self.assertGreaterEqual(
            number_property(cancel, "w") / number_property(cancel, "sizeEx"),
            7.5,
        )

    def test_dequeue_rejects_absent_or_malformed_parallel_queues_before_mutation(self) -> None:
        code = GUI.read_text(encoding="utf-8-sig")
        dequeue = code[code.index("if (MenuAction == 501) then {") : code.index("//--- Player funds", code.index("if (MenuAction == 501) then {"))]

        self.assertIn("if (isNull _closest) exitWith", dequeue)
        self.assertIn('typeName _q33 != "ARRAY"', dequeue)
        self.assertIn('typeName _qc33 != "ARRAY"', dequeue)
        self.assertIn('typeName _qp33 != "ARRAY"', dequeue)
        self.assertIn('typeName _ql33 != "ARRAY"', dequeue)
        self.assertIn("if (count _q33 == 0) exitWith", dequeue)
        self.assertLess(dequeue.index("typeName _q33"), dequeue.index("//--- Find the LAST entry"))

    def test_dequeue_removes_exactly_one_matching_index_with_refund_counter_parity(self) -> None:
        code = GUI.read_text(encoding="utf-8-sig")
        dequeue = code[code.index("if (MenuAction == 501) then {") : code.index("//--- Player funds", code.index("if (MenuAction == 501) then {"))]

        self.assertNotIn("_q33 = _q33 - [_q33 select _idx33];", dequeue)
        self.assertRegex(
            dequeue,
            r"_newArr33 = \[\]; _i33 = 0; \{if \(_i33 != _idx33\) then \{_newArr33 = _newArr33 \+ \[_x\]\}; _i33 = _i33 \+ 1\} forEach _q33; _q33 = _newArr33;",
        )
        self.assertIn("_refund33   = _paidCost33;", dequeue)
        self.assertIn("unitQueu = (unitQueu - _cpt33) max 0;", dequeue)
        self.assertIn('Format ["WFBE_C_QUEUE_%1", _type]', dequeue)


if __name__ == "__main__":
    unittest.main()
