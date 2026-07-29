# Handover → Kimi, 2026-07-29 06:30 CEST

Written by the outgoing Claude session. Everything below is verified state, not recollection.
Where something is unverified or is someone else's claim, it says so explicitly.

---

## 1. Live server — do not break this

- **LIVE box `176.9.104.115`**, build **m0728h**, rotation **Takistan → Chernarus**, both Veteran.
  Deployed 2026-07-28 ~20:35 CEST. Health at 21:00: fps recent-avg **45.5**, min 44.1,
  **zero** `Error in expression` / `Undefined variable` in the MISSINIT window.
- **Zargabad is OUT of rotation** — the owner asked for "Takistan > Chernarus" and got exactly that.
  The ZG PBO is already staged on the box, so restoring it needs a cfg edit, **not** a repack.
- Box clock is **CEST-9 (US Pacific)**. Convert before correlating RPT timestamps with anything.
- Secondary/test box `78.46.107.142` also hosts the Miksuu PR8 tenant on UDP 2302-2304.
  **Never** `Stop-Process` by name there — kill only recorded PIDs.
- **NEW, learned the hard way last night:** one-shot scheduled tasks on the secondary box must
  run `/RU SYSTEM`, **not** `/IT`. `/IT` (interactive-only) silently never runs — that box has no
  interactive session. This is the opposite of the live box, where `/IT` works. It cost two
  silent no-runs before it was caught.

## 2. Release branch state

`release/wasp-aicom-recovery-20260727` is **9 merges past live m0728h**. Everything below is
merged and gate-passed (brackets 0-delta, lint at the 168 baseline, mirrors regenerated,
TK/ZG templates restored) but **not yet in a deployed build**:

| PR | What |
|---|---|
| #1585 | Deck header was in BOTH visibility sets so the advisory loop hid it while commanding; FPV spawn discarded its own clearance-tested height |
| #1586 | AICOM air boarding cap 30s → 12s (`WFBE_C_AICOM_BOARD_WAIT`), verified air-only by construction |
| #1587 | COIN placement diagnostics (`COINPLACE|v1`) — the placement-method default case was DORMANT, so the real root cause of the owner's placement complaint is still unknown; the new logs will name it |
| #1590 | FPV kill-causation ledger (`FPVCAUSE|v1`), log-only, both error directions |
| #1591 | Command-menu nudge row `sizeEx` 0.035 → 0.020 (text overflow, not geometry — see §5) |
| #1592 | `Server_BombProbe.sqf` Stage-A harness, flag `WFBE_C_BOMB_PROBE` default 0 — **never arm on live** |
| #1593 | Base-defense re-man latency ~427s → ~15s; server-side structure cap race closed |
| + mirror commits | |

**Next build cut = m0728i.** Contains all of the above. Owner's standing rule: send a
`CHANGELOG <tag>` Peach DM **before** deploying, then deploy autonomously.

## 3. Drafts awaiting soak or an owner decision — DO NOT ARM

| PR | Flag | Gate |
|---|---|---|
| #1584 | `WFBE_C_AICOM_WEST_JETS` = 0 | Owner call. WEST structurally cannot field a fixed-wing bomber on Chernarus (`Squad_USMC.sqf` has zero jet templates; the A-10/AV-8B rows live only in `Squad_OA_US.sqf`, which Chernarus never loads) |
| #1588 | `WFBE_C_AICOM_AIRLIFT_V2` = 0 | Needs soak. Known risk the author flagged: the transport spawns at the factory nearest the team **at request time**, so if the team has marched away the 60s boarding wait may routinely abort (fail-safe, but reduces effectiveness) |
| #1589 | `WFBE_C_AICOM_AIR_QUICKSTART` = 0 | Needs soak. Closes the ~75s founding→first-order gap |
| #1594 | `WFBE_C_SPECTATOR` = 1, UID-allowlisted | **Collides with open PR #1580 (casting mode)** — both add a free camera, with opposite decisions on body invulnerability. Owner must reconcile before either merges |

## 4. The overnight Grok run — 351 cards, 323 done, 27 blocked

The 27 "blocked" are **complete work** that couldn't tick a milestone checkbox because the
fleet-console Inbox API was unreachable (3847/4173/4190 refusing). Fixing that endpoint
unblocks them without redoing any work.

**Two triage lanes were dispatched before this session ended:**
1. `codex-pr-triage` — **DONE.** Result written up in §6b below. Read that before touching any
   chernarus-codex PR.
