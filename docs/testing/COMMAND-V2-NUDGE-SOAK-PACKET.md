# COMMAND V2 nudge system — soak packet
<!-- GUIDE-REV: GR-2026-07-08a -->

Companion to `docs/design/COMMAND-V2-NUDGE-SYSTEM-DESIGN.md` (section 13 = as-built).

**Status: PLAN — NOT RUN.** No runtime evidence exists for this feature. Everything shipped so
far is static validation (lint gate, bracket gate, 45 deterministic source tests, mirror parity).
This document is the arming gate: it says exactly what has to be captured, and what has to be
true in that capture, before any of the five master flags is set to 1 on a live or test box.

Per `.claude/skills/pr-preflight/SKILL.md` section 6, a runtime claim requires quoted RPT tokens
windowed to the current `MISSINIT`. None are quoted here, because none have been collected.

---

## 1. What "the packet" is

Following the convention in `docs/design/DEFAULT-OFF-FEATURE-FLAG-READINESS-SWEEP.md`
("preserve the RPT and configuration provenance with the soak packet"), one packet is:

1. `arma2oaserver.RPT` — the server RPT, windowed to the last `MISSINIT`.
2. `ArmA2OA.RPT` from **both** headless clients — the AICOM team logs live here, not in the
   server RPT (see `CLAUDE.md`, "Where to look").
3. `python Tools\Soak\analyze_soak.py <server.RPT> --hc <ArmA2OA.RPT> --json > analyze.json`.
4. A flag-state manifest: the value of all 21 `WFBE_C_CMD_*` flags for that run, plus the branch
   and commit SHA the box was running.
5. A ledger row via `Tools\Soak\Append-LedgerRow.ps1` (schema:
   `docs/design/v2/SPEC-SOAK-LEDGER-CONTRACT.md`; remember: **null is not zero**).

Window the RPTs with `Tools\Monitor\Get-WindowedRpt.ps1` — an un-windowed RPT spans multiple
missions and will silently mix runs.

---

## 2. Runs required

Each run is a separate packet. Run them in this order; a failure at any stage stops the ladder.

| # | Name | Flags set to 1 | Minimum | Purpose |
|---|---|---|---|---|
| R0 | **Inertness baseline** | *none* (all default) | 30 min | Prove flag-off is behaviourally identical to HEAD. |
| R1 | Town nudge | `WFBE_C_CMD_TOWN_NUDGE` | 60 min, 2 clients | Weight sizing + does the AI still command. |
| R2 | Doctrine | `WFBE_C_CMD_TEAM_DOCTRINE` | 30 min, 2 clients | Eligibility, anti-spam, receipts. |
| R3 | Posture garrison | `WFBE_C_CMD_POSTURE_GARRISON` | 30 min | GARRISON accepted and biases the engage gate. |
| R4 | Heli support | `WFBE_C_CMD_SUPPORT_AIR` | 60 min, 2 clients | The whole grant/escort/return lifecycle. |
| R5 | Recall | `WFBE_C_CMD_SUPPORT_AIR` + forced last-stand | 30 min | Hysteresis actually holds. |
| R6 | All-on | all four gameplay flags | 90 min, 2 clients | Interaction + perf. |

**R0 is the gate for everything else.** If R0 shows any new token or any AICOM behaviour delta
versus a HEAD run, stop: the inertness claim is wrong.

Two clients and two HCs are required for R1, R2, R4 and R6 — the per-UID cooldowns, the
side-wide concurrency cap and the HC-delegated order path are all invisible with one of each.

---

## 3. Token vocabulary to grep

Every one of these is emitted by this feature and by nothing else, so they are safe greps.

```
AICOM2|v1|ORDER|TOWN_NUDGE|<accept|reject|cooldown|team>
AICOM2|v1|ORDER|TEAM_DOCTRINE|<stance>|<accept|reject|cooldown>
AICOM2|v1|ORDER|CMD_SUPPORT|<REQUEST|GRANT|NONE|RELEASE|RECALL|REJECT>
```

Field keys worth extracting: `agg=` and `ring=` (town nudge aggregation), `ferry=` (grant ferry
distance), `heldSecs=` and `reason=` (release), `state=armed|cleared` and `dwell=` (recall
hysteresis), `cdLeft=` (every cooldown rejection), `why=` (every rejection reason).

Note the `INFORMATION` lines from `Server_CmdSupportAir.sqf` are always-on (one per state
transition, per the LogContent rule); the per-interval CAS threat dump is gated behind
`WF_LOG_CONTENT`.

---

## 4. KPIs and arming thresholds

### R0 — inertness (blocking)

