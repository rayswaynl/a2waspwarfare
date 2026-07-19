import re, sys

CONST_PATH = r"Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
ALLOC_PATH = r"Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf"

CONFLICT_RE = re.compile(r"<<<<<<< HEAD\r\n(.*?)\r\n=======\r\n(.*?)>>>>>>> [^\r\n]*\r\n", re.DOTALL)

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
    print(f"RESOLVED (const-append) {path}  old_len={len(old)} new_len={len(new)}")

def resolve_alloc(path):
    TARGET_TAIL = "\t\t\tif (!isNull _tgt) then {\r\n"
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
    print(f"RESOLVED (interleave) {path}  old_len={len(old)} new_len={len(new)}")

if __name__ == "__main__":
    resolve_const(CONST_PATH)
    resolve_alloc(ALLOC_PATH)
