# Design: Optional PLAYER-SIDE client mods for WASP (sound / visual / UI)

Read-only recon deliverable (2026-07-02). Ray wants **optional** client mods — sound/visual/UI addons an
individual player MAY run without every player needing them — sourced from the Jerry bIdentify archive
(`bidentify.jerryhopper.com/files`) and Ray's existing repos. **Nothing here is implemented.** No box writes,
no repo pushes, no mission edits were made producing this doc.

Scope is strict: **client-side visual / audio / UI / HUD only.** Anything that touches simulation, ballistics,
weapon/vehicle stats, AI, or movement/stamina is OUT (it would desync or require every client + the server to
load it — that is the event-modpack lane, not this one).

---

## (a) Current box signature posture — the verdict

**Live box (confirmed 2026-07-02 over read-only SSH, `Administrator@78.46.107.142`):**

- Service: NSSM service **`Arma2OA-PR8`** (DisplayName "Arma 2 OA - Miksuu PR8 Test", **Running**); NSSM at `C:\WASP\nssm\nssm.exe`.
- Exe: `C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\arma2oaserver.exe` (v1.64.144629).
- Launch line (verbatim):
  ```
  arma2oaserver.exe -port=2302 -config=C:\WASP\profiles-pr8\server-pr8.cfg -cfg=C:\WASP\profiles-pr8\basic.cfg
    "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ACR;@CBA_CO;@adwasp;@admkswf"
    -malloc=mimalloc -world=empty
  ```
  No `-serverMod=`, no `-beplugin`/`-bepath`, no `equalModRequired` anywhere.
- Active server config: **`C:\WASP\profiles-pr8\server-pr8.cfg`** (basic.cfg = network tuning only, `MaxCustomFileSize=0`).

**Signature-policy keys as they stand in `server-pr8.cfg`:**

