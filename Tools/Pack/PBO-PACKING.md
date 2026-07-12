# PBO packing — `Tools/Pack/pack_pbo.py`

This is the recovered, documented, version-controlled replacement for the hand-rolled
`_pack_*.py` scripts that, until now, only ever existed on the Game PC build box. Nobody
had them checked in anywhere; the only way to reproduce a launch PBO was to already be
sitting at that one machine. This tool closes that gap.

## TL;DR — pack the 3 launch missions

Run from the repo root, with Python 3 (stdlib only — no cpbo/armake2/MakePbo required):

```powershell
python Tools\Pack\pack_pbo.py `
  --source "Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  --output "C:\WASP\incoming\[55-2hc]warfarev2_073v48co_<BUILDTAG>.chernarus.pbo" `
  --build-tag <BUILDTAG>

python Tools\Pack\pack_pbo.py `
  --source "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan" `
  --output "C:\WASP\incoming\[61-2hc]warfarev2_073v48co_<BUILDTAG>.takistan.pbo" `
  --build-tag <BUILDTAG>

python Tools\Pack\pack_pbo.py `
  --source "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad" `
  --output "C:\WASP\incoming\[61-2hc]warfarev2_073v48co_<BUILDTAG>.zargabad.pbo" `
  --build-tag <BUILDTAG>