2. `wasp-finding-verify` — **STILL RUNNING at handover.** It independently checks the four
   highest-consequence Grok claims (invalid buyable classnames; the 54 wrong-mount EASA rows;
   24 lobby params silently overriding constants; 66 flags read with different defaults at
   different sites) and returns a CONFIRMED / PARTIALLY-CORRECT / WRONG verdict per claim with
   sample hit-rates plus a ranked action list. **Collect this before acting on any Grok finding.**
   If the result is lost with the session, the four claims are restated in full below — re-run
   the verification rather than trusting them unverified. The single most important question it
   answers: what happens at runtime when a player buys a classname that does not exist — does it
   throw, silently no-op, or charge the player and give nothing?

**Do not act on any Grok finding until that verification lands.** An audit finding that is
itself wrong is worse than no audit. The claims most worth acting on **if confirmed**:

- **Buyable-units FAIL_HIGH** — invalid classnames (`BAF_crewman_W`, `RUS_Soldier_Medic`,
  several `INS_*`, `Smallboat_2`), an EAST MiG-21 buyable with no price entry, and Mi24_P
  priced 18000 in one place / 32600 in another. Highest crash-risk of the set.
- **EASA loadout audit** — 529 rows: 305 OK, 138 suspect, **54 wrong-mount**, **32 broken
  classname**. Independently supports the pre-existing suspicion that Mi24_P and Su34 kit rows
  use the hull path for turret-mounted weapons.
- **124 lobby params, 24 silently overriding differently-valued constants.**
- **1471 flags: 28 dead, 99 unregistered (63 governed purely by their fallback), 66 read with
  DIFFERENT defaults at different sites.** Multi-default is the dangerous class.
- **waspmalloc open question SOLVED**: the 2× commit is 4 MiB segments + eager-commit packing
  one 2 MiB object per segment; residual is architectural, not a leak. Options ranked.
- **Lint baseline triaged**: exactly 168, all A3MARKER false positives on `CfgAmmo B_*`
  classnames — and repo `CLAUDE.md` is wrong where it claims ~447. Worth correcting.

## 5. Traps burned in during this session — do not re-learn these

- **PowerShell variables are case-insensitive.** A loop variable `$f` silently clobbered `$F`
  (a script path), so every invocation tried to execute a JSON file. The loader reported
  `LOADED=140` while creating **nothing**, because `*>$null` swallowed the error stream.
  Two rules: never suppress the error stream of the thing you're counting, and verify writes
  against the filesystem rather than trusting a tool's self-report.
- **Fleet.ps1 over SMB from the Main PC is ~10× slower** than running it on the Game PC where
  the vault is a local path (`C:\wasp-share\Mijn vualt\Fleet`). Bulk card loads belong on
  gamingpc. Loader lives at `C:\Users\Game\load-cards-v2.ps1` (verifies each write).
- **Windows sshd kills detached children.** Anything long-running on a box must go through a
  one-shot scheduled task, not a backgrounded ssh command.
