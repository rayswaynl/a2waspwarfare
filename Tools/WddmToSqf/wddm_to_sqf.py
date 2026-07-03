#!/usr/bin/env python3
"""
wddm_to_sqf.py — convert WDDM composition design files (*.wddm.json) into the SQF
composition arrays consumed by the WASP mission's Server\\Init\\Init_Defenses.sqf
(the ['classname',[x,y,z],relDir] element format read by CreateDefenseTemplate /
Server_ConstructPosition.sqf).

Ray's WDDM tool (rayswaynl/WDDM) saves/loads these JSON files verbatim, so the .json
under docs/design/compositions/ is the SINGLE SOURCE OF TRUTH for a composition's
geometry; this script regenerates the matching SQF so hand-editing the arrays is never
needed. Author/iterate in WDDM -> re-run this -> paste the block (or use --emit-file).

Schema (per file, one composition):
  { "name": "WFBE_NEURODEF_...", "objs": [ {"cls","x","y","z","dir"}, ... ], ... }
Extra fields (notes/role/parentW/parentD/parentDir/structureType/fortOnly/mode) are
WDDM/soldier-logic metadata and are ignored by this converter.

Usage:
  python wddm_to_sqf.py                 # print all compositions found, to stdout
  python wddm_to_sqf.py --name WFBE_NEURODEF_AAPOS_WEST   # just one
  python wddm_to_sqf.py --check         # verify every JSON parses + every element well-formed; exit 1 on error
  python wddm_to_sqf.py --emit-file OUT.sqf   # write a self-contained include of all blocks

Coordinate/format notes (must match the mission exactly):
  * element = ['classname',[x,y,z],relDir]  (single quotes; SQF has no double-quote strings need here)
  * numbers are emitted with '.' decimals and no trailing ',0' cruft; integers stay integer-looking
  * +Y = model front, +X = model right, dir in degrees (identical math to WDDM + modelToWorld)
"""
import argparse
import glob
import json
import os
import sys

# docs/design/compositions relative to this script (Tools/WddmToSqf/ -> ../../docs/...)
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "design", "compositions"))


def fmt_num(v):
    """SQF-friendly number: integers as-is (no .0), floats with a single '.' decimal, trim trailing zeros."""
    if isinstance(v, bool):
        raise ValueError("boolean where a coordinate was expected")
    f = float(v)
    if f == int(f):
        return str(int(f))
    # up to 3 decimals, strip trailing zeros, never scientific notation
    s = ("%.3f" % f).rstrip("0").rstrip(".")
    return s


def element_sqf(obj, src):
    for k in ("cls", "x", "y", "z", "dir"):
        if k not in obj:
            raise ValueError("%s: element missing key '%s': %r" % (src, k, obj))
    cls = obj["cls"]
    if not isinstance(cls, str) or cls == "":
        raise ValueError("%s: element 'cls' must be a non-empty string: %r" % (src, obj))
    if "'" in cls or '"' in cls:
        raise ValueError("%s: element 'cls' has a quote char: %r" % (src, cls))
    x = fmt_num(obj["x"]); y = fmt_num(obj["y"]); z = fmt_num(obj["z"]); d = fmt_num(obj["dir"])
    return "['%s',[%s,%s,%s],%s]" % (cls, x, y, z, d)


def composition_sqf(data, src):
    name = data.get("name")
    if not isinstance(name, str) or not name.startswith("WFBE_NEURODEF_"):
        raise ValueError("%s: 'name' missing or not a WFBE_NEURODEF_* var: %r" % (src, name))
    objs = data.get("objs")
    if not isinstance(objs, list) or len(objs) == 0:
        raise ValueError("%s: 'objs' missing or empty" % src)
    elems = [element_sqf(o, src) for o in objs]
    body = ",\n\t".join(elems)
    return "missionNamespace setVariable ['%s',[\n\t%s\n]];" % (name, body)


def load_all(directory):
    files = sorted(glob.glob(os.path.join(directory, "*.wddm.json")))
    out = []
    for f in files:
        with open(f, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        out.append((f, data))
    return out


def main():
    ap = argparse.ArgumentParser(description="Convert WDDM *.wddm.json compositions to SQF arrays.")
    ap.add_argument("--dir", default=DEFAULT_DIR, help="compositions directory (default: docs/design/compositions)")
    ap.add_argument("--name", default=None, help="emit only the composition with this WFBE_NEURODEF_* name")
    ap.add_argument("--check", action="store_true", help="validate all files; exit 1 on any error")
    ap.add_argument("--emit-file", default=None, help="write a self-contained .sqf include of all blocks")
    args = ap.parse_args()

    try:
        loaded = load_all(args.dir)
    except Exception as e:
        sys.stderr.write("ERROR loading compositions: %s\n" % e)
        return 2

    if not loaded:
        sys.stderr.write("ERROR: no *.wddm.json files in %s\n" % args.dir)
        return 2

    blocks = []
    errors = []
    seen = {}
    for src, data in loaded:
        try:
            sqf = composition_sqf(data, os.path.basename(src))
            nm = data["name"]
            if nm in seen:
                errors.append("duplicate composition name %s (in %s and %s)" % (nm, os.path.basename(seen[nm]), os.path.basename(src)))
            seen[nm] = src
            blocks.append((nm, os.path.basename(src), sqf))
        except Exception as e:
            errors.append(str(e))

    if errors:
        for e in errors:
            sys.stderr.write("ERROR: %s\n" % e)
        return 1

    if args.check:
        sys.stderr.write("OK: %d compositions valid.\n" % len(blocks))
        return 0

    if args.name:
        match = [b for b in blocks if b[0] == args.name]
        if not match:
            sys.stderr.write("ERROR: no composition named %s\n" % args.name)
            return 1
        print(match[0][2])
        return 0

    header = ("//--- AUTO-GENERATED from docs/design/compositions/*.wddm.json by Tools/WddmToSqf/wddm_to_sqf.py\n"
              "//--- Source of truth is the .wddm.json (openable in Ray's WDDM tool). Do not hand-edit; re-run the converter.\n")
    text = header + "\n".join("//--- %s  (from %s)\n%s" % (nm, srcname, sqf) for nm, srcname, sqf in blocks) + "\n"

    if args.emit_file:
        with open(args.emit_file, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        sys.stderr.write("wrote %d blocks -> %s\n" % (len(blocks), args.emit_file))
        return 0

    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
