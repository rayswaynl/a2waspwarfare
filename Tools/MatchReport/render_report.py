#!/usr/bin/env python3
"""
CLI for the WASP post-match report renderer.

  python render_report.py --sample              -> render the built-in demo match
  python render_report.py --waspstat match.log  -> render from raw WASPSTAT lines
  python render_report.py --waspstat - < feed   -> read WASPSTAT lines from stdin

Options:
  -o, --out PATH     output mp4 (default: wasp_report_<map>.mp4)
  --names FILE       optional "uid<TAB>name" lines to label players (real matches:
                     names join from the players table; WASPSTAT carries only UIDs).

See README.md for the data flow and the production-wiring TODOs.
"""
import argparse, sys, time
from render import render

def load_names(path):
    names = {}
    if not path: return names
    with open(path, encoding="utf-8") as fh:
        for ln in fh:
            if "\t" in ln:
                uid, nm = ln.rstrip("\n").split("\t", 1); names[uid.strip()] = nm.strip()
    return names

def main():
    ap = argparse.ArgumentParser(description="Render a WASP post-match report video.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--sample", action="store_true", help="use the built-in demo match")
    src.add_argument("--waspstat", metavar="FILE", help="raw WASPSTAT telemetry ('-' = stdin)")
    src.add_argument("--leaderboard", action="store_true", help="render the real server leaderboard from the live DB")
    ap.add_argument("--names", metavar="FILE", help="optional uid<TAB>name mapping")
    ap.add_argument("-o", "--out", help="output mp4 path")
    args = ap.parse_args()

    if args.leaderboard:
        from leaderboard_data import load_leaderboard
        from render import render_leaderboard, caption_leaderboard
        data = load_leaderboard()
        if not data.players: sys.exit("No players in ingame_stats.")
        out = args.out or "wasp_leaderboard.mp4"
        t0 = time.time(); n = render_leaderboard(data, out)
        print(f"rendered {n} frames ({n/30:.1f}s) in {time.time()-t0:.1f}s -> {out}")
        with open(out + ".caption.txt", "w", encoding="utf-8") as fh: fh.write(caption_leaderboard(data))
        print("caption -> " + out + ".caption.txt")
        return

    if args.sample:
        from sample_match import build_sample
        m = build_sample()
    else:
        from matchdata import parse_waspstat
        fh = sys.stdin if args.waspstat == "-" else open(args.waspstat, encoding="utf-8", errors="replace")
        lines = fh.readlines()
        m = parse_waspstat(lines, names=load_names(args.names))
        if not m.players and not m.caps:
            sys.exit("No WASPSTAT records parsed — is the gate WFBE_C_STATLOG=1 and the file correct?")

    out = args.out or f"wasp_report_{m.map_name.lower()}.mp4"
    t0 = time.time()
    n = render(m, out)
    print(f"rendered {n} frames ({n/30:.1f}s video) in {time.time()-t0:.1f}s -> {out}")
    # sidecar caption for the Discord/TikTok post
    from render import caption
    cap = caption(m)
    with open(out + ".caption.txt", "w", encoding="utf-8") as fh: fh.write(cap)
    print("caption -> " + out + ".caption.txt")

if __name__ == "__main__":
    main()
