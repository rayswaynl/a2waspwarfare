#!/usr/bin/env python3
"""Regression contract for the town-AI delegation registry rebuild.

A2 OA `exitWith` semantics (engine-verified in this repo): an `exitWith` inside a
`then{}`/`else{}` block only exits that block and FALLS THROUGH - it does not return
from the enclosing `call{}`. A drop-condition `exitWith` nested two `then{}` levels
deep therefore never skips the registry re-add below it, so
`WFBE_CL_TownAI_Groups` grows monotonically forever instead of pruning cleaned-up
entries.

Substring presence checks cannot catch this class of bug (the vulnerable code
contains every "right" token, just at the wrong scope). This test instead parses
brace structure to confirm the re-add statement is actually reachable only from a
guarded branch, not unconditionally after the drop check.
"""

from pathlib import Path
import re
import unittest


REPO = Path(__file__).resolve().parents[2]
CLEANUP = (
    REPO
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_CleanupDelegatedTownAI.sqf"
)

REGISTRY_SET_STMT = "_registryNew set [count _registryNew, _entry];"

# Anchors the registry-rebuild `call { ... }` block uniquely within the file (the
# earlier cleanup-loop `call {` is preceded by `_group = _x;`, not `_entry = _x;`).
BLOCK_ANCHOR_RE = re.compile(r"_entry\s*=\s*_x;\s*call\s*\{")


def _brace_depth_of_statement(block_body, statement, start_depth=1):
    """Walk block_body (text strictly after the call block's opening '{') tracking
    brace depth, ignoring braces inside double-quoted strings. Returns the depth at
    which `statement` first appears, or None if it is not found before the call
    block closes (depth returns to 0)."""
    depth = start_depth
    in_string = False
    i = 0
    n = len(block_body)
    while i < n and depth > 0:
        ch = block_body[i]
        if ch == '"':
            in_string = not in_string
        elif not in_string:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return None
        if block_body[i : i + len(statement)] == statement:
            return depth
        i += 1
    return None


class TownDelegationRegistryMergeContractTests(unittest.TestCase):
    def setUp(self):
        self.cleanup_text = CLEANUP.read_text(encoding="utf-8")

    def test_registry_rebuild_reads_current_registry(self):
        self.assertIn(
            '_registryCurrent = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []]',
            self.cleanup_text,
        )
        self.assertIn("} forEach _registryCurrent;", self.cleanup_text)

    def test_registry_reAdd_is_reachable_only_from_a_guarded_branch(self):
        """The bug shape: exitWith nested two then{} levels deep falls through, so
        `_registryNew set [...]` sits at the call block's TOP scope (depth 1) and
        runs unconditionally for every entry - nothing is ever dropped.

        The fix shape: the re-add statement must live inside a guard - e.g.
        `if !(_entryDrop) then { ... set ... }` - so it is nested at least one level
        deeper (depth >= 2) than the call block's own body, and a genuine drop
        decision actually skips it.
        """
        match = BLOCK_ANCHOR_RE.search(self.cleanup_text)
        self.assertIsNotNone(
            match, "could not locate the registry-rebuild call{} block (anchor changed?)"
        )

        block_body = self.cleanup_text[match.end() :]
        depth = _brace_depth_of_statement(block_body, REGISTRY_SET_STMT)

        self.assertIsNotNone(
            depth,
            "did not find '%s' inside the registry-rebuild call{} block"
            % REGISTRY_SET_STMT,
        )
        self.assertGreaterEqual(
            depth,
            2,
            "the registry re-add ('%s') sits at the call{} block's top scope "
            "(depth %d) - it runs unconditionally for every entry regardless of "
            "any drop condition above it. It must be nested inside a guarded "
            "branch (e.g. `if !(_entryDrop) then { ... };`) so a genuine drop "
            "decision can actually skip it." % (REGISTRY_SET_STMT, depth),
        )

    def test_drop_decision_is_not_a_bare_nested_exitWith(self):
        """Guard against reintroducing the exact broken shape: a drop `exitWith`
        nested two `then{}` levels below the call{} block's own body. That
        exitWith only exits its immediate then{} block and falls through - it can
        never skip the re-add. (A single-level `if (...) exitWith {}` directly
        inside the call{} body is fine; this only forbids the doubly-nested
        fall-through shape that shipped as the bug.)"""
        broken_shape = re.compile(
            r"if\s*\(_entryGroup in _groups\)\s*then\s*\{"
            r".*?"
            r"if\s*\(.*?\)\s*then\s*\{"
            r".*?"
            r"exitWith\s*\{\};",
            re.DOTALL,
        )
        self.assertIsNone(
            broken_shape.search(self.cleanup_text),
            "found a drop-condition exitWith nested two then{} levels deep - this "
            "falls through instead of skipping the registry re-add (see module "
            "docstring). Hoist the condition to a top-scope `if (...) exitWith {}` "
            "directly inside the call{} block, or compute a keep/drop boolean at "
            "top scope and guard the re-add with it.",
        )


if __name__ == "__main__":
    unittest.main()
