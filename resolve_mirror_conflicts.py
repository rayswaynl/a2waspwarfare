import re, sys

CONST_FILES = [
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf",
]

ALLOC_FILES = [
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Allocate.sqf",
    r"Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Allocate.sqf",
]

CONFLICT_RE = re.compile(r"<<<<<<< HEAD\r\n(.*?)\r\n=======\r\n(.*?)>>>>>>> [^\r\n]*\r\n", re.DOTALL)
TARGET_TAIL = "\t\t\tif (!isNull _tgt) then {\r\n"

def resolve_const(path):
    with open(path, "r", newline="") as f:
        text = f.read()
    matches = list(CONFLICT_RE.finditer(text))
    assert len(matches) == 1, (path, len(matches))
    m = matches[0]
    old = text[m.start():m.end()]
    head_part, pr_part = m.group(1), m.group(2)
    new = head_part + "\r\n" + pr_part
    assert text.count(old) == 1
    new_text = text.replace(old, new)
    assert "<<<<<<<" not in new_text and ">>>>>>>" not in new_text
    with open(path, "w", newline="") as f:
        f.write(new_text)
    print(f"RESOLVED (const-append, provisional pre-mirror-regen) {path}")

def resolve_alloc(path):
    with open(path, "r", newline="") as f:
        text = f.read()
    matches = list(CONFLICT_RE.finditer(text))
    assert len(matches) == 1, (path, len(matches))
    m = matches[0]
    old = text[m.start():m.end()]
    head_part, pr_part = m.group(1), m.group(2)
    head_line = head_part + "\r\n"
    assert pr_part.endswith(TARGET_TAIL), pr_part[-120:]
    pr_prefix = pr_part[: -len(TARGET_TAIL)]
    new = pr_prefix + head_line
    assert text.count(old) == 1
    new_text = text.replace(old, new)
    assert "<<<<<<<" not in new_text and ">>>>>>>" not in new_text
    with open(path, "w", newline="") as f:
        f.write(new_text)
    print(f"RESOLVED (interleave, provisional pre-mirror-regen) {path}")

if __name__ == "__main__":
    for p in CONST_FILES:
        resolve_const(p)
    for p in ALLOC_FILES:
        resolve_alloc(p)