```

Replace `<BUILDTAG>` with whatever build identifier you're shipping (e.g. `wasp-1-3-0-20260715`).
The output filename convention (`<prefix>.pbo` where `<prefix>` is the mission folder name with
`_<BUILDTAG>` inserted before the terrain suffix) matches what `docs/ops/SERVER-STARTUP-ROTATION.md`
documents the live deploy/rotation tooling already expects (see its "Active-map PBO name" table) —
this is not a new convention, it's the one the box has been using all along.

Each mission folder needs a real `version.sqf` for an actual deploy (see "version.sqf" below). If
you run the command above straight after a fresh clone, the tool will notice `version.sqf` is
missing (it's gitignored by design), fall back to `version.sqf.template`, and print a warning — fine
for a structural/smoke build, **not** fine for anything that ships.

For a strict release build that refuses to substitute the template, add `--strict-version`.

## What the tool does, and why it looks like this

### Provenance

Recovered read-only from the Game PC (`ssh gamingpc`, box left untouched) on 2026-07-12:

- `C:\Users\Game\_pack_*.py` — 55 scripts, oldest recovered is `_pack_b48_pbo.py`
  (~2026-06, packs from a zip export), newest at that path is
  `_pack_ch_cmdcon41c.py` / `_pack_tk_cmdcon41c.py` (2026-07-02).
- `C:\Users\Game\wasp-build\*.py` — the same lineage continuing past 07-02:
  `_pack_{ch,tk,zg}_cmdcon42.py` … `cmdcon44t.py` (through 2026-07-05), then a renamed,
  no-longer-per-build-hardcoded generation: `pack_release_ch.py`, `pack_wasp120_ch.py`,
  `pack_wasp121_{ch,zg}.py`, `pack_zgt1.py`, `pack_zgt2.py`, `pack_rigtest_ch.py`,
  `pack_stresstest_zg.py` (2026-07-09/10), plus a reader, `list_pbo_entries.py` (07-09).
- Every single script recovered — oldest to newest, Chernarus/Takistan/Zargabad alike —
  writes **byte-for-byte the same header/entry/checksum layout**. The format did not
  drift; only the guard rails around it got stricter over time (see "Evolution" below).
- Two known-good reference PBOs were pulled read-only from the box for structural
  comparison (kept local only, never committed — see "Reference PBOs" below):
  `wasp-armedtest-20260712e-ch.pbo` and `wasp-1-2-1-20260710-zg.pbo`.
- The other candidate recovered per the same investigation,
  `Tools/PrTestHarness/Experital/Pack-WaspExperital.ps1` (branch
  `tools/reusable-pr-test-harness`, unmerged), takes a different approach entirely: it
  shells out to `cpbo.exe` / `armake2.exe` / `MakePbo.exe`, whichever is found on PATH.
  None of those are installed on any machine touched by this investigation, and the
  actual Game PC scripts never called out to one either — they always hand-wrote the
  binary format directly, which is what `pack_pbo.py` continues to do.

### The binary format

Every recovered script (and this tool) writes:

1. **Header/"Vers" entry** — empty name, then 5×`uint32` little-endian:
   `(mimetype=0x56657273 "Vers", original_size=0, reserved=0, timestamp=0, data_size=0)`.
   The magic value tells a reader a properties block follows.
2. **Properties block** — null-terminated `key`, null-terminated `value`, repeated,
   terminated by one empty (zero-length) string. Only one property is ever written:
   `prefix` → the mission's internal identity string (see "Prefix" below).
3. **One entry per file** — null-terminated relative path (backslash-separated,
   lowercased — see "Divergence" below), then 5×`uint32` LE:
   `(mimetype=0 "uncompressed", original_size=len(data), reserved=0, timestamp=0,
   data_size=len(data))`. `mimetype` is always `0` and `data_size` always equals
   `original_size` — nothing in this lineage ever compresses an entry.
4. **Terminator entry** — empty name, all 5 fields zero.
5. **Raw file data**, concatenated in the exact order of the entries above. No padding,
   no line-ending translation — files are read and written as opaque bytes.
6. **Checksum trailer** — one `0x00` byte, then a 20-byte SHA1 digest. The digest is
   computed over everything from byte 0 up to (but **not including**) that trailing
   `0x00` byte — i.e. `sha1(header + all file data)`, with the zero byte itself excluded
   from the hash. This specific hash-boundary convention is what every recovered script
   used and what the live server has been loading successfully for weeks, so it's treated
   as ground truth rather than any generic textbook description of "PBO checksums" (the
   public BI PBO format writeups are not fully explicit about which side of that leading
   zero byte the hash boundary falls on — this codebase's own working history settles it).

This matches the general shape of the publicly documented Arma PBO format (BI wiki /
community packer implementations): a "Vers"-tagged properties header, a null-terminated
file table with 5 trailing `uint32` fields per entry, a zero-entry terminator, then data,
then an optional SHA1 trailer. The recovered scripts are a faithful, minimal, hand-rolled
implementation of that format — this tool is a generalized continuation of the same thing.

### Divergences from a "by the book" packer (intentional, and why)

- **Every stored path is lowercased.** The earliest recovered scripts (through
  `_pack_ch_cmdcon44t.py`, 2026-07-05) preserved source casing. `pack_release_ch.py`
  (2026-07-09) added a lowercase pass with this comment in place, verbatim from the
  script:

  > owner-reported bug 2026-07-09: real PBO packers (MakePbo/pboProject) lowercase every
  > internal path. This hand-rolled packer previously preserved case, so
  > `loadScreen.jpg` got stored case-preserved, but Arma's texture-asset lookup
  > lowercases the path it searches for, so the lookup missed and the client threw
  > `Cannot load texture ... loadscreen.jpg`.

  `pack_pbo.py` keeps this fix as the default (there is no opt-out — reproducing the bug
  on purpose would be pointless). Confirmed against both downloaded reference PBOs: **zero**
  entries with any uppercase character in either.
- **No compression, ever.** `mimetype` is hardcoded to `0` for every file entry. Real BI
  tools can also emit LZSS-compressed entries (`mimetype = 0x43707273`), but nothing in
  this project's build lineage ever used that — replicated here as-is, not as a
  limitation to fix later.
- **No CRLF/text normalization of any kind.** Files are read with `open(path, "rb")` and
  concatenated as raw bytes. This matches every recovered script.

### Evolution of the guard rails (what pack_pbo.py inherited)

| Guard | First seen in | What it does |
|---|---|---|
| Active `#define WF_DEBUG` abort | `_pack_ch_cmdcon41c.py` (07-02) onward | Refuses to pack if `version.sqf` has an uncommented `#define WF_DEBUG` (900k funds, all units unlocked, cheat menu — never a real build). |
| `.template`/`.bak`/`.orig` exclusion | present in every recovered script | Keeps stray backup/template files out of the pack. |
| `version.sqf` existence/non-empty/marker check | `pack_release_ch.py` (07-09) | Full release-candidate marker matching (`WF_RELEASE_MARKER "...candidate=<BUILD>|..."`) — this was a one-off ritual for a specific release branch/tag pairing, not reproduced verbatim here since it assumes a marker format that isn't guaranteed for every future build. `pack_pbo.py` keeps the *existence/non-empty* half of this guard generically (see "version.sqf" below) but does not enforce a specific marker string. |
| Lowercase-collision guard | `pack_release_ch.py` (07-09) | Refuses to pack if lowercasing would make two originally-different-case source paths collide onto one entry (silently dropping one). Reproduced in `pack_pbo.py` as `check_lowercase_collisions()`. Note: unreachable when the source tree lives on a Windows/NTFS disk (case-insensitive filesystem — two such files literally can't coexist there); it matters if a source is ever drawn from a case-sensitive filesystem or an archive. |
| Debug-stress-hook absence check | `pack_release_ch.py` (07-09) | Specific to one release lane (asserts a particular stress-test hook string is absent). Not reproduced — too specific to be general. |

`pack_pbo.py` is deliberately **general** (one script, parameterized by `--source`/
`--output`/`--build-tag`/`--prefix`), not a 91st copy-pasted-per-build script. Anything in
the historical guard list that was inherently one-build-specific (the exact release marker
string, the debug-stress-hook name) was left out rather than baked in as a false sense of
safety; the universal ones (WF_DEBUG, template exclusion, lowercase collisions, version.sqf
presence) are all still enforced.

### `version.sqf`

`description.ext` and `initJIPCompatible.sqf` both `#include "version.sqf"`, so a PBO
without one fails to load with `Include file ... version.sqf not found`. The real
`version.sqf` is gitignored per-mission (it differs per deployment context — player count,
mission title, per-map constants) — only `version.sqf.template` is tracked.

- If a real `version.sqf` exists on disk under `--source`, it's used as-is (and the
  `WF_DEBUG` guard runs against it).
