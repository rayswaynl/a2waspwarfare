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
- **No compression by default.** `mimetype` is `0` for every file entry unless `--compress`
  (alias `--cprs`) is passed. Real BI tools can also emit LZSS-compressed entries
  (`mimetype = 0x43707273`, "Cprs"), and nothing in this project's build lineage ever used
  that — matched here as the default, unchanged behaviour. `--compress` is opt-in, off by
  default, and still gated on a client-join proof before any real deploy uses it. See
  "Cprs text compression" below.
- **No CRLF/text normalization of any kind.** Files are read with `open(path, "rb")` and
  concatenated as raw bytes. This matches every recovered script.

### Evolution of the guard rails (what pack_pbo.py inherited)

| Guard | First seen in | What it does |
|---|---|---|
| Active `#define WF_DEBUG` abort | `_pack_ch_cmdcon41c.py` (07-02) onward | Refuses to pack if `version.sqf` has an uncommented `#define WF_DEBUG` (900k funds, all units unlocked, cheat menu — never a real build). |
| `.template`/`.bak`/`.orig` exclusion | present in every recovered script | Keeps stray backup/template files out of the pack. |
| `version.sqf` existence/non-empty/marker check | `pack_release_ch.py` (07-09) | Full release-candidate marker matching (`WF_RELEASE_MARKER "...candidate=<BUILD>|..."`) — this was a one-off ritual for a specific release branch/tag pairing, not reproduced verbatim here since it assumes a marker format that isn't guaranteed for every future build. `pack_pbo.py` keeps the *existence/non-empty* half of this guard generically (see "version.sqf" below) but does not enforce a specific marker string. |
| Lowercase-collision guard | `pack_release_ch.py` (07-09) | Refuses to pack if lowercasing would make two originally-different-case source paths collide onto one entry (silently dropping one). Reproduced in `pack_pbo.py` as `check_lowercase_collisions()`. Note: unreachable when the source tree lives on a Windows/NTFS disk (case-insensitive filesystem — two such files literally can't coexist there); it matters if a source is ever drawn from a case-sensitive filesystem or an archive. |
| `WF_MAXPLAYERS`/lobby-slot consistency guard | 2026-08-02 | Refuses to pack when the human capacity in `version.sqf` disagrees with `mission.sqm` after excluding reserved headless-client and caster seats. This catches stale deployment headers before they become live PBO provenance/runtime ambiguity. |
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
- Before writing the PBO, the packer counts authored `player=` entries in `mission.sqm`,
  subtracts `forceHeadlessClient=1` and `wfbe_caster_slot` seats, and requires the result
  to equal `WF_MAXPLAYERS`. A mismatch aborts the build with the counted values; this is
  a release-integrity check, not a live-runtime fix.

### Prefix

The PBO's `prefix` property defaults to the source folder's own name (e.g.
`[55-2hc]warfarev2_073v48co.chernarus`). With `--build-tag TAG`, it follows the exact
naming convention every recovered script used —
`[55-2hc]warfarev2_073v48co_<TAG>.chernarus` — but derived generically from whatever
folder name is passed in, rather than hardcoded per build like the original scripts were.
`--prefix` overrides this entirely if you need something else (e.g. a dedicated internal
name like the PrTestHarness's `WASP_Experital_TEST.Chernarus`).

## Cprs text compression (`--compress` / `--cprs`, opt-in)

The WASP mission PBO is ~17.5 MB per terrain × 3, and every joining player downloads it in
full before they can play. `Tools/Pack/cprs.py` implements the real BIS "Cprs" LZSS scheme
(ported from `BIS.Core.Compression.LZSS` in the third-party
[Braini01/bis-file-formats](https://github.com/Braini01/bis-file-formats) library — see that
module's docstring for the full provenance chain; the BI wiki page for this format is behind
a CAPTCHA no environment touching this repo could clear, and no `.pbo` on any machine involved
in this investigation — this repo's own builds, the Steam-installed base game, third-party
addons — actually contains a compressed entry to reverse-engineer from directly). `pack_pbo.py`
can now write those entries when `--compress` (alias `--cprs`) is passed; the default (flag
omitted) is byte-for-byte identical to every build before this feature existed.

**Do not use `--compress` for a real deploy yet.** Server-side engine acceptance is proven
(see "Boot-test evidence" below); client-side load is not. See "Client-join proof protocol"
below for what still has to happen before a compressed wave ships.

### What gets compressed, and why

Only text/config entries, matching the mission-pbo-bloat program's own corpus definition
(the set `test_cprs.py`'s round-trip proof and the TEST-box boot test both used):

```
.sqf .hpp .ext .sqm .fsm .html .bikb .xml
```

`.paa` / `.ogg` / `.wss` and other already-compressed binary formats are never touched —
LZSS would only make them larger. This followed a real refutation: an earlier proposal to
quote a whole-corpus zlib ratio (3.32×–3.9×) as the expected win was killed on adversarial
review because PBO `Cprs` is necessarily **per-entry** (the engine fetches one asset by
name/offset and must decompress it alone, no shared dictionary across files), and BIS LZSS
is a materially weaker scheme than deflate besides. The real, measured per-entry ratio on
this mission's text corpus is **2.42×** (890 real files, 8,851,149 → ~3,658,000 bytes) — see
`Tools/Pack/test_cprs.py::test_all_real_mission_text_files_round_trip`.

An entry is compressed only if it clears every gate in `compress_entries()`
(`Tools/Pack/pack_pbo.py`):

1. Extension is in the list above.
2. Size is `>= 1024` bytes (`REAL_LZSS_MIN_SIZE`) — this matches the real BIS packer/reader
   convention (`BinaryReaderEx`/`WriterEx.ReadLZSS`/`WriteLZSS`'s own `< 1024` guard, per
   `cprs.py`'s provenance docstring): a real packer never actually LZSS's an entry below this
   size regardless of the mimetype tag, and a real reader reads it raw either way. Both
   `read_pbo.py`'s decompressor and `pack_pbo.py`'s writer honour the identical threshold —
   getting this wrong in either direction would silently desync from a real engine.
3. The compressed result is actually smaller than the original (rare for already-dense text,
   but LZSS framing overhead makes it possible; such entries fall back to uncompressed).

Every entry that passes those gates is immediately round-tripped through `cprs.decompress()`
inside `compress_entries()` and compared byte-for-byte against the original **before** being
accepted into the PBO — a codec bug aborts the pack right there. `self_check()` independently
re-verifies the same contract from the fully assembled bytes afterward (decompresses every
Cprs-tagged entry, confirms it recovers exactly `original_size` bytes, and rejects any
Cprs-tagged entry below the 1024-byte threshold that this writer should never produce) — two
independent passes, not one function grading its own homework twice.

### Round-trip proof

- `python Tools/Pack/test_cprs.py` (or `python -m pytest Tools/Pack -q`) — the codec itself:
  synthetic edge cases (empty input, window-boundary sizes, checksum-corruption detection)
  plus **900/900 real mission text files** (9,100,369 bytes) under
  `Missions/[55-2hc]warfarev2_073v48co.chernarus`, byte-identical after `compress()` →
  `decompress()`.
- `python Tools/Pack/test_pack_pbo.py` — `PackPboCompressionTests` (7 cases): large text
  entries get Cprs-tagged and shrink; `read_pbo.py`'s independent decompressor recovers them
  byte-identical; sub-1024-byte and non-text-suffix entries are never touched even with
  `--compress`; `compress=False` is byte-identical to the flag never having existed;
  `self_check()` rejects a synthetic sub-threshold Cprs entry and a corrupted compressed
  payload.
- **All three launch missions**, packed with `--compress` from this worktree and validated
  with the independent reader (`read_pbo.py --diff-source`, a from-scratch second parser —
  not the writer grading its own output):

  | Mission | Uncompressed | Compressed | Reduction | `read_pbo.py --diff-source` |
  |---|---|---|---|---|
  | Chernarus (`[55-2hc]…`) | 17,704,799 B | 12,372,597 B | −30.1% (5,332,202 B saved) | 1005 byte-identical, 0 mismatched, 1 not-found (`version.sqf`, synthesized from template — gitignored by design, expected) |
  | Takistan (`[61-2hc]…`) | 17,589,597 B | 12,285,880 B | −30.2% (5,303,717 B saved) | 1005 byte-identical, 0 mismatched, 1 not-found (same reason) |
  | Zargabad (`[61-2hc]…`) | 17,538,209 B | 12,274,542 B | −30.0% (5,263,667 B saved) | 1005 byte-identical, 0 mismatched, 1 not-found (same reason) |
  | **Total (×3 terrains)** | **52,832,605 B** | **36,933,019 B** | **−30.1% (15,899,586 B saved)** | |

  Every compressed PBO's own checksum trailer also verified OK (`read_pbo.py`'s header dump:
  `distinct entry mimetypes: ['0x0', '0x43707273']`, `checksum(...) OK`). Reproduce with:

  ```powershell
  python Tools\Pack\pack_pbo.py --source "Missions\[55-2hc]warfarev2_073v48co.chernarus" --output ch_compressed.pbo --build-tag proof --compress --force
  python Tools\Pack\read_pbo.py ch_compressed.pbo --diff-source "Missions\[55-2hc]warfarev2_073v48co.chernarus"
  ```

### Boot-test evidence (server-side acceptance — separate investigation, cited here)

This is NOT this PR's own test — it is prior, already-performed work on branch
`pbo/cprs-experiment` (commit `c50b94422e` + an uncommitted `pack_pbo.py --compress-text`
extension in that investigation's own worktree) that this PR's `--compress` reproduces the
byte-level behaviour of. Real boot on the TEST box (`78.46.107.142`, "Miksuu's Warfare Test
Server", via the `Arma2OA-PR8` service — **not** the live WASP box):

- Compressed Chernarus PBO: **12,266,307 bytes vs 17,454,965 control (−29.7%)** (that
  investigation's own point-in-time source tree; this PR's independently-repacked figures
  above are −30.1% on the current tree — consistent, not identical, as expected for a tree
  that has moved on since).
- Server RPT: `Mission …_cprstest.chernarus: Number of roles (38) is different from
  'description.ext::Header::maxPlayer' (34)` — this line only exists if the engine
  successfully **parsed the compressed `description.ext`** to read `maxPlayer`, and the
  role count itself comes from parsing the compressed `mission.sqm`. Both were Cprs-tagged
  in that build. The **identical** warning (same numbers) also appears in the uncompressed
  control boot from the same session — proof the compressed parse produced the same result
  as the uncompressed one, not a different/degraded one.
- `XEH: PreInit Started … MISSINIT: missionName=…_cprstest, worldName=chernarus,
  isMultiplayer=true, isServer=true, isDedicated=true` followed by `XEH: PostInit Finished`
  with `_startInitDone=true, _postInitDone=true` — full mission init reached.
  Zero file-read / corruption / "cannot open" errors anywhere in that session's RPTs.
- The only errors present (`Server error: Player without identity "HC-AI-Control-2"`) are
  the rig's pre-documented HC/BattlEye identity plateau — environmental, reproduced
  identically in the uncompressed control boot from the same session, not PBO-related.

**This proves the A2OA 1.64 dedicated server reads and correctly parses a Cprs-compressed
mission PBO.** It does not prove a connecting game client does — see below.

### Client-join proof protocol (the ship blocker — NOT performed by this PR)

The boot-test above only exercises the **server's** own parse of the compressed entries.
Every joining player's game client downloads and loads the same PBO through the same
engine code path, but under different conditions (streamed download vs local disk read,
client-side mission cache), and nothing in either investigation to date has taken an actual
client connection against a Cprs-compressed WASP PBO. This is the one remaining gap between
"proven safe to build" and "proven safe to ship."

Protocol for whoever runs this (owner or an agent with server/game-launch authority — this
PR's author is explicitly barred from touching the live box or launching the game):

1. **Stage, don't replace.** Build the compressed PBO with `pack_pbo.py --compress` using a
   real (not template-fallback) `version.sqf`. Drop it into the TEST box
   (`78.46.107.142`, already used for the server-side boot test above — never the live box
   for this step) or a local dedicated-server instance, alongside — not instead of — the
   normal uncompressed build.
2. **Boot and grade.** Start the dedicated server on the compressed PBO. Once it reaches
   `MISSINIT`, grade the RPT with the repo's existing read-only gate:
   ```powershell
   pwsh Tools\Smoke\Test-WaspBootSmoke.ps1 -ServerRpt <path-to-arma2oaserver.RPT>
   ```
   This repeats the boot-test evidence above in a form CI/the soak farm can consume, but it
   does **not** launch anything itself — it only grades an RPT a real server run already
   produced (see `Tools/Smoke/README.md`: "Read-only. It observes and asserts; it never
   modifies the mission... or the box"). Launching the dedicated server and a game client are
   both out of scope for any tool in this repo and out of scope for this agent's authority —
   they are the orchestrator/owner's step, same as every prior boot test in this program.
3. **Client joins.** Owner (or a designated test client) connects to the compressed-PBO
   session directly (not JIP into an already-running uncompressed one). Confirm:
   - The client completes its mission download/load without a "Cannot read/verify PBO" or
     signature-style error.
   - No new error class appears in either the server or client RPT that the uncompressed
     control doesn't also produce.
   - In-game: loading screen, briefing, and at least one asset from a Cprs-compressed
     `.sqf`-driven system (e.g. an action menu entry, since `client\action\*.sqf` are all
     large enough to compress) function normally.
4. **Instant rollback.** Per `docs/ops/SERVER-STARTUP-ROTATION.md`'s existing park model,
   only one map PBO is ever active in `MPMissions` at a time, with the other builds resting
   in `C:\WASP\mission-park\{ch,tk,zg}\`. Keep the current uncompressed wave PBOs parked and
   untouched throughout this test — rollback is "put the uncompressed PBO back in
   `MPMissions`," a file swap, not a rebuild. Do this on the very first sign of a
   client-side load anomaly.
5. **Graduate.** Only after a clean client-join session (and, per standing owner policy, only
   in an owner-present window) does `--compress` become eligible for an actual wave ship.
   Until then this flag exists, is tested, and is documented — but is not live-ready.

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
4. **Regression tests**: `Tools/Pack/test_pack_pbo.py` (13 cases — round trip with
   synthesized `version.sqf`, `--strict-version` enforcement, missing-template abort,
   active-`WF_DEBUG` abort/`--allow-debug` override, lowercase-collision guard,
   overwrite protection, byte-identical diff against a real `version.sqf`, and
   `WF_MAXPLAYERS`/lobby-slot consistency including reserved HC/caster seats). Wired into
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
