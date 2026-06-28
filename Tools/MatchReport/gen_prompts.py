#!/usr/bin/env python3
"""Print the ChatGPT prompt pack for the report's generated art.

Each block is ready to paste into ChatGPT (image-gen-2). Generate the image, then
SAVE IT under assets/ using the exact 'SAVE AS' filename — that filename is how the
renderer finds it and how we keep track of which output is which.

    python gen_prompts.py            # all slots
    python gen_prompts.py emblem     # only slots whose id contains 'emblem'
"""
import sys
from assets import ASSETS

flt = sys.argv[1] if len(sys.argv) > 1 else ""
print("="*72)
print("WASP MATCH-REPORT — IMAGE-GEN PROMPT PACK")
print("Save each output to  Tools/MatchReport/assets/<SAVE AS>  (exact name).")
print("="*72)
for aid, a in ASSETS.items():
    if flt and flt not in aid: continue
    w, h = a["size"]; alpha = "transparent PNG" if a["transparent"] else "opaque PNG/JPG"
    print(f"\n### {aid}   [{a['role']}]")
    print(f"SAVE AS : {a['file']}")
    print(f"SIZE    : {w}x{h}   ({alpha})")
    print("PROMPT  :")
    print(a["prompt"])
print("\n" + "="*72)
print("After dropping files in assets/, just re-render — present art is used,")
print("missing art falls back to the procedural look.")
