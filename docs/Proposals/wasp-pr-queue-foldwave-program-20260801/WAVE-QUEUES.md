# MERGEABLE wave queues (oldest-first within wave)
# Generated 2026-08-01 by grok-main-07311829-night

## mission-core-r-series (n=26)
- #1599 | 29/07/2026 | codex/string-formatting-bughunt-20260729 | fix(lint): ignore diagnostic STR labels
- #1606 | 29/07/2026 | codex/loadout-gear-bughunt-20260729 | fix: preserve respawn backpack cargo and EASA pricing
- #1612 | 30/07/2026 | fix/ft-mobile-respawn-bughunt-20260730 | fix(ft/respawn): charge-after-success, start recheck, free-mode dedupe, mobile side gate
- #1619 | 30/07/2026 | fix/supply-transport-cargo-bughunt-20260730 | fix(supply): cargo transfer world revalidation + deliverer + exitWith latch
- #1622 | 30/07/2026 | fix/mission-core-disconnect-slot-20260730 | fix(jip): disconnect must not delete preserved AI team leader
- #1625 | 30/07/2026 | fix/aicom-config-param-bughunt-20260730 | fix(aicom): gate AI_Com_Upgrade research on LINKS (UR-H1)
- #1715 | 30/07/2026 | fix/spectator-observer-camera-lifecycle-r36-g1606 | fix(mission-core): death/observer camera lifecycle teardown residuals (r36)
- #1738 | 31/07/2026 | fix/alife-rally-regroup-r61-g1606-20260731 | fix(alife): rally regroup hold + live dest revalidation (r61)
- #1759 | 31/07/2026 | claude/fix-icbm-radiation-player-locality-r69-20260731 | Fix ICBM radiation dealing zero damage to players (locality)
- #1764 | 31/07/2026 | fix/mission-vote-commander-authority-r71-g1606-20260731 | fix(mission-core): vote/commander authority ΓÇö income percent PVF + transfer bind (r71)
- #1766 | 31/07/2026 | fix/aicom-hqstrike-recall-order-r72-g1606-20260731 | fix(aicom): HC order rebind on HQ-strike edge-lost recall (r72)
- #1769 | 31/07/2026 | fix/aicom-order-behaviour-formation-speed-r72-g1606-20260731 | fix(aicom): order behaviour/formation/speed mode assignment integrity (r72)
- #1771 | 31/07/2026 | claude/aicom-air-posture-aipatrol-clobber-r72 | fix(aicom): apply COMBAT/RED air posture AFTER AIPatrol (W13/W22/PatrolAirPass) (r72)
- #1775 | 31/07/2026 | fix/sqf-player-vehicle-utility-actions-r74-g1606-20260731 | fix(sqf): player vehicle utility actions fail-clean (push/taxi/IR/sell/flip r74)
- #1776 | 31/07/2026 | fix/sqf-player-construction-service-actions-r75-g1606-20260731 | fix(sqf): player construction/service actions fail-clean (cancel/eject/MHQ/build r75)
- #1778 | 31/07/2026 | fix/aicom-retreat-withdrawal-fallback-r76-g1606-20260731 | fix(aicom): retreat/withdrawal/fallback after town loss (r76)
- #1779 | 31/07/2026 | fix/alife-usv-driver-lost-reap-r76-g1606-20260731 | fix(alife): USV boat patrol driver-lost reap + water-only unstuck (r76)
- #1780 | 31/07/2026 | fix/alife-naval-boat-patrol-lifecycle-r77-g1606-20260731 | fix(alife): USV coastal boat patrol lifecycle integrity (r77)
- #1782 | 31/07/2026 | fix/mission-match-stats-endround-r78-g1606-20260731 | fix(mission-core): match stats emission + end-round report integrity (r78)
- #1783 | 31/07/2026 | fix/upgrade-ui-queue-r79b-g1606-20260731 | fix(mission-core): upgrade UI + queue integrity fail-clean (r79b)
- #1784 | 31/07/2026 | fix/sqf-trigger-waypoint-scope-r79-g1606-20260731 | fix(sqf): trigger/waypoint statement-scope integrity (r79)
- #1785 | 31/07/2026 | fix/aicom-order-cancel-airlift-clear-r78-g1606-20260731 | fix(aicom): cancel undelivered airlift on order retarget/abort (r78)
- #1787 | 31/07/2026 | fix/player-respawn-cm-hc-barracks-radar-r80b-g1606-20260731 | fix(mission-core): player respawn gear + CM residual + HC PV + barracks queue + AAR detect (r80b)
- #1788 | 31/07/2026 | fix/alife-airdef-manpad-r80-g1606-20260731 | fix(alife): air defence / MANPAD static site lifecycle integrity (r80)
- #1789 | 31/07/2026 | fix/uav-terminal-handover-r78-g1606-20260731 | fix(mission-core): UAV terminal control handover lifecycle (r78)
- #1790 | 31/07/2026 | fix/daytime-skiptime-wrap-r78-g1606-20260731 | fix(sqf): permanent-daylight clamp on all machines + JIP band fold (r78)

