# Zargabad Claude Runtime Handoff

This is the runtime half of PR #9. Static mission validation is already covered by `Tools/Validate-ZargabadMission.ps1`; this file is for the Arma 2 OA hosted/dedicated/JIP/HC evidence that cannot be proven from source alone.

## Coordination Cadence

Claude should send Codex a short status after each Codex commit or major runtime gate: hosted boot, dedicated boot, JIP, HC, base safety, central wall/pathing, rim abuse, economy/factory pricing, and mystery feature. Include the RPT path or excerpt, screenshot/coordinate notes when visual, and a clear pass/fail/uncertain label.

Codex should treat Claude's runtime findings as authoritative when they include RPT evidence, screenshots, coordinates, or repeatable repro steps. If Claude finds a real issue, update the mission or validators instead of trying to preserve the current implementation.

Static claims from Codex should be handed back to Claude with the command evidence that proved them. Runtime or design claims from Claude should be accepted when they include reproducible evidence, then converted into a source patch, validator check, or explicit retest request.

After each Codex commit, generate the current Claude brief and paste it to the runtime tester before asking for another pass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadClaudeBrief.ps1
```

The brief names the latest commit, PR head, files changed by that commit, inferred retest focus, required runtime commands, dirty local state warning, and the stop/go rule. Use it as the fresh context packet so Claude is not working from stale chat memory.

After each RPT-producing pass, Claude should generate a compact markdown status with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadRuntimeReport.ps1 -RptPath "C:\path\to\rpts"
```

Use the same required switches as the validator for the gate being tested, then paste the report and any screenshots/coordinates back to Codex.

The `Claude Notes` table in the report is part of the gate, not optional commentary. Mark each runtime check `PASS`, `FAIL`, or `UNCERTAIN`; every `FAIL` or `UNCERTAIN` row should include coordinates, screenshot filenames, RPT excerpts, or repeatable repro steps. Codex should listen to that evidence: if Claude proves the mission is wrong, Codex updates mission code or validators before asking Claude to repeat the same pass.

Before Codex makes a stop/go call on a filled runtime report, run the report validator against Claude's edited markdown. It fails if required gates are still `MISSING`, the failure scan contains `FOUND`, key evidence placeholders remain, or any Claude Notes row is not `PASS`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeReport.ps1 -ReportPath ".\zargabad-runtime-report.md" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireBlackMarket
```

For map-placement, defense-facing, pathing, or sightline notes, generate a coordinate packet before the playtest and paste it beside the runtime report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadMapAuditPacket.ps1 -OutputPath ".\zargabad-map-audit.md"
```

Use the packet's objective, camp, defense, start, base-axis, rim-test and central-wall checkpoint coordinates as the shared reference for screenshots and repro notes.

For fortification changes, use Steff's WDDM tool at https://rayswaynl.github.io/WDDM/ beside the map audit packet. WDDM/`CreateDefenseTemplate` coordinates are relative to the template origin, with `+Y` as front and `+X` as right. If Claude proposes a base wall or central-wall change, paste the WDDM-exported SQF or coordinate deltas back with screenshots/RPT evidence before Codex edits the template.

## Do Not Stop Until

Claude/runtime tester should keep going until there is RPT and short note evidence for every required gate below:

| Gate | Required evidence |
| --- | --- |
| Hosted boot | Zargabad mission reaches server init end without Arma script errors. |
| Dedicated boot | Dedicated server reaches server init end without missing script/include/dependency errors. |
| Town init | RPT contains `Init_Server.sqf: Town starting mode is done`. |
| Zargabad init | RPT contains `Init_Zargabad.sqf: Spawn fortifications, central wall gaps, and side defenses are placed`. |
| Town defense orientation | RPT contains `Init_Zargabad.sqf: Oriented [33] town defense logics toward linked town centers`. |
| Edge guard init | RPT contains `Zargabad_EdgeGuard.sqf: outer [120]m rim timeout [45]s safe range [325]m`. |
| Runtime audit | RPT contains `Zargabad_RuntimeAudit.sqf` lines with 13 towns, 19 camps, 1 airport, 33 defenses, start SV 185, max SV 648, base/static/wall counts, `baseFootprint [35,45,74,78]`, `centralWallCrewed [0]`, central-wall gap checkpoints, factory restriction counts, exact compact normal heavy/aircraft lists, price multipliers/samples, and the Zargabad economy/range/weapon-pressure constants. |
| Base static templates/positions | RPT contains `Zargabad_RuntimeAudit.sqf: baseStaticTemplates` with the WEST M2/TOW/Stinger and EAST KORD/Metis/Igla layouts plus `Init_Zargabad.sqf: Base static runtime positions WEST ... EAST ...`; screenshot notes should call out any mismatch between template, actual spawned position/facing, manning, commander space, `baseFootprint [35,45,74,78]`, and usable firing arcs. |
| JIP | A second client joins after time > 30 and RPT shows player join/JIP storage; markers and town colors still match current ownership. |
| HC | If the server uses HC, RPT shows `Headless client is now connected` and town AI/static defense still wakes. |
| Base safety | WEST/EAST starts cannot trivially spawn-kill each other or suppress city routes from spawn. |
| Central wall | Wall around `3425,3375` interrupts flat middle sightlines, reports `centralWallCrewed [0]`, and does not create an armed middle-map kill strip; gap checkpoints around `[4053,2725]`, `[3789,2998]`, `[3504,3293]`, `[3195,3613]`, and `[2903,3915]` pass infantry, light armor and AI. |
| Side hills/rim | The map audit Rim Test Points pass: ground vehicles at `80,3000`, `3000,80`, `5900,3000`, and `3000,5900` are removed after the configured timeout, while `3600,5900`, `4330,5900`, `5900,4340`, and aircraft/objective-near fights are not punished. |
| Economy | City/airfield are valuable without runaway snowball; farms/outskirts stay lower-value flank objectives. |
| Factory lists/costs | Source/static validation proves exact compact WEST/EAST normal heavy/aircraft lists with MBTs, MLRS, SPAAGs, attack helicopters and attack jets excluded; runtime confirms buy-menu availability and price feel. |
| Weapon/range pressure | Runtime audit shows missile range 2000, UAV range 800, town defense/mortar/patrol ranges 45/500/350, hangar range 35, and countermeasures 16/24; Claude confirms they feel sane on the smaller map. |
| Mystery feature | RPT contains `Zargabad_BlackMarket.sqf: armed near Zargabad Airfield positions` after town init; owning Zargabad Airfield can surface the black-market cache; RPT proves cache spawn and cleanup release. |

