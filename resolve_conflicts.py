import re, sys

CONST_FILES = [
    r"Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf",
]

ALLOC_FILES = [
    r"Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Allocate.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Allocate.sqf",
]

CONFLICT_RE = re.compile(r"<<<<<<< HEAD\r\n(.*?)\r\n=======\r\n(.*?)>>>>>>> [^\r\n]*\r\n", re.DOTALL)

TARGET_TAIL = "\t\t\tif (!isNull _tgt) then {\r\n"

def resolve_const(path):
    with open(path, "r", newline="") as f:
        text = f.read()
    matches = list(CONFLICT_RE.finditer(text))
    if not matches:
        print(f"NO CONFLICT MARKERS in {path}")
        return False
    assert len(matches) == 1, f"expected 1 conflict block in {path}, found {len(matches)}"
    m = matches[0]
    head_part, pr_part = m.group(1), m.group(2)
    replacement = head_part + "\r\n" + pr_part
    new_text = text[:m.start()] + replacement + text[m.end():]
    assert "<<<<<<<" not in new_text and ">>>>>>>" not in new_text
    with open(path, "w", newline="") as f:
        f.write(new_text)
    print(f"RESOLVED (const-append) {path}")
    return True

def resolve_alloc(path):
    with open(path, "r", newline="") as f:
        text = f.read()
    matches = list(CONFLICT_RE.finditer(text))
    if not matches:
        print(f"NO CONFLICT MARKERS in {path}")
        return False
    assert len(matches) == 1, f"expected 1 conflict block in {path}, found {len(matches)}"
    m = matches[0]
    head_part, pr_part = m.group(1), m.group(2)
    head_line = head_part + "\r\n"  # the single modified condition line
    assert pr_part.endswith(TARGET_TAIL), f"unexpected pr_part tail in {path}: {pr_part[-120:]!r}"
    pr_prefix = pr_part[: -len(TARGET_TAIL)]
    replacement = pr_prefix + head_line
    new_text = text[:m.start()] + replacement + text[m.end():]
    assert "<<<<<<<" not in new_text and ">>>>>>>" not in new_text
    with open(path, "w", newline="") as f:
        f.write(new_text)
    print(f"RESOLVED (interleave) {path}")
    return True

if __name__ == "__main__":
    ok = True
    for p in CONST_FILES:
        ok = resolve_const(p) and ok
    for p in ALLOC_FILES:
        ok = resolve_alloc(p) and ok
    sys.exit(0 if ok else 1)
