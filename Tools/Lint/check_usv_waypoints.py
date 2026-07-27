#!/usr/bin/env python3
"""USV waypoint-logic authoring + deterministic item/count validator for Chernarus mission.sqm.

Usage:
  python usv_sqm_tool.py            # verify only (structural receipt): every items=N == child count
  python usv_sqm_tool.py --author   # insert the WFBE_USV_WP_CH_* logic group, then re-verify

Preserves CRLF byte-for-byte. This is the ISOLATED WRITER + STRUCTURAL RECEIPT the task requires.
Class blocks in .sqm always place '{' and '};' on their own lines; array assignments
(position[]={...}, synchronizations[]={...}) keep their braces inline on one line, so we
only treat a line whose STRIP is exactly '{' / '};' / '}' as a block delimiter.
"""
import re, sys, hashlib

SQM = r"Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm"

# --- water-valid coastal route: collinear eastern-seaboard sea lane at x=14700, bracketed by the
# --- two proven-water naval-carrier anchors Khe Sanh Charlie (y=2000) and Alpha (y=9400). Every
# --- point on that segment is open sea (east of Skalisty I.; Charlie itself is surfaceIsWater-proven
# --- shipped). Offsets keep all waypoints >=1200m from both carrier anchors. z=0 = sea level
# --- (matches the naval-logic convention; surfaceIsWater ignores z).
WAYPOINTS = [
    ("WFBE_USV_WP_CH_1", 14700, 3200, 9101),
    ("WFBE_USV_WP_CH_2", 14700, 5000, 9102),
    ("WFBE_USV_WP_CH_3", 14700, 6800, 9103),
    ("WFBE_USV_WP_CH_4", 14700, 8200, 9104),
]


def load(path):
    with open(path, "rb") as f:
        return f.read()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def parse_counts(text):
    """Return list of (items_line, container_name, declared, actual, ok) for every block
    that declares items=N;."""
    results = []
    stack = []  # frames: {'name','items','items_line','children'}
    pending_class = None
    for i, raw in enumerate(text.split("\n"), 1):
        s = raw.strip()
        mclass = re.match(r'^class\s+([A-Za-z0-9_]+)$', s)
        if mclass:
            pending_class = mclass.group(1)
            continue
        mitems = re.match(r'^items=([0-9]+);$', s)
        if mitems and stack:
            stack[-1]['items'] = int(mitems.group(1))
            stack[-1]['items_line'] = i
            continue
        if s == '{':
            if pending_class and re.match(r'^Item[0-9]+$', pending_class) and stack:
                stack[-1]['children'] += 1
            stack.append({'name': pending_class or '(anon)', 'items': None, 'items_line': None, 'children': 0})
            pending_class = None
            continue
        if s in ('};', '}'):
            if stack:
                fr = stack.pop()
                if fr['items'] is not None:
                    results.append((fr['items_line'], fr['name'], fr['items'], fr['children'], fr['items'] == fr['children']))
            continue
    return results, len(stack)


def find_groups_span(text):
    """Return (items_line_idx, items_value, close_line_idx) 0-based line indices for the top-level
    'class Groups' block. close_line_idx is the line whose strip is '};' that closes Groups."""
    lines = text.split("\n")
    gi = None
    for i, raw in enumerate(lines):
        if raw.strip() == 'class Groups':
            gi = i
            break
    if gi is None:
        raise RuntimeError("class Groups not found")
    # its opening brace
    assert lines[gi + 1].strip() == '{', lines[gi + 1]
    # its items= line
    items_line = gi + 2
    m = re.match(r'^\s*items=([0-9]+);$', lines[items_line])
    assert m, f"expected items= at line {items_line+1}: {lines[items_line]!r}"
    items_val = int(m.group(1))
    # walk to matching close, only counting standalone braces
    depth = 1  # we are inside Groups '{'
    j = gi + 2
    while j < len(lines):
        st = lines[j].strip()
        if st == '{':
            depth += 1
        elif st in ('};', '}'):
            depth -= 1
            if depth == 0:
                return items_line, items_val, j
        j += 1
    raise RuntimeError("Groups block never closed")


