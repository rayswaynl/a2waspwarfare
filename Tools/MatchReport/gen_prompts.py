#!/usr/bin/env python3
"""Print the ChatGPT prompt pack for the report's generated art.

Each block is ready to paste into ChatGPT (image-gen-2). Generate the image, then
SAVE IT under assets/ using the exact 'SAVE AS' filename — that filename is how the
renderer finds it and how we keep track of which output is which.

    python gen_prompts.py            # all slots
    python gen_prompts.py emblem     # only slots whose id contains 'emblem'
"""
import sys
from assets import ASSETS, NEGATIVE

flt = sys.argv[1] if len(sys.argv) > 1 else ""
print("="*72)
print("MIKSUU'S WARFARE MATCH-REPORT — IMAGE-GEN PROMPT PACK")
print("Style follows  miksuus-warfare/brand/IMAGE-GEN-BRIEF.md  (STYLE SUFFIX baked in).")
print("Save each output to  Tools/MatchReport/assets/<SAVE AS>  (exact name).")
print("="*72)
print("\nNEGATIVE PROMPT (paste once, if the tool supports one):")
print(NEGATIVE)
print("="*72)
# Backgrounds worth generating extra variants of — the renderer auto-rotates among any
# <stem>_k.png siblings by match seed, so a feed of many reports never reuses the same frame.
VARIANT_SLOTS = ["intro_splash","winner_bg_blufor","winner_bg_opfor","winner_bg_guer",
                 "mvp_backdrop","bg_momentum","outro_bg"]
if flt == "variants":
    import os
    nvar = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    print(f"\nVARIANT POOL — drop each as <stem>_k.png; the renderer rotates by match seed.\n" + "="*72)
    for aid in VARIANT_SLOTS:
        a = ASSETS.get(aid)
        if not a: continue
        stem, ext = os.path.splitext(a["file"])
        for k in range(2, nvar+1):
            print(f"\n### {aid}  VARIANT {k}")
            print(f"SAVE AS : {stem}_{k}{ext}")
            print(f"SIZE    : {a['size'][0]}x{a['size'][1]}")
            print("VARY    : keep the EXACT style; change the composition — different camera angle, "
                  "dusk time-of-day, haze, vehicle placement — so it reads as a fresh frame.")
            print("PROMPT  :"); print(a["prompt"])
else:
    for aid, a in ASSETS.items():
        if flt and flt not in aid: continue
        w, h = a["size"]; alpha = "transparent PNG" if a["transparent"] else "opaque PNG/JPG"
        print(f"\n### {aid}   [{a['role']}]")
        print(f"SAVE AS : {a['file']}")
        print(f"SIZE    : {w}x{h}   ({alpha})")
        print("PROMPT  :"); print(a["prompt"])
print("\n" + "="*72)
print("All slots: python gen_prompts.py     |     Variant pool: python gen_prompts.py variants 3")
print("Drop files in assets/ and re-render — present art is used; missing falls back to procedural.")
