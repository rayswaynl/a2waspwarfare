# PR-QUEUE-TRIAGE

Status: PARTIAL-BLOCKED. The roster asks for authenticated enumeration of all open PRs and stacked chains. This sandbox could not run `gh` or `git`, and the unauthenticated public PR page only exposed three open PR rows.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Source Limitation

Attempted source:

- Public page: `https://github.com/rayswaynl/a2waspwarfare/pulls`
- Result observed on 2026-07-04: page header showed 3 open PRs and listed PRs #1, #2, #3. Dynamic filters errored in the unauthenticated HTML page.

Blocked sources:

- `gh pr list --state open --limit 200`
- `gh pr view <N>`
- `git log`
- branch/stack validation

Therefore this file is not a final 80-PR triage. It is a queue-triage template plus the only publicly visible rows.

## Summary Counts

| Category | Count | Confidence |
| --- | ---: | --- |
| MERGE-NOW | 0 | Low, blocked by missing auth. |
| HOLD-FOR-V2 | 2 | Medium for public docs PRs only. |
| CLOSE | 1 | Medium for public supply-heli PR because AGENTS says not to re-propose AI supply trucks. |
| UNCLASSIFIED-AUTH-REQUIRED | unknown | High that more work may exist outside public listing. |

## Visible Public Rows

| PR | Title | Category | Reason | Stack status |
| --- | --- | --- | --- | --- |
| #1 | `feat: supply helicopters for both teams` | CLOSE | AGENTS owner constraints say not to re-propose AI supply trucks; supply-heli mechanics are adjacent and should not merge without owner re-approval. | Unknown; auth required. |
| #2 | `docs: add developer wiki mirror` | HOLD-FOR-V2 | Docs-only reference material may still be useful, but must be reconciled against current GUIDE-REV and V2 artifact convention before merge. | Unknown; auth required. |
| #3 | `docs(wiki): Claude review -- round 1 deepening + round 2 adversarial deep-review` | HOLD-FOR-V2 | Docs/review content may be useful as archive context, but should not outrank current V2 specs until reviewed for stale or duplicate instructions. | Unknown; auth required. |

## Required Authenticated Procedure

Run on a machine with authenticated `gh` and normal git access:

```powershell
gh pr list --state open --limit 200 --json number,title,headRefName,baseRefName,isDraft,updatedAt,author,labels > C:\tmp\wasp-open-prs.json
```

For every PR:

```powershell
gh pr view <N> --json number,title,body,headRefName,headRefOid,baseRefName,commits,files,reviews,labels
```

Validation rules:

1. Every open PR appears exactly once.
2. No `MERGE-NOW` PR is stacked on an unmerged base.
3. PRs touching AGENTS, CLAUDE, deploy scripts, HC architecture, player enrollment/JIP, deploy/box scripts, or antistack are owner-review required.
4. Any `WFBE_C_SIM_GATING` PR is CLOSE.
5. Any doctrine-personality PR is CLOSE.
6. Shelved PR duplicates are CLOSE.
7. Docs-only PRs are HOLD-FOR-V2 unless they directly update required V2 process docs.

## Final Table Template

| PR | Title | Files touched | Base | Stack | Category | One-line reason | Required owner decision |
| --- | --- | --- | --- | --- | --- | --- | --- |