def build_group(nl):
    """Build the new LOGIC group block text (class ItemNNN body only, without the leading
    'class ItemNNN' header line — caller supplies index). Uses tabs + given newline."""
    def L(tabs, s):
        return ("\t" * tabs) + s + nl
    out = []
    out.append(L(3, 'side="LOGIC";'))
    out.append(L(3, 'class Vehicles'))
    out.append(L(3, '{'))
    out.append(L(4, f'items={len(WAYPOINTS)};'))
    for idx, (name, x, y, oid) in enumerate(WAYPOINTS):
        out.append(L(4, f'class Item{idx}'))
        out.append(L(4, '{'))
        out.append(L(5, f'position[]={{{x},0,{y}}};'))
        out.append(L(5, 'azimut=0;'))
        out.append(L(5, 'special="NONE";'))
        out.append(L(5, f'id={oid};'))
        out.append(L(5, 'side="LOGIC";'))
        out.append(L(5, 'vehicle="Logic";'))
        if idx == 0:
            out.append(L(5, 'leader=1;'))
        out.append(L(5, 'skill=0.60000002;'))
        out.append(L(5, f'name="{name}";'))
        # init= self-assignment is the PROVEN binding mechanism: a bare-global assignment lands in
        # missionNamespace (proven in-repo: IS_naval_map in initJIPCompatible.sqf is read back via
        # missionNamespace getVariable in this same driver). name= above is the editor Variable Name
        # (belt-and-suspenders); we do not rely on it alone. enableSimulation false matches the RCoin
        # / town-logic idiom in this file and drops per-frame overhead (getPos still works).
        out.append(L(5, f'init="{name} = this; this enableSimulation false;";'))
        out.append(L(4, '};'))
    out.append(L(3, '};'))
    return "".join(out)


def author(data, nl):
    text = data.decode("cp1252")
    # guard: not already present
    if 'WFBE_USV_WP_CH_1' in text:
        raise RuntimeError("WFBE_USV_WP_CH_* already present - refusing to double-author")
    lines = text.split(nl)
    if len(lines) == 1:
        raise RuntimeError("newline split failed - wrong nl")
    items_line, items_val, close_line = find_groups_span(text.replace(nl, "\n"))
    # translate the \n-based indices back: they are line indices, identical for either split
    new_index = items_val  # items_val groups => indices 0..items_val-1 exist; new one is class Item{items_val}
    header = ("\t" * 2) + f"class Item{new_index}" + nl + ("\t" * 2) + "{" + nl
    body = build_group(nl)
    footer = ("\t" * 2) + "};" + nl
    block = header + body + footer
    # bump items count
    m = re.match(r'^(\s*)items=([0-9]+);$', lines[items_line])
    assert m and int(m.group(2)) == items_val
    lines[items_line] = f"{m.group(1)}items={items_val+1};"
    # insert block text right before the Groups closing line (close_line)
    # 'block' already ends with nl; splitting on nl gives its constituent lines + trailing ''
    block_lines = block.split(nl)[:-1]
    new_lines = lines[:close_line] + block_lines + lines[close_line:]
    return (nl.join(new_lines)).encode("cp1252")


def verify(data):
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n")
    print(f"file sha256={sha(data)}")
    print(f"bytes={len(data)} CRLF={crlf} total-LF={lf} all-CRLF={crlf==lf}")
    text = data.decode("cp1252")
    results, leftover = parse_counts(text.replace("\r\n", "\n"))
    bad = [r for r in results if not r[4]]
    print(f"blocks-with-items checked={len(results)} mismatches={len(bad)} stack-leftover={leftover}")
    for r in bad:
        print(f"  MISMATCH line {r[0]} <{r[1]}> declared={r[2]} actual={r[3]}")
    for r in results:
        if r[1] == 'Groups':
            print(f"Groups: declared={r[2]} actual={r[3]} ok={r[4]} (items= at line {r[0]})")
    wp = re.findall(r'name="WFBE_USV_WP_CH_(\d+)"', text)
    idxs = sorted(int(x) for x in wp)
    contiguous = idxs == list(range(1, len(idxs) + 1))
    print(f"WFBE_USV_WP_CH_* present={idxs} contiguous-from-1={contiguous} count={len(idxs)} (>=2 required)")
    return len(bad) == 0 and (crlf == lf) and leftover == 0


def main():
    data = load(SQM)
    if "--author" in sys.argv:
        nl = "\r\n" if data.count(b"\r\n") else "\n"
        newdata = author(data, nl)
        with open(SQM, "wb") as f:
            f.write(newdata)
        print("== AUTHORED ==")
        data = load(SQM)
    print("== VERIFY ==")
    ok = verify(data)
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
