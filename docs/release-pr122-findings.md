# PR #122 Release Findings

Last updated: 2026-07-01 09:35 Europe/Amsterdam

This document is the running Codex release-captain findings log for the July 2
release pass. It is intentionally documentation-only: no gameplay source,
mission generation output, livehost config, or private credential is included
here.

## Current Verdict

NO-GO as a release claim until exact-build runtime evidence exists.

PR #122 is source-backed and static/tooling-clean, but release-ready wording
still needs current Arma 2 OA evidence from the exact build, covering both
Chernarus and Takistan plus server, client, late join, and headless-client
roles.

## Current Anchors

- Repository: `rayswaynl/a2waspwarfare`
- Base branch: `origin/master`
- Base head: `bd48a6dbe673ae47a88053dafdf948a29cb8dfe0`
- PR #122 branch: `origin/feat/qol-polish-pack`
- PR/scanner head: `4c66c3b6b1c20321163e732d6d06f5dacaeb4e5a`
- Mission-content head: `f5c41461508e117d13d0b6172cbd66698091a8eb`
- Comparison remote `Miksuu/a2waspwarfare`: `b8389e7482438edd00f420c5bb795ac0a642971f`
- Wiki head checked during the release loop: `a8b4dc229f59d452f3afd031fd0c3c914d4f33f2`

GitHub currently reports PR #122 as open, non-draft, and mergeable, with no
reported checks. Mergeability is not runtime proof.

## Evidence Already Strong

- The real AICOM implementation for this release path lives in current
  `rayswaynl/a2waspwarfare` PR #122 mission files, not old Miksuu master.
- Chernarus remains the source mission and Takistan is generated from it.
- Checked AICOM/HC files match between maintained Chernarus and generated
  Takistan in the current PR #122 release slice.
- LoadoutManager reaches `CHERNARUS DONE` and `TAKISTAN DONE` for the PR #122
  mission-content head.
- The release scanner has gates for server debug/content logging, PR #122 guard
  markers, both terrain windows, HC registry proof, and stronger AICOM
  telemetry.
- The exact mission-folder artifact and portable folder-smoke kit were built
  locally during the release loop and hash-checked:
  - mission artifact SHA256:
    `CB67EC13696FC97C9C497884B7808A79D02422B79F6A82D23BA81E18EE65ED49`
  - folder-smoke kit SHA256:
    `1F1588001C69BDE3514C53A23E91E30C455846E41BFF39CDE720892C19B41E93`
- Wiki wording has been kept runtime-pending rather than calling PR #122
  release-ready without RPT evidence.

## Main Runtime Gaps

The release still needs exact-build evidence for:

- Chernarus server RPT
- Takistan server RPT
- hosted/client RPT
- late-join client RPT
- HC1 RPT
- HC2 RPT, unless the topology is explicitly changed and documented
- scanner PASS with:
  - `-RequireServerDebug`
  - `-RequirePr122Markers`
  - `-RequireAicomTelemetry`
  - `-RequireHcRegistry`
  - `-RequireBothTerrains`
- human smoke notes for factory slope behavior, JIP flags, corpse guard, TAGS
  toggle, JIP/deadspawn guards, HC registry behavior, AICOM team founding, and
  Takistan flow.

Current livehost RPTs are useful baseline health evidence only. They are not
proof of PR #122 because they are not tied to the exact mission-content artifact
and do not satisfy the release scanner gates.

## Livehost Findings

Read-only probes found the active livehost config shape still using
`cmdcon30aicom` mission template names:

- active Chernarus resolves to a same-name live PBO
- active Takistan does not resolve to a same-name PBO or folder in active
  `MPMissions`
- a parked Takistan candidate exists outside active `MPMissions`, but it is not
  active release proof

No livehost writes, deploys, config edits, or restarts were performed by Codex
during this findings pass.

## ASR / Ka-137 Stop-Condition Finding

The newest baseline Chernarus server RPT showed 10 release-gating
stop-condition matches. Follow-up triage connected the visible failing
expression/error-position pairs to the external ASR AI fired/gunshot-hearing
handler:

- external path: `x\asr_ai\addons\sys_aiskill\fnc_fired.sqf`
- error shape includes `nearEntities [["CAManBase","StaticWeapon"], ...]`
- error text includes `Bad conversion: array` and
  `Error 0 elements provided, 3 expected`
- the failure window correlates with GUER `Ka137_MG_PMC` air-defense activity

The current PR #122 mission content still defaults GUER light air defense to
`Ka137_MG_PMC`. A mission-local ASR mitigation candidate was validated in an
isolated disposable worktree only:

```sqf
class asr_ai {
	class sys_aiskill {
		gunshothearing = 0;
	};
};
```

That candidate touched only the two maintained `description.ext` files and
regenerated through Chernarus/Takistan validation. It has not been applied to
PR #122, has not been pushed, and is not runtime-proven. Accepting it would
invalidate the current artifacts and require a fresh rebuild plus exact-build
ASR-enabled RPT proof.

## Recommended Next Path

1. Preserve PR #122 mission content as-is unless the owner/operator chooses the
   ASR mitigation path.
2. Run the exact current artifact through folder-smoke or a controlled dedicated
   proof environment with content logging enabled.
3. Collect both-map server/client/latejoin/HC evidence.
4. Run the release scanner with all required gates.
5. Attach human smoke notes.
6. Only then update release notes/wiki wording from runtime-pending to
   release-proven.

If the ASR/Ka-137 stop-condition errors recur on the exact proof runtime,
choose one explicit mitigation path:

- keep current artifact and prove on a non-failing ASR-compatible stack
- apply the narrow mission-local ASR `gunshothearing = 0` override and rebuild
- make GUER Ka-137 air defense opt-in/off and rebuild
- approve an ASR userconfig/addon-side fix outside this mission PR

Every source-changing mitigation resets the artifact hashes and evidence clock.
