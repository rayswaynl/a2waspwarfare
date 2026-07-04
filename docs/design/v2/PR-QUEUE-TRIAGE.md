# PR Queue Triage

Status: BLOCKED in N5N7 sandbox  
Lane: 453

## Blocker

The lane requires:

- `gh pr list --state open --limit 200`
- `gh pr view` per PR
- git log/merge validation

This sandbox showed repeated Windows sandbox error 206 during shell execution, and the user explicitly instructed not to push or open PRs. Because live PR enumeration could not be trusted, this file does not fabricate the ~80-PR decision table.

## Classification Rules For Orchestrator

Every open PR must appear exactly once and receive one category:

- `MERGE-NOW`: self-contained, not stacked on an unmerged base, no owner-rejected feature, no live-runtime/deploy risk, verification present.
- `HOLD-FOR-V2`: useful but conflicts with V2 prep/build sequencing, stacked on pending work, needs soak, or touches high-risk systems.
- `CLOSE`: duplicates shelved/rejected work, conflicts with owner constraints, uses rejected flags/features, obsolete after newer build, or unsafe for A2 OA.

## Mandatory CLOSE Filters

Classify as `CLOSE`:

- any PR wiring `WFBE_C_SIM_GATING`
- doctrine-personality PRs
- TPWCAS proposals
- AI supply truck proposals
- satchel AI proposals
- EMP/WP/DECOY SCUD munitions
- antistack touch proposals
- ACR content proposals
- duplicates of shelved PR pages

## Mandatory HOLD Filters

Classify as `HOLD-FOR-V2` unless owner explicitly approves:

- HC architecture
- player enrollment/JIP flow
- deploy/box scripts
- live runtime settings
- GUER output caps/nerfs
- commander changes not aligned with V2 one-master-flag fallback

## Decision Table Template

| PR | Branch | Title | Stack/base | Category | One-line reason | Verification risk |
|---:|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | Run `gh pr list` outside this sandbox. | TBD |

## Commands For Orchestrator

```powershell
gh pr list --state open --limit 200 --json number,title,headRefName,baseRefName,isDraft,updatedAt,author
gh pr view <number> --json number,title,body,headRefName,baseRefName,commits,files,reviews,mergeStateStatus
```

For stacked validation:

```powershell
git log --oneline --decorate --graph --all --max-count=200
git merge-base <pr-head> origin/claude/build84-cmdcon36
```

## Summary Counts

Not filled in this sandbox:

- `MERGE-NOW`: blocked
- `HOLD-FOR-V2`: blocked
- `CLOSE`: blocked
- total open PRs: blocked