| Key | Literal value | Effect |
|---|---|---|
| `verifySignatures` | **`0`** | No signature check on ANY loaded addon. |
| `equalModRequired` | **absent** (→ off) | Client `-mod` list need NOT match the server's. |
| `checkfiles` | absent | — |
| `regularCheck` | absent | — |
| `kickDuplicate` | **`0`** | — |
| `BattlEye` | **`0`** | BattlEye fully off; no `BattlEye\` folder in the install. |

Server `Keys\` folders in the mod chain contain only: `bi.bikey`, `bi2.bikey` (OA + Expansion) and CBA's
`cba.bikey` / `cba_b196.bikey`. **No WASP/Miksuu publisher key is installed server-side** (the `@adwasp` /
`@admkswf` PBOs even ship `.bisign` for `wasp` / `asr_ai` keys whose `.bikey` is not in any `Keys\` folder —
moot at `verifySignatures=0`, but relevant if v2 is ever turned on).

### VERDICT

> **TODAY a client CAN join with an extra client-only mod — signed OR unsigned — with zero server objection.**
> The server performs no mod/signature enforcement whatsoever (`verifySignatures=0`, `equalModRequired`
> absent, BattlEye off).

- Extra **signed** client mod → joins fine.
- Extra **unsigned** client mod → also joins fine.
- The only real limits are functional, not policy: a client addon that changes networked/synchronized content
  (a gameplay/config mod) can cause a client-side error or desync — but the server will not kick the player for
  merely loading extra addons. Pure cosmetic/local addons (JSRS sound, Blastcore FX, STHUD, tracers) have no
  such issue.

**No config change is required to allow optional client mods.** That is the important part: this is a
distribution/curation exercise, not a server-cfg exercise.

The single line that governs this is `verifySignatures = 0;`. If Ray ever wants to **tighten** to
"signed-optional-only" (block unsigned/cheat addons while still allowing a curated signed set), the change is:

```diff
- verifySignatures = 0;
+ verifySignatures = 2;
```
…**plus** dropping each accepted mod's `.bikey` (and CBA's + the WASP mods' own keys) into a `Keys\` folder in
the server's `-mod` path. Under v2, a client's extra addon loads only if its publisher `.bikey` is present
server-side; unsigned/unknown-key addons get kicked on load. **`equalModRequired` must stay off** — setting it
to `1` would kick any client whose `-mod` list differs from the server's, defeating the whole "optional" idea.

> Caveat carried from Ray's own event research (`a2waspwarfare-events/docs/research/mod-improvement-and-final-sweep.md`
> and `aircraft-catalog.md`): several era mods ship only **v2-incompatible bisigns** (the F/A-18 case), which is
> exactly why every WASP *event* pack chose `verifySignatures=1`. If Ray tightens the live box, prefer **v1**
> over v2 for the same reason, or accept that a few older optional mods won't pass v2.

---

## (b) Recommended architecture

Two viable models. **Because the box is `verifySignatures=0`, Model A (do-nothing-server) already works today
— it's purely a client-distribution convenience.** Model B is only worth the effort if/when Ray tightens the box.

### Model A — curated `@wasp_optional` client pack (RECOMMENDED, works today)

Ship a small, curated, **client-only** modpack that a player drops into their Arma 2 OA folder and adds to their
`-mod` line. It is never on the server's `-mod` line and is never in the mission's `requiredAddons[]`, so the
server runs identically whether a given player has it or not.

- **Contents shortlist** (all client-side-safe; details in the table below):
  - `@CBA_CO` — already the server standard; every regular has it. It is the dependency for STHUD and Blastcore.
    (Not "extra" — listed so the pack's prerequisites are explicit.)
  - `@JSRS1.5` — sound. Classic, runs entirely client-side.
  - `@Blastcore_Visuals_R1.2` (WarFX Blastcore) — explosion/particle FX. Already in Ray's event base pack.
  - `@sthud` (ShackTac Fireteam HUD) — minimalist fireteam-position HUD (UI overlay). CBA dep.
  - *(optional)* a tracer/FX pack **only if** it is confirmed pure-visual and not already covered by Blastcore.
- **Distribution:** reuse the exact pattern the event repos already use — a locked zip + `manifest.json`
  (SHA-256 + size + source per PBO) published as a GitHub Release asset, plus a `Verify-*.ps1` verifier the
  player runs and pastes the hash of in Discord. Precedent (described, not yet built): the "Distribution"
  sections of `taviana-air-war/MODLIST.md` and `napf-tank-war/MODLIST.md` (a `Verify-EventModpack.ps1` /
  `verify-modpack.ps1` verifier is specified there but not yet committed — build one from that spec).
- **Signing:** *not required at `verifySignatures=0`.* Sign it anyway (cheap, future-proofs a v2 flip) — see the
  key note below.
- **Why this is the right default:** zero box risk, zero mission risk, no approval needed to *enable* it; the
  work is packaging + a download page (the miksuu-skins `web/` pages are a ready template).

### Model B — accept the mods' own `.bikey`s on the server (only if tightening to v2)

If Ray flips `verifySignatures=2` for anti-cheat reasons, then to keep the optional set working:

- Put each optional mod's shipped `.bikey` into the server `Keys\` folder (JSRS ships `jsrs15.bikey`, CBA ships
  `cba.bikey`, Blastcore/STHUD ship their own — confirm at packaging time; `bisign2bikey`
  (https://github.com/wrdg/Bisign2Bikey) derives a `.bikey` for any mod that shipped only `.bisign`).
- **Tradeoff:** accepting a third-party `.bikey` means the server will admit *any* addon signed by that key,
  now and in future — a mild trust expansion. Minting our OWN key and re-signing the curated pack (Model A's
  signing) is tighter: the server then trusts exactly one publisher (us) for the whole optional pack.
- Also re-install the WASP mods' own keys (currently missing from `Keys\`) or the server's own `@adwasp`/
  `@admkswf` would fail v2. This is the hidden cost of a v2 flip and argues for staying at v1 (or v0) unless
  cheating becomes a real problem.

### The signing key — what exists and what to name it

**There is NO single shared WASP master signing key in any repo.** The pattern across every WASP addon is
**one dedicated key per addon**, private key **gitignored** and stored offline, `.bikey` committed:

- `wasp-tweaks` → mints `wasp_tweaks.bikey` / `.biprivatekey` (`wasp-tweaks/README.md`, `build/build.ps1`).
- `taviana-air-war` / `napf-tank-war` → `wasp_event_tweaks.bikey`, `napf_tank_tweaks.bikey`
  (`a2waspwarfare-events/docs/reviews/2026-06-12-codex-adversarial-review.md:49`).
- `miksuu-skins` → `miksuu_skins.bikey` (`addons/miksuu_skins/BUILD-NOTES.md`).

All private keys are excluded via `.gitignore` (`*.biprivatekey`, `keys/*.biprivatekey`) — **none is present in
git**, so there is nothing to reuse; a key must be **minted**. **Recommendation:** mint a dedicated
**`wasp_optional.biprivatekey` / `wasp_optional.bikey`** (`DSCreateKey wasp_optional`), keep the private key
offline (Ray holds it, like the other event keys), commit only the `.bikey`. Re-sign the curated pack's own
override PBO (if any) with it. This mirrors the established per-addon convention exactly.

> **NOTE for Ray:** the passphrase/private-key custody for `wasp_optional` (and whether to reuse the offline
> `wasp_event_tweaks` key instead of minting a new one) is a Ray decision — see rollout §(d).

---

## (c) Candidate optional-mod table

All are era-correct Arma 2 OA 1.64 addons. "Client-only safe?" = the server does NOT need it loaded and players
without it are unaffected. bIdentify file-ids/filenames are the exact archives to pull (Combined Operations loads
**both** the base-`arma2` and `arma2oa` trees, so either tree is usable — Ray's event research confirms this).

<!-- BIDENTIFY-TABLE-START -->
_bIdentify note: the site's file **search is JS-driven** (the `/search?q=` URL returns the homepage to a plain
fetch), so numeric ids must be read from the site's search UI at pull time. **JTD FireAndSmoke's id (`1935`) was
confirmed directly.** JSRS / Blastcore / STHUD are all confirmed *present* on bIdentify (they are staples of the
archive and appear in Ray's prior sweeps + event packs) but their exact numeric ids should be captured from the
`/search` UI when pulling — per Ray's own modlist convention ("AVAILABLE (bidentify) — verify at extraction").
The columns below carry the load-bearing facts (signed?, client-safe?, caveats); the id column is filled where
directly confirmed._

| Mod | Type | On bIdentify | File id / filename | Ships `.bikey`? | Client-only safe? | Caveats (A2 OA 1.64, sig-checking dedi) |
|---|---|---|---|---|---|---|
| **CBA_CO** | dependency | yes | `@CBA_CO` (also live pack) | **yes** (`cba.bikey`, `cba_b196.bikey`) | yes (already server-side) | Prerequisite for STHUD + Blastcore. Already the server standard → no extra burden. Load FIRST in the client `-mod` line (XEH race). |
| **JSRS 1.5** | sound | yes | *(confirm id)* `JSRS 1.5 Final` | **yes** (`*.jsrs15.bisign` → `jsrs15.bikey`) | **yes** — "runs entirely on the client, cannot induce server lag; players who don't run it can still play" | Already in Ray's event base pack (`@JSRS1.5`). Pure sound. Some `_C.pbo` sub-files can be disabled to trim. No known MP blocker. |
| **Blastcore Visuals R1.2** (WarFX Blastcore) | visual FX | yes | *(confirm id)* `WarFX Blastcore R1.2` | **yes** (ships bisign/bikey) | **yes** — "changes particle visuals, not sim cost" (Ray's `server-performance.md`) | Already in Ray's event base pack (`@Blastcore_Visuals_R1.2`). CBA dep. FPS dips during heavy particle moments on weak clients → recommend the low-FX profile for those users. |
| **ShackTac Fireteam HUD (STHUD)** | UI/HUD | yes | *(confirm id)* `sthud` / `ShackTac_HUD` | **yes** (ships bikey) | **yes** — pure client HUD overlay (fireteam positions only) | **CBA dep** (already server-side). Toggle menu = Alt-Shift-H. Purely local overlay; no server component. Includes STGI group indicators. |
| **JTD FireAndSmoke 0.3** (tracer/smoke FX) | visual FX | **yes** | **id `1935`** (`JTD_FireAndSmoke` archive) | **yes — confirmed** (`JTD.bikey` + `.bisign`) | **yes** — ambient fire/smoke/dust visual FX | Confirmed held + signed on bIdentify (direct verify). Healthiest pure-visual tracer/smoke candidate. **Partly redundant** with Blastcore — include only if you want the extra ambient smoke/dust layer; it does not alter ballistics/ammo (pure visual → in-scope). |
| ~~ShackTac Stamina / movement~~ | movement | — | — | — | **NO — OUT** | **Gameplay-affecting** (alters fatigue/movement). Changes simulation → would need every client + server and would desync as an optional. Explicitly excluded per scope. |

**Also OUT of scope** (named so they aren't re-proposed): ACE/ACEX (total conversion, gameplay), ASR AI /
Zeus AI / bCombat (AI behaviour — server-side, not client-optional), TPW MODS (A3-only), any weapon/vehicle
replacement config, any "realism" ballistics/stamina pack.
<!-- BIDENTIFY-TABLE-END -->

**bIdentify index notes** (how to cite exact links): the archive is served at `bidentify.jerryhopper.com/files`
(HTTP; the `/files/` path 307-redirects to `/files`). It mirrors both the base **arma2** and **arma2oa** content
trees; Combined Operations loads both, so a client-side mod present in *either* tree is usable. Ray's prior
sweeps recorded exact archive filenames in `napf-tank-war/MODLIST.md` and `taviana-air-war/MODLIST.md` — reuse
that citation style (archive filename + tree). Numeric ids beyond JTD's `1935` are read from the site's `/search`
UI at pull time (the search is JS-driven and not fetchable headless).

---

## (d) Rollout steps (and what needs Ray)

1. **Decide the model.** Default = **Model A** (curated `@wasp_optional`, box unchanged). Model B only if Ray
   wants anti-cheat tightening. — *Ray decision.*
2. **Confirm the archives on bIdentify** (JSRS 1.5, Blastcore R1.2, STHUD, CBA_CO; optional JTD FireAndSmoke
   **id 1935**) via the site's `/search` UI — record file-id + filename + SHA-256 + size into a `manifest.json`.
   `bisign2bikey` any that shipped only `.bisign` (JTD already ships `JTD.bikey`). *(Automatable; no Ray input.)*
3. **Mint the pack key** — `DSCreateKey wasp_optional` (or reuse the offline `wasp_event_tweaks` key). Commit
   `wasp_optional.bikey`, keep `.biprivatekey` offline. — **Ray: key custody + passphrase.**
4. **Build + sign** the curated pack (zip layout mirrors `wasp-tweaks` / event packs: `@wasp_optional\addons\…`,
   `@wasp_optional\keys\wasp_optional.bikey`). Reuse `wasp-tweaks/build/build.ps1` (auto-detects MakePbo/armake2/
   AddonBuilder + optional `DSSignFile`). Publish as a GitHub Release asset + `Verify-*.ps1`. *(Automatable.)*
5. **Player-facing page** — extend the `miksuu-skins/web/` pages (`skins.html` / `skin-picker.html` /
   `nav-button-snippet.html`) with a "Optional Mods" download + install instructions (`-mod=@CBA_CO;@wasp_optional`
   order, Alt-Shift-H for STHUD, low-FX note for Blastcore). — miksuu.com rebuild/restart is **Ray-only**
   (per `miksuu-website-deploy-boundary`).
6. **(Model B only) Box cfg edit** — set `verifySignatures=2` (or keep `1`), drop every `.bikey` (CBA + WASP
   mods + optional pack) into `C:\WASP\profiles-pr8\` server `Keys\`, restart the `Arma2OA-PR8` NSSM service.
   — **Ray approval required** (box cfg change + service restart; overnight box changes are box-side, not Claude).
   **Also re-install the WASP mods' own keys or the server's own mods fail v2.**
7. **Smoke test** — one client with the pack + one without both join a live match; confirm no kick, RPT-clean,
   STHUD toggles, JSRS audible, Blastcore FX render. (Model A needs no box change to test.)

**What needs Ray, at a glance:** (i) model choice; (ii) `wasp_optional` key custody + passphrase (or reuse
event key); (iii) miksuu.com page rebuild/deploy; (iv) *only for Model B* — box `verifySignatures` edit +
`Keys\` population + `Arma2OA-PR8` restart approval. **Nothing here needs a drive password** — the four
candidates are on bIdentify (public archive); Miksuu's Drive is only relevant if Ray later wants Drive-exclusive
FX/skins folded in (currently link-shared, not enumerable — see `last-stand/MODLIST.md`).

---

## (e) Mission-side hook ideas (read-only; NOT implemented)

The mission can *detect* a client mod locally and degrade gracefully — the exact `isClass (configFile >>
"CfgVehicles"/"CfgPatches" >> "X")` pattern **already ships live** in `WASP/actions/SkinSelector/
SkinSelector_Data.sqf` (it drops `mks_*` skins unless `@MiksuuSkins` is loaded). All hooks below are per-client,
run on the joining player only, and are safe no-ops when the mod is absent. Paths are the Chernarus master
(`Missions\[55-2hc]warfarev2_073v48co.chernarus\…`); the LoadoutManager mirrors to Takistan.

A2 OA 1.64 detection primitive (verified core commands): `isClass (configFile >> "CfgPatches" >> "cba_main")`
returns `true` iff CBA is loaded on this client; substitute the CfgPatches class of any mod (e.g. `JSRS`,
`WarFXPE`/`blastcore`, `sthud`). **Do NOT use A3-only `isEqualType`/`allMapMarkers`** (per host notes).

1. **Suppress the mission's hand-rolled explosion FX when Blastcore is present.**
   - Where: `Client\Module\Nuke\nuke.sqf` builds a mushroom cloud from raw `#particlesource`/`#lightpoint`
     emitters (client-local). Blastcore/WarFX ships far better explosion visuals.
   - Hook: at the top of `nuke.sqf`, `if (isClass (configFile >> "CfgPatches" >> "<blastcore_class>")) exitWith
     { /* let Blastcore's own explosion FX handle it, or spawn a lighter cue */ };` — purely cosmetic, per-client.
   - Benefit: no double-stacked particle load on Blastcore users; the mission's FX still runs for everyone else.

2. **Skip the mission's rocket-motor tracer particles when a tracer/Blastcore FX mod is present.**
   - Where: `Common\Functions\Common_HandleRocketTracer.sqf` (`HandleRocketTraccer`) draws its own
     `#particlesource` smoke/flame trail for AT rockets. It is compiled at `Common\Init\Init_Common.sqf:6` and
     attached via `Fired` EHs at `Client\Init\Init_Client.sqf:71`, `Client\Functions\Client_BuildUnit.sqf:569`,
     and `WASP\actions\SkinSelector\SkinSelector_Apply.sqf:227`.
   - Hook: guard the body of `Common_HandleRocketTracer.sqf` with a one-time client-cached flag,
     e.g. `if (WFBE_HAS_FX_MOD) exitWith {};` (set once in `Init_Client.sqf` from the `isClass` check), so
     Blastcore/tracer-mod users don't get the mission trail layered on top of the mod's.
   - Benefit: avoids visible double-trails for FX-mod users; unchanged for everyone else.

