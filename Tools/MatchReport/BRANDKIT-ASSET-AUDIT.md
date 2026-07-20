# Match-report BrandKit asset audit

Reviewed 2026-07-20 for `wasp-match-report-overhaul-20260720` / draft PR #1195.

## Scope and rule

The report's drifting vehicle treatment now has six committed fallback files. They
are used only when the optional generated `assets/silhouette_*.png` files are not
present. No vehicle, logo, icon, or faction art was generated or hand-drawn for
this change.

The audit source was `W:\Mijn vualt\Fleet\BrandKit\veh`, cross-checked against
`origin/main:web/public/brand/` in `rayswaynl/miksuus-website-discord-bot`.
Each source file, BrandKit mirror file, and committed report copy had the same
SHA-256 value.

| Fallback | Report role | Dimensions | SHA-256 |
| --- | --- | ---: | --- |
| `veh-hind.png` | helicopter / rotor drift | 2172 x 724 | `a954c8fc72c4de02f71603df7fdefabe0c982648ea593fc39f86e64cdc59431d` |
| `veh-t90.png` | armour drift | 2172 x 724 | `4b735af4170fcbd7d8fc328cb6867740263022fec2df24a66ebffbd708af1f0f` |
| `veh-a10.png` | jet drift | 2172 x 724 | `7c17336b9265fda1ad3b0c35bbdca35768f72ad01f699e642aa3897faafe0f42` |
| `veh-bmp3.png` | APC / IFV drift | 1536 x 1024 | `b3f9626e5fa2e4e1833a56acf80b66e968549210fae8769c846d3fe0523ff051` |
| `veh-grad.png` | artillery drift | 2172 x 724 | `19456950e38f283c6ea232fb0c306a744ea2aa2ef0d28662d61a260d65c12592` |
| `veh-technical.png` | supply / utility drift | 1672 x 941 | `d855853aa2a2b57b5b3c5bd34e91c1c2e032fbaac49ad46201267f829a5895ed` |

## Deliberate exclusions

- `veh-su25.png` and `veh-hemtt.png` appear in the BrandKit convenience mirror but
  are marked draft-pending there and are not on the source-of-truth `origin/main`
  branch. They are intentionally not copied or referenced.
- Optional report art slots under `Tools/MatchReport/assets/` remain optional. Their
  absence does not cause a brand-art substitution or a render failure.

## Gap result

All six vehicle roles the current renderer can select have an approved committed
blackout. No missing vehicle-card image is required for this report rework. The
same result is recorded as an annotation on Fleet card
`brandkit-vehicle-blackouts-missing-20260720`.