| KPI | PASS |
|---|---|
| Any `TOWN_NUDGE` / `TEAM_DOCTRINE` / `CMD_SUPPORT` token in either RPT | **0 occurrences** |
| New STATE-A buttons visible to a client | **not rendered** (screenshot) |
| `analyze_soak.py` overall verdict | same band as the pre-feature baseline run |
| Any new `Error`/`Type Nothing`/`undefined variable` line | **0** |

### R1 — town nudge

| KPI | PASS | WATCH | FAIL |
|---|---|---|---|
| `TOWN_NUDGE\|accept` per player per hour | 1-6 | 7-15 | >15 (cooldown not biting) |
| Fraction of fist primaries that changed within 1 tick of an accept | <40% | 40-60% | >60% (the nudge is commanding, not suggesting) |
| `agg=` maximum observed | <= 1.74 (= `sqrt(3)`) | — | >1.74 (ceiling breached) |
| `ring=` maximum observed | <= `WFBE_C_CMD_TOWN_NUDGE_RING` | — | above it (ring unbounded) |
| `TOWN_NUDGE\|reject` with `why=unregistered` | 0 | — | >0 (client sending non-towns) |

**Weight tuning is the point of R1.** Owner ruling 2 says start at 120 and soak-tune. If the
"fist changed within 1 tick" fraction lands above 60%, halve `WFBE_C_CMD_TOWN_NUDGE_WEIGHT` and
re-run; if nudges never visibly matter (<5%), raise it — but never above
`WFBE_C_AICOM_GRUDGE_BONUS` (400), which is the design's hard sizing rule.

### R2 — doctrine

| KPI | PASS |
|---|---|
| `TEAM_DOCTRINE\|...\|accept` from a NON-leader player | **>= 1** (proves ruling 3: no leader-only gate) |
| `cooldown` rejections under deliberate spam | >= 1, and the spammer gets a receipt each time |
| `why=playerLedTeam` when aimed at another human's squad | >= 1 |
| Teams that stopped being retasked by the allocator after a nudge | **0** (advisory, never a pin) |

### R4 — heli support lifecycle

| KPI | PASS | FAIL |
|---|---|---|
| `GRANT` -> `RELEASE` pairs | every GRANT has exactly one RELEASE | an orphan GRANT (leaked grant slot) |
| `heldSecs=` on a `reason=timeout` release | ~= `WFBE_C_CMD_SUPPORT_AIR_TTL` | far below (premature drop) |
| Concurrent grants per side | <= `WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE` | above it |
| Team returned to allocator eligibility after release | yes, within one allocate tick | team stuck in `move`/`patrol` forever |
| `ferry=` distribution | record it — this is what sets a real max-ferry cap | — |
| Heli engaging targets far from the holder | **0** (ruling 4: no free-hunting) | any |
| `NONE` with `why=noEligibleHeli` while an idle gunship existed | 0 | >0 (search too strict) |

### R5 — recall hysteresis

| KPI | PASS |
|---|---|
| `RECALL\|state=armed` followed by `state=cleared` on a brief last-stand blip | grant survives (no `reason=recall-emergency`) |
| Sustained last-stand > `WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST` | exactly one `reason=recall-emergency` release |
| A request inside the post-recall window | `NONE` with `why=recall-hysteresis` |
| Grant/release flapping (>2 recall cycles in 5 min) | **0** |

### R6 — all-on, perf

| KPI | PASS |
|---|---|
| Server FPS delta vs R0 | within noise (no new per-frame work exists, so any delta is suspect) |
| `SRVPERF` / `GRPBUDGET` telemetry | no regression band change |
| Allocate tick duration | no measurable increase (the ring is read once per tick, not per town) |

---

## 5. Arming order

Arm one flag at a time, in the run order above, and only after that run's packet is graded and
posted to the ledger. `WFBE_C_CMD_SUPPORT_JET` stays 0 permanently in this build — there is no
jet grant path, and setting it to 1 does not create one.

`WFBE_C_CMD_TEAM_DOCTRINE` should **not** be armed for gameplay effect until the AssignTowns
stance consumer is built (design section 13.4) — until then the stance is stamped, logged and
receipted but changes no AI behaviour, so R2 only validates the intake path.

---

## 6. Sequencing constraint (from the task card)

Integration is gated on the P0 authority/ledger foundations being reconciled. At the time of
writing, the commander-lease foundation is **PR #1154, still in review** (Fleet card
`wasp-cmd-c1-commander-lease-20260718`, `review_status: pending`). This PR is a draft and must
not merge ahead of it; the `wfbe_aicom_support_holder` grant is keyed on a player object and a
UID, so a change in how commander/player identity is leased is a genuine upstream dependency.
