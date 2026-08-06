# Restart-safety harness evidence — core-loop supervisor (HP-01)

Task: `wasp-restart-safety-harness-20260722`
Harness: `Tools/RestartSafety/restart_safety_harness.py`

## Supervisor static checks

| Check | OK | Detail |
|-------|:--:|--------|
| supervisor_file_exists | yes | Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\FSM\server_coreloop_supervisor.sqf |
| descriptor_four_loops | yes | descriptor table covers town/economy/upgrade/groupsgc |
| groupsgc_default_restart | yes | groupsgc default mode 2 (restart) |
| others_default_observe | yes | town/economy/upgrade default mode 1 (observe) |
| init_server_launches_supervisor | yes | Init_Server launches supervisor behind enable flag |
| restart_mode_read_per_loop | yes | per-loop WFBE_C_CORELOOP_RESTART_<ID> arming |

## Per-loop verdict table (owner arming list)

| Loop | Current default | Verdict | Arm recommendation | Flag | Confidence |
|------|-----------------|---------|--------------------|------|------------|
| groupsgc | auto-restart | **GREEN** | keep-auto-restart | `WFBE_C_CORELOOP_RESTART_GROUPSGC` | high |
| town | observe/watch-only | **GREEN** | arm-auto-restart | `WFBE_C_CORELOOP_RESTART_TOWN` | medium |
| economy | observe/watch-only | **RED** | stay-watch-only | `WFBE_C_CORELOOP_RESTART_ECONOMY` | high |
| upgrade | observe/watch-only | **AMBER** | stay-watch-only-until-stuck-paths-cleared | `WFBE_C_CORELOOP_RESTART_UPGRADE` | medium |

### Deploy patchnotes arming list (copy into review + deploy notes)

- Already auto-restart: **groupsgc**
- GREEN → propose arm (mode 2): **town**
- Stay watch-only (mode 1): **economy, upgrade**

## Loop detail

### `groupsgc` — GREEN

- Default mode: auto-restart (2)
- Recommendation: `keep-auto-restart`
- Reason: all crash points idempotent under live re-check; default already auto-restart
- Confidence: high
- Not verified:
  - BASE-GC re-adopt cap races under concurrent commander founding

Static checks:

| Check | OK | Detail |
|-------|:--:|--------|
| owner_generation_gate | yes | owner key wfbe_coreloop_owner_groupsgc + while-gate present |
| heartbeat_stamp | yes | hb stamp wfbe_coreloop_hb_groupsgc |
| two_pass_collect_then_delete | yes | two-pass empty-group reap |
| live_state_recheck | yes | live unit-count recheck before reap |

Crash-point cases:

| Step | Outcome | Detail |
|------|---------|--------|
| `hb` | pass | deleted=[1] mid=[] attempts=1 (mid_attempts=0) |
| `collect` | pass | deleted=[1] mid=[] attempts=1 (mid_attempts=0) |
| `delete_pass` | pass | deleted=[1] mid=[1] attempts=1 (mid_attempts=1) |
| `basegc` | pass | deleted=[1] mid=[1] attempts=1 (mid_attempts=1) |
| `sleep` | pass | deleted=[1] mid=[1] attempts=1 (mid_attempts=1) |

### `town` — GREEN

- Default mode: observe/watch-only (1)
- Recommendation: `arm-auto-restart`
- Reason: all modeled crash points recovered without double-credit/corruption
- Confidence: medium
- Not verified:
  - full server_town.sqf side-effect chains (hangar, naval HVT, leaderboard) under restart
  - mode-2 all-camps capture edge cases

Static checks:

| Check | OK | Detail |
|-------|:--:|--------|
| owner_generation_gate | yes | owner key wfbe_coreloop_owner_town + while-gate present |
| heartbeat_stamp | yes | hb stamp wfbe_coreloop_hb_town |
| sideid_write_present | yes | sideID capture flip write present |
| write_on_change_contested | yes | contested write-on-change path |

Crash-point cases:

| Step | Outcome | Detail |
|------|---------|--------|
| `hb` | pass | side=1 supply=30 flips=1 camps=True |
| `scan` | pass | side=1 supply=30 flips=1 camps=True |
| `drain` | pass | side=1 supply=30 flips=1 camps=True |
| `maybe_flip` | pass | side=1 supply=30 flips=1 camps=True |
| `camps` | pass | side=1 supply=30 flips=1 camps=True |
| `rewards` | pass | side=1 supply=30 flips=1 camps=True |
| `sleep` | pass | side=1 supply=30 flips=1 camps=True |
| `post_flip_reward_restart` | pass | reward stable at 1, flips=1 |

