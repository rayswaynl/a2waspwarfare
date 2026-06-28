#!/usr/bin/env python3
"""
A/B (or N-way) compare intro-splash candidates IN CONTEXT — each composited into
the real report intro (mark + wordmark + title), side by side, labelled.

  python ab_compare.py                      # baseline (no splash) vs assets/intro_splash.png
  python ab_compare.py "A=foo.png" "B=bar.png" "C="   # explicit; empty path = no splash
  python ab_compare.py ... -o out.png

This is what actually matters for picking art: how it reads behind the title,
not the raw plate. Drop Codex's diffusion splash in as another candidate to make
it a procedural-vs-diffusion head-to-head.
"""
import sys, os
from PIL import Image, ImageDraw
import render as R

def intro_frame(splash):
    """Reproduce render.py s_intro for a single still, with the given background."""
    im = Image.new("RGB", (R.W, R.H), R.BG)
    if splash and os.path.exists(splash):
        a = Image.open(splash).convert("RGB")
        s = max(R.W/a.width, R.H/a.height)
        a = a.resize((int(a.width*s), int(a.height*s)))
        im.paste(a, ((R.W-a.width)//2, (R.H-a.height)//2))
    d = ImageDraw.Draw(im, "RGBA")
    mk = R.brand_logo("mark")
    if mk is not None:
        m2 = mk.resize((300, 300)); im.paste(m2, (R.W//2-150, R.H//2-450), m2)
    d.text((R.W/2, R.H/2-95), "MIKSUU'S WARFARE", font=R.DISP(92), fill=R.INK, anchor="mm")
    d.text((R.W/2, R.H/2+10), "CHERNARUS", font=R.f_h1, fill=R.GOLD, anchor="mm")
    d.text((R.W/2, R.H/2+92), "POST-MATCH REPORT", font=R.f_h3, fill=R.DIM, anchor="mm")
    d.text((R.W/2, R.H/2+170), "20 operators   ·   43:20   ·   1147 kills", font=R.f_sm, fill=R.DIM, anchor="mm")
    return im

def main():
    out = "ab_intro.png"
    cands = []
    for arg in sys.argv[1:]:
        if arg in ("-o", "--out"): continue
        if sys.argv[sys.argv.index(arg)-1] in ("-o", "--out"): out = arg; continue
        if "=" in arg:
            lbl, pth = arg.split("=", 1); cands.append((lbl, pth or None))
    if not cands:
        sp = os.path.join(os.path.dirname(__file__), "assets", "intro_splash.png")
        cands = [("A · no splash (baseline)", None), ("B · procedural splash", sp)]

    tw = 380; th = int(tw*R.H/R.W); pad = 18; lh = 50
    n = len(cands)
    sheet = Image.new("RGB", (n*tw+(n+1)*pad, pad+lh+th+pad), (26, 29, 34))
    dd = ImageDraw.Draw(sheet)
    for i, (lbl, pth) in enumerate(cands):
        x = pad + i*(tw+pad)
        dd.rectangle([x, pad, x+tw, pad+lh-8], outline=(70, 80, 90))
        dd.text((x+tw/2, pad+(lh-8)/2), lbl, font=R.f_sm, fill=(231, 227, 214), anchor="mm")
        sheet.paste(intro_frame(pth).resize((tw, th)), (x, pad+lh))
    sheet.save(out); print("A/B sheet ->", out, sheet.size)

if __name__ == "__main__":
    main()
