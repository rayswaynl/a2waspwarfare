# Salvage Loop Status - 2026-07-02

Fleet lane 117 asks for the salvage-truck scanner to stop running after the
salvage vehicle dies. The current live target already contains that fix in both
maintained roots, so this lane is a status/evidence closure rather than another
mission source patch.

## Verdict

Status: closed on `claude/build84-cmdcon36@ca278c4bc7a5989be7523f08d90ed5953d15854d`.

Fixing commit: `1ad62bf4a` (`b759: adopt PR #83 bucket-A correctness fixes +
economy guards (B2/B3/B7)`).

The checked files are:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/FSM/updatesalvage.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/FSM/updatesalvage.sqf`

Both maintained copies now use:

```sqf
while {!gameOver && (alive _vehicle)} do {
```

That means the salvage scanner continues only while the match is running and
the salvage truck is alive. A dead salvage truck no longer leaves this client
loop sleeping and rescanning until match end.

## Validation Notes

Checks performed for this status pass:

- `Select-String` confirmed the fixed loop condition at line 11 in both
  maintained roots.
- `git diff --no-index` reported no content difference between the maintained
  Chernarus and Takistan `updatesalvage.sqf` copies.
- `git log -S "while {!gameOver && (alive _vehicle)}"` identifies
  `1ad62bf4a` as the current-lineage change for the two checked files.
- `git show --stat 1ad62bf4a -- <two updatesalvage.sqf files>` shows the
  two-line mirrored loop-condition change.

## Boundaries

This closes only the lane 117 loop-exit bug. It does not claim to solve every
salvage-system issue:

- salvage payout helper spelling/casing and any server-authority payout review
  are separate salvage lanes;
- client-local wreck deletion/reward authority is separate from the dead-truck
  loop condition;
- PR #275 covers different salvage/stealth exploit lanes and does not need this
  loop-exit work duplicated.

Future agents should not reintroduce an `||` loop condition here. The loop is a
client-side scanner attached to one salvage vehicle; it should stop when either
the match ends or that vehicle is no longer alive.