## Commands For Evidence

Run the source validator before packaging or starting the mission:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadMission.ps1
```

After each hosted/dedicated smoke, point the RPT validator at the relevant log file or directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath "C:\path\to\server-or-client.rpt"
```

For the JIP pass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath "C:\path\to\rpts" -RequireJip
```

For the HC pass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath "C:\path\to\rpts" -RequireHeadlessClient
```

For the optional edge-guard and black-market action checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath "C:\path\to\rpts" -RequireEdgeGuardRemoval -RequireBlackMarket
```

For a Codex-ready handoff report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadClaudeBrief.ps1 -OutputPath ".\zargabad-claude-brief.md"
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadMapAuditPacket.ps1 -OutputPath ".\zargabad-map-audit.md"
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadRuntimeReport.ps1 -RptPath "C:\path\to\rpts" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireBlackMarket -OutputPath ".\zargabad-runtime-report.md"
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeReport.ps1 -ReportPath ".\zargabad-runtime-report.md" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireBlackMarket
```

Use `-AllowKnownDisconnectScoreErrors` only if the only RPT `ERROR` lines are the existing disconnect score messages after intentionally disconnecting test clients.

## Notes To Capture

- Screenshot or coordinates for WEST/EAST start sightlines.
- Screenshot from the base-axis midpoint/wall origin `3425,3375` toward both default starts, and from both default starts back toward `3425,3375`.
- Screenshot or coordinates for the central wall gaps that were driven/walked through, especially `[4053,2725]`, `[3789,2998]`, `[3504,3293]`, `[3195,3613]`, and `[2903,3915]`.
- WDDM-exported SQF or coordinate deltas for any proposed central-wall or base-fortification change, with the origin/direction used for review.
- RPT excerpt for edge-guard init and removal at the illegal rim points; screenshot/coordinate notes for the legal North Camp, Rahim Villa and East Farms rim points that did not get removed.
- RPT excerpt for `Init_Zargabad.sqf: Oriented [33] town defense logics toward linked town centers`.
- RPT excerpt for the `Zargabad_RuntimeAudit.sqf` count/SV, base/static/wall with `baseFootprint [35,45,74,78]`, `centralWallCrewed [0]` and `centralWallGaps`, base static template, factory restriction, price multiplier/sample, and economy/range/weapon-pressure lines.
- RPT excerpt for `Init_Zargabad.sqf: Base static runtime positions WEST ... EAST ...`, plus screenshot/coordinate notes for spawned position/facing and usable arcs.
- RPT excerpt for `Zargabad_BlackMarket.sqf: armed near Zargabad Airfield positions` before waiting for the ownership-gated cache roll.
- RPT excerpts for black-market cache surfacing and cleanup release.
- Buy-menu notes for the exact compact normal factory lists: WEST heavy `M2A2_EP1/M2A3_EP1/BAF_FV510_D`, EAST heavy `M113_TK_EP1/BMP2_TK_EP1/T34_TK_EP1/BMP3`, WEST aircraft utility/light transport only, and EAST aircraft utility/light transport only.
- Weapon/range notes for missile range, UAV spotting, town defense/mortar/patrol ranges, purchase hangar range, and reduced aircraft countermeasures.
- Any observed town where static defenses still face the wrong route or block normal movement after the orientation pass.
- Any economy issue where city/airfield income or vehicle pricing snowballs too fast in a 5v5-style test.

## How Codex Should Respond

When Claude sends a report:

1. Treat RPT-backed validator failures as mission bugs until disproven.
2. Treat screenshot/coordinate/repro-backed gameplay failures as actionable design findings.
3. If evidence is concrete, patch the mission, validator, or handoff docs before requesting another pass.
4. If evidence is ambiguous, ask Claude for the smallest missing proof: exact coordinates, RPT excerpt, screenshot filename, or reproduction steps.
5. Do not ask Claude to stop until every required gate has a `PASS` or an accepted follow-up fix.