- If it's missing, `pack_pbo.py` falls back to `version.sqf.template` **in memory only**
  (nothing is written to your working tree) and prints a warning. This mirrors what
  `Pack-WaspExperital.ps1` does explicitly (it writes a generated `version.sqf` before
  packing) — the difference here is the fallback is synthetic/in-memory and clearly
  flagged, not silently written to disk.
- Pass `--strict-version` to refuse the fallback and require a real file — use this for
  anything that's actually going to be deployed.

### Prefix

The PBO's `prefix` property defaults to the source folder's own name (e.g.
`[55-2hc]warfarev2_073v48co.chernarus`). With `--build-tag TAG`, it follows the exact
naming convention every recovered script used —
`[55-2hc]warfarev2_073v48co_<TAG>.chernarus` — but derived generically from whatever
folder name is passed in, rather than hardcoded per build like the original scripts were.
`--prefix` overrides this entirely if you need something else (e.g. a dedicated internal
name like the PrTestHarness's `WASP_Experital_TEST.Chernarus`).

## Verification performed

**Structural only — this does NOT confirm A2OA will boot the mission.** See "What still
needs an owner boot-test" below.

1. **Packed all three launch missions** from this worktree (Chernarus, Takistan,
   Zargabad) and ran the self-check built into `pack_pbo.py` (header magic, entry count).
2. **Independent round-trip validation** with `Tools/Pack/read_pbo.py` — a from-scratch
   second implementation of the parser (not sharing code with the writer). For a clean
   copy of the Chernarus mission (real `version.sqf` copied in from the template so there's
   nothing gitignored in the way):

   ```
   diff-source: 912 byte-identical, 0 mismatched, 0 not found under source
   trailer: 21 bytes, leading byte=0, checksum(SHA1 of bytes[0:...]) OK
   ```

   Takistan and Zargabad packed and validated the same way (928 of 929 files
   byte-identical; the one "missing" file in each is the synthetic `version.sqf`, which
   is correctly absent from the on-disk source since it's gitignored — not a bug).
3. **Structural comparison against two known-good reference PBOs** pulled read-only from
   the Game PC (`wasp-armedtest-20260712e-ch.pbo`, `wasp-1-2-1-20260710-zg.pbo` — both
   currently-in-use test builds, not this tool's own output):

   ```
   $ python Tools\Pack\read_pbo.py wasp-armedtest-20260712e-ch.pbo
   properties: {'prefix': '[55-2hc]warfarev2_073v48co_wasp-armedtest-20260712e.chernarus'}
   entry count: 913
   distinct entry mimetypes: ['0x0']            (uncompressed - matches)
   trailer: 21 bytes, leading byte=0, checksum(...) OK   (same checksum scheme - matches)
   entries with any uppercase char stored: 0    (lowercase-fix generation - matches)
   ```

   Same result shape for the Zargabad reference. Header layout, property block shape,
   uncompressed-entry convention, and checksum algorithm/boundary all match what
   `pack_pbo.py` produces. (Entry counts differ from this worktree's current file counts,
   as expected — the reference PBOs were built from a different point-in-time source tree
   on the box, not this checkout; only the *format* was being compared, not the content.)
4. **Regression tests**: `Tools/Pack/test_pack_pbo.py` (7 cases — round trip with
   synthesized `version.sqf`, `--strict-version` enforcement, missing-template abort,
   active-`WF_DEBUG` abort/`--allow-debug` override, lowercase-collision guard,
   overwrite protection, byte-identical diff against a real `version.sqf`). Wired into
   `wasp-ci.yml` alongside the other `Tools/*/test_*.py` suites.

Run it yourself:

```powershell
python Tools\Pack\test_pack_pbo.py
python Tools\Pack\pack_pbo.py --source "Missions\[55-2hc]warfarev2_073v48co.chernarus" --output out.pbo --build-tag smoke
python Tools\Pack\read_pbo.py out.pbo --diff-source "Missions\[55-2hc]warfarev2_073v48co.chernarus"
```

`out.pbo` is gitignored (`Tools/Pack/*.pbo`) — never commit a packed binary.

### What still needs an owner boot-test

This verification is entirely structural: correct header layout, correct entry table,
byte-identical file contents, correct checksum. **None of it proves Arma 2: OA will
actually load the resulting PBO on a real dedicated server.** Before treating this tool
as fully launch-ready, the owner (or someone with server access) needs to:

- Drop a `pack_pbo.py`-built PBO into a real (or local test) MPMissions folder with a real
  (not template-fallback) `version.sqf` and confirm the server selects it and reaches
  `MISSINIT` without errors in the RPT.
- Spot-check in-game that a couple of known assets load correctly (this is exactly the
  class of bug the lowercase fix targeted — e.g. the loading screen image, a sound file,
  a texture referenced from a nested folder).
- Confirm client-side JIP and headless-client connect against a `pack_pbo.py`-built PBO
  the same way they do against the existing hand-packed builds.

## Reference PBOs (not in this PR)

Two known-good PBOs (`wasp-armedtest-20260712e-ch.pbo`, `wasp-1-2-1-20260710-zg.pbo`) were
pulled read-only from `C:\Users\Game\wasp-build\` on the Game PC for the structural
comparison above. They are binary build artifacts and are **not** included in this PR —
kept local only, per the constraint that reference PBOs never get committed to the repo.