- **Compute UI geometry, don't eyeball it.** Two dialog bugs this session were found by parsing
  `Dialogs.hpp`, resolving class inheritance, and intersecting rectangles. The second one
  (#1591) *disproved* the stated hypothesis — controls were all in-bounds; the truncation was
  text overflow at the inherited font size. The analyzer is at
  `scratchpad\cmd_layout.py`; a v2 that also resolves `Ressources.hpp` base classes exists.
- **`wfbe_startpos` is an OBJECT**, despite a comment at `RequestDefense.sqf:44` claiming array.
  That comment is now corrected. It only ever "worked" because `distance` accepts objects.

## 6. Open threads, ranked

1. **Collect the two triage lanes** (§4) before touching anything they cover.
2. **Cut m0728i** when the owner wants it, or let it ride the 06:00 restart. Changelog DM first.
3. **Fix the fleet-console Inbox API** — unblocks 27 finished cards for free.
4. **HC-slot experiment is still unresolved.** The test infrastructure now works end-to-end
   (SYSTEM scheduled task, PID-safe teardown, tenant untouched), but the minimal server cfg
   boots to lobby and never loads the mission, while the full production cfg on the same box
   auto-starts fine. A Grok research card (`wasp-research-persistent-autostart-20260728`) was
   queued for exactly this. Artifacts: `C:\WASP\hcslot-test.ps1`, PBO already in MPMissions,
   uncommitted Takistan `mission.sqm` on branch `fable/hc-slot-lowid-test`.
5. **AI bombs are only partly addressed.** The cannon-nudge that was actively starving the
   Mi-24P's bomb launcher is fixed (#1583), but two causes remain: WEST can't field a bomber at
   all (#1584, owner-gated), and whether A2 AI releases unguided bombs without scripted forcing
   is **still unverified** — that's what the Stage-A probe (#1592) exists to answer. Run it on
   the test box, never live. `forceWeaponFire` is A3-only; the A2 equivalent is `fireAtTarget`.
6. **AH6J kill misattribution** — deliberately not fixed. #1590's `FPVCAUSE|v1` ledger is now
   collecting the evidence in both error directions. Let it gather a day of play, then decide
   from data rather than shrinking windows on a guess.
7. **Owner build-rule decisions still open** (from the build-menu audit): per-map slope check
   re-enable, road-clear check for player placement, AA/AT sub-caps inside the 25-static budget,
   structure spacing. Implementation specs were carded (`wasp-audit-buildrule-specs-20260728`).
   Note the audit's headline: the player build path has **zero server-side geometric validation**
   — the AI validates everything server-side, players can build on roads.

## 6b. Codex-site PR triage — RESULT (lane completed 06:47, verified against real code)

**Do not bulk-merge the 54.** Verdict: content is sound, mechanics are not.

**Accuracy: clean.** All six highest-risk AI-Behaviour pages were checked line-by-line against
`a2wasp-smlfix @ 2bcb0cf5e4` (the exact commit each page cites). No factual errors. Every one of
the four known-unsettled items was hedged correctly — GUER Director's coded `=1` default (which
contradicts its own design doc) was confirmed byte-for-byte, airlift is described as broken and
disabled, AI bomb release is explicitly framed as OPEN, and the AICOM V2 "layered brain" is
correctly described as designed-but-never-built. A couple of cited line numbers are off by one
and self-caveated. **Publishing these is safe on accuracy grounds.**

**Mechanics: messy.**
- `src/lib/nav.ts` is touched by **39 of 54** PRs, each re-deriving the same infra hunk from #7.
  Resolution is mechanical but must be done once per PR, sequentially. No way around it.
- `src/lib/mdx.ts` is **fully rewritten** by 7 PRs (#49,50,52,53,56,58,60), each for a different
  purpose. Not diff-mergeable — only the first lands. Three of them implement three *different*
  mechanisms for intercepting code-block rendering, likely mutually incompatible. #58 also
  changes `loadDoc()`'s return type. **This needs one unified pipeline written by hand — real
  dev work, not conflict resolution.**
- Four PRs (#49/50/52/53) independently reinvent Mermaid infra, all adding the same dependency.
  #50 and #53 are diagram-first *stubs* that would OVERWRITE the real prose pages in #8 and #13 —
  merge the prose first, then hand-splice the diagram.
- `order:` frontmatter collides badly (`order: 14` used by four pages). `content.test.ts` won't
  catch it — ties pass. Needs one renumbering pass across the batch.

**RED — hold until the mdx.ts unification exists:** #49, #50, #52, #53, #55, #56, #58, #59, #60.
Two add build-contract changes worth a second look on the real deploy box: **#55** adds a
`postbuild` Pagefind index step to every future build, and **#59** adds `postinstall`+`prebuild`
hooks that patch `node_modules` (a real, well-guarded Windows `next/og` fix — but it auto-patches
third-party code).

**Merge order:** #7 alone → #46 → #31 → #38 → the 17 clean AI pages → #8 then splice #50, #13
then splice #53, splice #52 onto post-#31, splice #49 onto post-#38 → remaining GREEN
guides/traps → #51+#54 → #57 → #48 → RED cluster last → renumber `order:`.

**Also found: this repo has ZERO GitHub Actions workflows — no CI gate at all.** Every merge is
trust-based today. Three PRs were built and tested locally (#12, #55, #56) and all passed clean,
so the risk is in merging them *together*, not in any one alone. Worth adding a build+test
workflow before absorbing 54 PRs.

## 7. Working agreements to honour

- Peach DM after every completed step or gate.
- `CHANGELOG <tag>` DM at fire time, before deploying. Deploy authority is standing.
- Never touch HC architecture, player enrollment, or JIP flow without explicit per-task consent.
- New features flag-gated default 0; correctness fixes may ship unflagged.
- Edit only the Chernarus tree, then regenerate mirrors via LoadoutManager and restore the
  TK/ZG `version.sqf.template` files before staging.
- No `Co-Authored-By` trailers. Never expose host/user/path/IP in the public repo.