3. **One-time friendly RPT + system-chat acknowledgement of a detected optional mod.**
   - Where: `Client\Init\Init_Client.sqf` (the client init entry; after the null-player guard ~L34, before the
     JIP-heavy waits). No existing CBA/mod detection lives here today (verified) — this would be net-new and tiny.
   - Hook: build a small list of `[displayName, cfgPatchesClass]` for the optional pack, and for each loaded one
     emit `diag_log` (goes to the client RPT for support triage) plus a single `systemChat` line
     (e.g. "Optional mods detected: JSRS, Blastcore, STHUD — enjoy."). Read-only; no gameplay effect.
   - Benefit: confirms to the player (and to us in their RPT) that their optional pack loaded correctly — the
     cheapest possible "did my mod work?" support tool, and a natural place to hang hooks (1) and (2)'s flags.

> These are *ideas with exact insertion points*, not changes. Implementing any of them is a separate, approved
> task; each is a per-client cosmetic guard with a safe absent-mod path (mirroring the live SkinSelector guard).

---

## (f) Miksuu Drive inventory

**Access reality (verified 2026-07-02):** the Miksuu Drive is **NOT reachable from this gaming PC.** Confirmed:
no Google Drive / storage MCP connector is installed here; there is no local mirror folder
(`Arma_Mods_Mirror_WithPW_by_Miksuu` is absent); there is **no E: drive** on this host (Jerry's cache
`E:\arma2-cache` and `E:\ArmaModpackBackup` live on a *different* machine — the "Main PC", `C:\Users\Steff\…`);
and no password-protected mod archives (`.7z/.rar/.zip`) exist anywhere on C:. This matches Ray's own repeated
notes: Miksuu's Drive is *"link-shared, not enumerable via the Drive MCP"*
(`last-stand/MODLIST.md:4`, `last-stand/docs/specs/2026-06-30-last-stand-design.md:5`).

