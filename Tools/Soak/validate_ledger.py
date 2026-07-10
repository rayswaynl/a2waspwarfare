#!/usr/bin/env python3
"""Validate a soak-ledger JSONL file against run_result.schema.json.

Dependency-free (does not require the `jsonschema` package): walks the subset of
JSON Schema the frozen contract actually uses -- `required`, `properties`,
`additionalProperties: false`, `const`, and `enum` -- which is enough to catch the
mistakes that matter for this ledger (a missing/renamed/extra field, a bad status
enum, null-vs-omitted drift). Comment lines (leading '#') and blank lines are skipped.

Usage:
    python validate_ledger.py <ledger.jsonl> [--schema run_result.schema.json]
    python validate_ledger.py --self-test

Exit 0 = every row conforms; exit 1 = one or more violations (printed).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SCHEMA = os.path.join(HERE, "run_result.schema.json")

_JSON_TYPES = {
    "object": dict,
    "array": list,
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "null": type(None),
}


def _type_ok(value, spec_type):
    types = spec_type if isinstance(spec_type, list) else [spec_type]
    for t in types:
        py = _JSON_TYPES.get(t)
        if py is None:
            return True  # unknown type keyword -> don't fail on it
        # bool is a subclass of int in Python; keep them distinct
        if t == "integer" and isinstance(value, bool):
            continue
        if t == "number" and isinstance(value, bool):
            continue
        if isinstance(value, py):
            return True
    return False


def _walk(node, data, path, errs):
    if "const" in node and data != node["const"]:
        errs.append(f"{path}: const {node['const']!r} != {data!r}")
    if "enum" in node and data not in node["enum"]:
        errs.append(f"{path}: {data!r} not in enum {node['enum']}")
    if "type" in node and not _type_ok(data, node["type"]):
        errs.append(f"{path}: type {data!r} is not {node['type']}")

    if node.get("type") == "object" or "properties" in node:
        if not isinstance(data, dict):
            return
        for k in node.get("required", []):
            if k not in data:
                errs.append(f"{path}.{k}: MISSING required field")
        props = node.get("properties", {})
        if node.get("additionalProperties", True) is False:
            for k in data:
                if k not in props:
                    errs.append(f"{path}.{k}: UNEXPECTED key (additionalProperties:false)")
        for k, sub in props.items():
            if k in data:
                _walk(sub, data[k], f"{path}.{k}", errs)

    if node.get("type") == "array" and isinstance(data, list) and "items" in node:
        for i, item in enumerate(data):
            _walk(node["items"], item, f"{path}[{i}]", errs)


def iter_rows(path):
    with open(path, "r", encoding="utf-8-sig") as fh:
        for lineno, line in enumerate(fh, 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            try:
                yield lineno, json.loads(s)
            except json.JSONDecodeError as e:
                yield lineno, e


def validate_file(ledger_path, schema_path=DEFAULT_SCHEMA):
    schema = json.load(open(schema_path, "r", encoding="utf-8"))
    errs, n = [], 0
    for lineno, row in iter_rows(ledger_path):
        if isinstance(row, json.JSONDecodeError):
            errs.append(f"line {lineno}: invalid JSON ({row})")
            continue
        n += 1
        _walk(schema, row, f"line{lineno}", errs)
    return n, errs


def _self_test():
    """Round-trip: a good row passes, each deliberate mutation is caught."""
    schema = json.load(open(DEFAULT_SCHEMA, "r", encoding="utf-8"))
    good = {
        "schema": "a2wasp-soak-ledger-row-v1",
        "rowId": "20260707-0001",
        "createdAtUtc": "2026-07-07T00:00:00Z",
        "status": "POSTED",
        "identity": {"stampId": "x", "candidate": "x", "terrain": "chernarus",
                     "role": "r", "git": None, "archiveSha256": None,
                     "pboName": None, "operator": "Ray"},
        "provenance": {"serverRptPath": None, "hcRptPath": None, "analyzeJsonPath": None,
                       "lensJsonPath": None, "serverRptSha256": None, "hcRptSha256": None},
        "analyzer": {"build": None, "map": None, "hours": None, "roundend": None,
                     "arrival": {"dispatches": None, "arrivals": None, "arrivalPct": None,
                                 "medianDispatchToArrivalMin": None},
                     "zombies": {"minDispatch": None, "count": None},
                     "armyVsArmy": {"totalKills": None, "weKills": None, "weSharePct": None},
                     "churn": {"frontChangesWest": None, "frontChangesEast": None,
                               "reissueCount": None, "targetAbandonTotal": None},
                     "hold": {"captures": None, "maxTownsWest": None, "maxTownsEast": None,
                              "hcCaptured": None},
                     "perf": {"serverFpsMin": None, "serverFpsMedian": None, "serverFpsMax": None,
                              "serverFpsMinWindow": None, "hcFpsMin": None, "hcFpsMedian": None,
                              "hc2FpsMedian": None, "aiTotPeak": None, "guerPeak": None,
                              "samples": None},
                     "warStateExt": {"present": False, "arrivalRatePct": None,
                                     "townsW": None, "townsE": None, "terr": None}},
        "lenses": {"overall": None, "worstLens": None, "release": None, "errors": None,
                   "war": None, "perf": None, "summary": None},
        "discord": {"enabled": False, "status": "skipped", "guildId": None, "channelId": None,
                    "messageId": None, "postedAtUtc": None, "error": None},
        "notes": [],
    }
    cases = []
    e = []; _walk(schema, good, "good", e); cases.append(("good row passes", len(e) == 0))
    bad = json.loads(json.dumps(good)); del bad["status"]
    e = []; _walk(schema, bad, "r", e); cases.append(("missing status caught", len(e) > 0))
    bad = json.loads(json.dumps(good)); bad["status"] = "NONSENSE"
    e = []; _walk(schema, bad, "r", e); cases.append(("bad status enum caught", len(e) > 0))
    bad = json.loads(json.dumps(good)); bad["surprise"] = 1
    e = []; _walk(schema, bad, "r", e); cases.append(("extra top-level key caught", len(e) > 0))
    bad = json.loads(json.dumps(good)); bad["schema"] = "wrong"
    e = []; _walk(schema, bad, "r", e); cases.append(("wrong schema const caught", len(e) > 0))
    bad = json.loads(json.dumps(good)); bad["analyzer"]["perf"]["samples"] = "notint"
    e = []; _walk(schema, bad, "r", e); cases.append(("wrong type caught", len(e) > 0))
    ok = True
    for name, passed in cases:
        print(f"  {'ok  ' if passed else 'FAIL'} {name}")
        ok = ok and passed
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("ledger", nargs="?", help="Path to soak-ledger.jsonl")
    ap.add_argument("--schema", default=DEFAULT_SCHEMA)
    ap.add_argument("--self-test", action="store_true", help="Run the built-in validator tests")
    args = ap.parse_args()

    if args.self_test:
        ok = _self_test()
        print("PASSED" if ok else "FAILED")
        return 0 if ok else 1

    if not args.ledger:
        ap.error("ledger path required (or use --self-test)")
    n, errs = validate_file(args.ledger, args.schema)
    if errs:
        print(f"CONFORMANCE FAIL ({len(errs)} violation(s)) over {n} row(s):")
        for e in errs:
            print("  -", e)
        return 1
    print(f"CONFORMANCE OK: {n} row(s) conform to {os.path.basename(args.schema)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