### `economy` — RED

- Default mode: observe/watch-only (1)
- Recommendation: `stay-watch-only`
- Reason: 3 crash-point invariant breach(es); first: partial={'WEST': 100, 'EAST': 0} final={'WEST': 200, 'EAST': 100} overpay={'WEST': 100} (no last-tick idempotency stamp in updateresources.sqf) | Source confirms heartbeat-first then multi-side charge then sleep, with no last-income-tick idempotency key.
- Confidence: high
- Not verified:
  - live RPT CORELOOP|v1|RESTART under production income interval
  - multi-side partial forEach kill timing on real SQF scheduler

Static checks:

| Check | OK | Detail |
|-------|:--:|--------|
| owner_generation_gate | yes | owner key wfbe_coreloop_owner_economy + while-gate present |
| heartbeat_stamp | yes | hb stamp wfbe_coreloop_hb_economy |
| has_charge_sites | yes | income charge sites present |
| last_tick_idempotency_stamp | info | no wfbe_coreloop_last_pay_* (or similar) gate — mid-tick restart can re-pay |

Crash-point cases:

| Step | Outcome | Detail |
|------|---------|--------|
| `hb` | pass | partial={'WEST': 0, 'EAST': 0} final={'WEST': 100, 'EAST': 100} |
| `pay_WEST` | fail | partial={'WEST': 100, 'EAST': 0} final={'WEST': 200, 'EAST': 100} overpay={'WEST': 100} (no last-tick idempotency stamp in updateresources.sqf) |
| `pay_EAST` | fail | partial={'WEST': 100, 'EAST': 100} final={'WEST': 200, 'EAST': 200} overpay={'WEST': 100, 'EAST': 100} (no last-tick idempotency stamp in updateresources.sqf) |
| `sleep` | fail | partial={'WEST': 100, 'EAST': 100} final={'WEST': 200, 'EAST': 200} overpay={'WEST': 100, 'EAST': 100} (no last-tick idempotency stamp in updateresources.sqf) |

### `upgrade` — AMBER

- Default mode: observe/watch-only (1)
- Recommendation: `stay-watch-only-until-stuck-paths-cleared`
- Reason: no double-credit but 2 stuck/incomplete intermediate path(s); first: possible stuck upgrade: upgrading=True process_spawned=False funds=1000 queue=[]
- Confidence: medium
- Not verified:
  - ProcessUpgrade timer completion races with queue restart on real engine
  - dual-currency edge when supply deduct fails mid-path

Static checks:

| Check | OK | Detail |
|-------|:--:|--------|
| owner_generation_gate | yes | owner key wfbe_coreloop_owner_upgrade + while-gate present |
| heartbeat_stamp | yes | hb stamp wfbe_coreloop_hb_upgrade |
| upgrading_gate_before_start | yes | queue + wfbe_upgrading gate present |
| start_order_queue_flag_deduct | yes | indices queue=4990 upgrading=5163 deduct=5547 |

Crash-point cases:

| Step | Outcome | Detail |
|------|---------|--------|
| `hb` | pass | starts=1 funds=800 level={7: 1} upgrading=False queue=[] |
| `gate_check` | pass | starts=1 funds=800 level={7: 1} upgrading=False queue=[] |
| `select` | pass | starts=1 funds=800 level={7: 1} upgrading=False queue=[] |
| `pop_queue` | pass | starts=0 funds=1000 level={7: 0} upgrading=False queue=[] |
| `set_upgrading` | stuck | possible stuck upgrade: upgrading=True process_spawned=False funds=1000 queue=[] |
| `deduct` | stuck | possible stuck upgrade: upgrading=True process_spawned=False funds=800 queue=[] |
| `spawn_process` | pass | starts=1 funds=800 level={7: 1} upgrading=False queue=[] |
| `sleep` | pass | starts=1 funds=800 level={7: 1} upgrading=False queue=[] |

## Proposed SQF arming flips (only GREEN + arm-auto-restart)

Grok probation forbids this lane from applying mission SQF edits. Below is the exact arming intent for a follow-up builder lane / PR stack:

```sqf
// In server_coreloop_supervisor.sqf descriptor defaults OR Init_CommonConstants.sqf:
// town: observe(1) -> restart(2) after harness GREEN
if (isNil "WFBE_C_CORELOOP_RESTART_TOWN") then {WFBE_C_CORELOOP_RESTART_TOWN = 2};
```

## How to re-run

```
python Tools/RestartSafety/restart_safety_harness.py
python -m pytest Tools/RestartSafety/test_restart_safety_harness.py -q
```