**About the password `armedassault`:** in the repos it is documented as the extraction password for **Jerry's
cache archives**, not a Drive login — `taviana-air-war/docs/superpowers/plans/2026-06-29-phase1-boot-taviana.md:38`:
*"Extract (pw `armedassault` for cache archives)."* Those cache archives sit on the Main PC's `E:\arma2-cache`.
So even with the password, there is nothing on THIS host to unlock — the archives it applies to are not present.

> **Therefore a real file-by-file Drive listing cannot be produced from this machine.** To inventory the Drive
> as requested, run it from the **Main PC** (where `E:\arma2-cache` + the Drive mirror live) or after a Google
> Drive connector is installed and the folder is shared to this account. Once reachable, the inventory should
> capture: filename, size, and a one-line "what it appears to be", flagging each as **(a)** client-side mod
> candidate (sound/visual/UI → this doc's lane), **(b)** AI/behavior mod (→ handoff §(g)), or **(c)** old
> mission/source material. **Command to enumerate + extract into scratchpad (Main PC, when reachable):**
> ```powershell
> # inventory only (no bulk pulls):
> Get-ChildItem -Recurse 'E:\arma2-cache','<DriveMirrorPath>' -Include *.7z,*.rar,*.zip |
>   Select-Object FullName, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
> # extract ONLY a mod-looking archive:
> & 7z x '<archive>' -o'<scratchpad>\<name>' -p'armedassault'
> ```

**What is known about the Drive's contents from the repos** (indirect — not a live listing): Ray's notes
describe it as an **`Arma_Mods_Mirror_WithPW_by_Miksuu`** — a password-protected mirror of the community
addon set, intended to be "folded in later for additional **zombie/enemy/prop variety**" for the Last Stand
event (`last-stand/MODLIST.md:40`, `docs/specs/…last-stand-design.md`). It is a *variety* source (extra
content mods), not specifically a client-optional or AI-mod source. Miksuu historically kept a full backup of
the armedassault.info addon catalog (`wiki-120/Miksuu-Wiki-Archive-Changelog.md:538`: *"if the site goes down,
I have them all backed up"*), so the mirror likely spans the whole classic A2/OA addon universe — which means
any client-side or AI mod on bIdentify is plausibly also in the Drive under a similar filename.

## (g) AI-improvement mod handoff (for the separate AI-eval agent)

Ray's deeper interest is **AI-improvement** mods — AI aircraft not crashing, better pathfinding. **Important
framing:** the classic A2/OA AI mods below are **server-side (or server+HC) AI-behavior addons, NOT client-
optional cosmetics** — they belong in a *different lane* than this doc's `@wasp_optional` client pack (they must
run on the server/HC to affect the AI everyone sees, and several are gameplay-affecting). Also, **none of the
classic AI mods addresses AI *aircraft* crashing/pathfinding** — that is a helicopter/fixed-wing FSM problem
the WASP mission already tackles mission-side (see `docs/design/EASA-FOR-AI.md`, `AICOM-AIRCRAFT.md`,
`AICOM-UNIT-BEHAVIOR-FABLE.md`), not something an off-the-shelf A2 addon fixes. Handing off the candidates that
DO exist, with filenames/ids to look up — no deep-dive here:

| AI mod | What it does | A2 OA? | Notes for the AI-eval agent |
|---|---|---|---|
| **ASR AI 3** (`@ASR_AI3` / `asr_ai3_*`) | Infantry skill/behavior, suppression, gear randomization | yes — **already bundled in `@adwasp`** (v1.16.0.40), userconfig-tunable (`server-config/userconfig/ASR_AI/asr_ai_settings.hpp`) | Infantry-only; **does NOT touch aircraft**. Already live. Tune `radiorange` per map. Not a client mod. |
| **Zeus AI Combat Skills** (`@ZeusAI` / `zeu_*`) | Infantry spotting/skill improver | yes | Server-side; infantry-only; ~+10-20% CPU/unit (`server-performance.md:31`). Stacks with ASR. Doesn't touch aircraft. |
| **TPWCAS** (suppression) | AI suppression under fire | yes — **script-embeddable, 0 MB** | Already promoted into event specs as a mission-embed; no addon/bikey needed. Infantry feel, not air. |
| **GL4** (Group Link 4) | AI group reinforcement/awareness FSM | yes | Compiled FSM; heavier than ASR (`server-performance.md:31`). Server-side. |
| **SLX** (AI steering/behavior suite) | AI movement/steering, wounding | yes | Ray flagged **"extraction complexity > gain"** (`mod-improvement-and-final-sweep.md:72`). Server-side, gameplay-affecting. |
| **bCombat** | Infantry AI overhaul | yes | Server-side AI behavior; gameplay-affecting. Community-known for A2. |
| **UPSMON / LAMBS-equivalent** | Patrol/behavior scripting | script | Scripting frameworks, not addons; mission-side. WASP already has its own Patrols v2 + AICOM. |

**On the actual ask (AI aircraft crashing / pathfinding):** no classic A2 addon reliably fixes AI *air*
crashing on modded terrain. The realistic levers are all mission-side and already in WASP's design lane:
AICOM air-hull founding/behavior (`Server/AI/Commander/*`), EASA kit application to AI aircraft
(`docs/design/EASA-FOR-AI.md`), and air-route/waypoint handling. The AI-eval agent should evaluate those
mission-side systems first; an addon like ASR/Zeus will improve *infantry* fights but will not stop a jet from
flying into a hill. **If the Drive/bIdentify sweep surfaces a dedicated AI-aviation/pathfinding addon, list its
filename/id here** — but expectation is low that one exists for A2 OA.

## Appendix — source pointers (for the next agent)

- Live box facts: read-only SSH recon 2026-07-02 (NSSM `Arma2OA-PR8`, `C:\WASP\profiles-pr8\server-pr8.cfg`,
  `verifySignatures=0`, `equalModRequired` absent, `BattlEye=0`).
- Override-addon (CfgPatches inheritance) precedent: `wasp-tweaks/addons/wasp_tweaks/config.cpp` +
  `Mods\mkswf_sidewinder_reload_time_fix\{config.cpp,CfgPatches.hpp,CfgWeapons.hpp}` (in the mission repo).
- Signed client-texture-addon precedent (build/sign/deploy + `hiddenSelections` + `.paa`): `miksuu-skins`
  (`addons/miksuu_skins/config.cpp`, `BUILD-NOTES.md`). Format = **`.paa`** (PNG→PAA via ImageToPAA/TexView2);
  textures gitignored. This is the template for a future signed **`@wasp_skins`** client pack — same flow as
  `@wasp_optional`, but Q4's skins repo needs the server loaded too (it adds `CfgVehicles` classes the selector
  reads), so it's "optional-cosmetic-that-also-lives-server-side," not purely client-local like JSRS/Blastcore.
- Per-addon key convention (no shared WASP master key; private key offline+gitignored, `.bikey` committed):
  `wasp-tweaks/README.md`, `a2waspwarfare-events/docs/reviews/2026-06-12-codex-adversarial-review.md`.
- Client-side-safety of JSRS/Blastcore, and v2-bisign caveat → prefer v1:
  `a2waspwarfare-events/docs/research/{aircraft-catalog.md,mod-improvement-and-final-sweep.md,supplementary-systems.md}`.
- Distribution/manifest/verifier pattern: `taviana-air-war/MODLIST.md`, `napf-tank-war/MODLIST.md`.
- Mission-side `isClass` graceful-detect precedent (live): `WASP\actions\SkinSelector\SkinSelector_Data.sqf`.