## aicom (n=20)
- #1540 | 27/07/2026 | codex/codex-main-07271028-1-teamsfound-chunking | fix(aicom): chunk founding hot scans
- #1548 | 28/07/2026 | codex/main-07260818-ap1-decap-gate-maprelative-20260728 | fix(aicom): map-scale DECAP enemy-town gate
- #1584 | 28/07/2026 | fable/west-jet-templates | feat(aicom): add WEST fixed-wing team templates to USMC roster [flag WFBE_C_AICOM_WEST_JETS default 0]
- #1588 | 28/07/2026 | fable/airlift-v2 | feat(aicom): implement AICOM airlift LIFT at the in-loop delivery point [flag WFBE_C_AICOM_AIRLIFT_V2 default 0]
- #1589 | 28/07/2026 | fable/air-quickstart-v2 | feat(aicom): HC-safe single-team air quickstart at founding [flag WFBE_C_AICOM_AIR_QUICKSTART default 0]
- #1598 | 29/07/2026 | fable/teams-epilogue-nilguard-20260729 | fix(aicom): seed _eligible/_pick epilogue reads on the server-local founding path (live RPT x47 pairs)
- #1603 | 29/07/2026 | fix/aicom-cbr-research-restart-durable-20260729 | fix(aicom): durable CBR research latch across supervisor restart
- #1607 | 29/07/2026 | fix/aicom-produce-sidecap-recheck-20260730 | fix(aicom): nil-safe buy-unit queue release so abort refunds always run
- #1610 | 29/07/2026 | fix/aicom-service-refuel-ground-20260730 | fix(aicom): service tick refuels ground hulls and detours on low fuel
- #1614 | 30/07/2026 | codex/aicom-hqrange-fallback-20260730 | fix(aicom): enforce HQ range on fallback placement
- #1616 | 30/07/2026 | fix/commander-election-vote-tally-latch-20260730 | fix(vote): election tally latch + ballot sanitize + claim/vote grant race
- #1618 | 30/07/2026 | fix/aicom-createteam-turret-crew-20260730 | fix(aicom): man QUERYUNITTURRETS seats in Common_CreateTeam
- #1624 | 30/07/2026 | fix/aicom-config-param-ingest-20260730 | fix(aicom): config ingest ΓÇö paramsArray bounds, funds-sink lobby default, team-cap fallbacks
- #1629 | 30/07/2026 | fix/aicom-order-authority-20260730 | fix(aicom): order-dispatch authority ΓÇö commander/same-side binds for ai-command/request-unit/arty/focus/TeamUpdate
- #1632 | 30/07/2026 | fix/aicom-order-auth-siblings-20260730 | fix(aicom): order-dispatch authority ΓÇö same-side bind for reinforce/posture/fieldorder (siblings #1629 missed)
- #1656 | 30/07/2026 | claude/gdir-suppress-timer-wire-20260730 | fix(gdir): wire dead post-wipe suppression timer (ledger[4] read at :220 but never written) [flag AICOMV2_GDIR_SUPPRESS_WIRE default 0]
- #1781 | 31/07/2026 | fix/aicom-town-attack-pathfind-r78b-g1606-20260731 | fix(aicom): town attack pathfind fail-clean (null leader/hops/camps/path-pos safe r78b)
- #1793 | 31/07/2026 | codex/fold-lane194-victory-pack-20260731 | feat(lane194): victory-pack hold-ticks + HQ-loss winner + roundend flush [flags]
- #1794 | 31/07/2026 | codex/fold-perf-antistack-aicom-cleaner-r2-20260731 | perf(server): antistack mainLoop active-slice audit (r2 fold)
- #1795 | 31/07/2026 | codex/fold-map-clarity-team-marker-null-20260731 | fix(aicom): preserve HC team marker feed on leader handoff (map-clarity fold)

## alife (n=6)
- #1615 | 30/07/2026 | fix/alife-town-detect-hysteresis-20260730 | fix(alife): town detect range hysteresis (active 1.25x > idle 1x)
- #1621 | 30/07/2026 | fix/alife-ambient-event-triggers-20260730 | fix(alife): group-first teardown for ambient/wildcard event despawns
- #1631 | 30/07/2026 | fix/alife-despawn-budget-20260730 | fix(alife): despawn budget integrity (HC shells + capture reclaim + GUER mid-sweep)
- #1655 | 30/07/2026 | claude/naval-cap-capture-teardown-20260730 | fix(alife): tear down GUER carrier CAP when the naval HVT is captured
- #1660 | 30/07/2026 | claude/alife-town-defender-skill-order-20260730 | fix(alife): town-defender scalar skill wiped sub-skill spread (setSkill order)
- #1684 | 30/07/2026 | fix/alife-wakeup-cache-r32-20260730 | fix(alife): cached-group wakeup restores town patrol/defense fidelity (r32)

## sqf-correctness (n=1)
- #1530 | 27/07/2026 | codex/main-07270840-1-usv-coastal-tag-init-race-20260727 | fix: wait for populated USV town roster

## pathfinding (n=1)
- #1770 | 31/07/2026 | fix/sqf-radio-marker-waypoint-chat-r73b-g1606-20260731 | fix(sqf): radio SideMessage + map marker text + waypoint type + chat/CM fail-clean (r73b)

## telemetry-client (n=8)
- #1798 | 01/08/2026 | feat/caster-slots-allowlist-20260801 | feat(caster): Caster 1/2 spectator slots + caster allowlist [flag WFBE_C_CASTER_AUTOSPECTATE default 0]
- #1799 | 01/08/2026 | fold/spectator-stack-20260801 | fold(spectator): v4 streaming stack ΓÇö #1786 (v4/v4.1 free-cam + director) + #1715 (observer lifecycle teardown)
- #1544 | 28/07/2026 | codex/main-07280026-2-fortif-unbuildable | fix: preserve fortification preview color
- #1617 | 30/07/2026 | fix/type-mismatch-queue-token-coercion-20260730 | fix(client): type-safe shared factory queue tokens (AI SCALAR vs player STRING)
- #1626 | 30/07/2026 | fix/sqf-marker-object-leaks-20260730 | fix(markers): unique paraDZ names + ICBM strike marker pre-delete
- #1786 | 31/07/2026 | fable/spectator-v4-streaming-20260731 | feat(spectator): v4 streaming pass ΓÇö smooth director cam, fight-gated town cams, autostart + free-cam overhaul
- #1796 | 31/07/2026 | fable/isrealplayer-call-precedence-20260731 | fix(spectator): parenthesise the IsRealPlayer Call so ! does not negate the array
- #1797 | 31/07/2026 | fix/mission-description-evergreen-20260801 | fix(lobby): production mission descriptions, and drop the build number that rots

## combat-content (n=3)
- #1547 | 28/07/2026 | codex/guer-airdef-slice-chernarus-20260728 | fix(airdef): bound enemy-air scan slices
- #1620 | 30/07/2026 | claude/guer-scud-cost-align-20260730 | fix(guer-drones): align GUER SCUD menu cost to the server charge (WFBE_C_SCUD_COST)
- #1661 | 30/07/2026 | claude/scudstrike-team-side-bind-20260730 | fix(support): carrier SCUD must debit the firing side's own wallet (team/side bind)

## fold-meta (n=1)
- #1401 | 25/07/2026 | claude/u2-harden-attackwave-init-20260725 | fix(security): re-derive ATTACK_WAVE_INIT discount input from server supply

## other (n=14)
- #1262 | 22/07/2026 | codex/07221740-1-startup-hang-timeouts-20260722 | fix(startup): bound silent bootstrap hangs
- #1278 | 22/07/2026 | codex/pr-harness-staleness-refresh-20260722 | fix(tools): refresh 11 stale PR8 static-smoke assertions vs master
- #1536 | 27/07/2026 | claude/earplugs-full-sfx-20260728 | fix(earplugs): duck all effect SFX and restore effects volume on toggle-off
- #1537 | 27/07/2026 | codex/main-07270548-1-manned-defences | fix: preserve static-defense crew fallback at group cap
- #1545 | 28/07/2026 | codex/main-07270715-2-usv-aa-role-refill-20260728 | fix(usv): refill missing flotilla role
- #1602 | 29/07/2026 | fix/defense-reman-nullguard-20260729 | fix(defense): null-guard getPosATL + reman poll
- #1628 | 30/07/2026 | fix/sqf-eh-hygiene-20260730 | fix(sqf): eventhandler hygiene ΓÇö re-index-safe remove, no double Blink, skin restore
- #1633 | 30/07/2026 | fix/economy-funds-authority-g1606-20260730 | fix(economy): funds transfer/donation authority envelope + atomic debit
- #1636 | 30/07/2026 | fix/sqf-object-var-namespace-g1606-20260730 | fix(sqf): object/missionNamespace var pollution ΓÇö CBR registry, FPV PV, disconnect keys
- #1641 | 30/07/2026 | fix/buyunit-payload-authority-g1606-20260730 | fix(buyunit): factory/purchase PV authority ΓÇö FOB envelope, sell envelope, BuyUnit class/side/team
- #1765 | 31/07/2026 | fix/sqf-crew-seat-getin-getout-r71b-g1606-20260731 | fix(sqf): vehicle crew seat getIn/getOut lifecycle integrity (r71b)
- #1777 | 31/07/2026 | fix/sqf-skill-weather-score-arty-actions-r76b-g1606-20260731 | fix(sqf): skill actions + setSkill + daynight + arty shells + endgame score (r76b)
- #1791 | 31/07/2026 | triage/worktree-triage-20260731 | docs: worktree triage report 2026-07-31
- #1792 | 31/07/2026 | kimi/ops-server-launch-autoinit | feat(ops): add -autoInit to server_launch.cmd (cold-boot lobby-idle fix)

