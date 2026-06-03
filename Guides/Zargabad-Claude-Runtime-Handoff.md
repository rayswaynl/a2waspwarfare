# Zargabad Claude Runtime Handoff

This is the runtime half of PR #9. Static mission validation is already covered by `Tools/Validate-ZargabadMission.ps1`; this file is for the Arma 2 OA hosted/dedicated/JIP/HC evidence that cannot be proven from source alone.

## Do Not Stop Until

Claude/runtime tester should keep going until there is RPT and short note evidence for every required gate below:

| Gate | Required evidence |
| --- | --- |
| Hosted boot | Zargabad mission reaches server init end without Arma script errors. |
| Dedicated boot | Dedicated server reaches server init end without missing script/include/dependency errors. |
| Town init | RPT contains `Init_Server.sqf: Town starting mode is done`. |
| Zargabad init | RPT contains `Init_Zargabad.sqf: Spawn fortifications, central wall gaps, and side defenses are placed`. |
| Edge guard init | RPT contains `Zargabad_EdgeGuard.sqf: outer [120]m rim timeout [45]s safe range [325]m`. |
| Runtime audit | RPT contains `Zargabad_RuntimeAudit.sqf` lines with 13 towns, 19 camps, 1 airport, 33 defenses, start SV 185, max SV 648, and the Zargabad economy/range constants. |
| JIP | A second client joins after time > 30 and RPT shows player join/JIP storage; markers and town colors still match current ownership. |
| HC | If the server uses HC, RPT shows `Headless client is now connected` and town AI/static defense still wakes. |
| Base safety | WEST/EAST starts cannot trivially spawn-kill each other or suppress city routes from spawn. |
| Central wall | Wall around `3425,3375` interrupts flat middle sightlines; gaps pass infantry, light armor and AI. |
| Side hills/rim | Extreme-rim ground camping is removed after the configured timeout; objective-near fights and aircraft are not punished. |
| Economy | City/airfield are valuable without runaway snowball; farms/outskirts stay lower-value flank objectives. |
| Factory lists/costs | MBTs/heavy attack aircraft are absent from normal Zargabad factory flow; light/heavy/air/airport price multipliers are visible. |
| Mystery feature | Owning Zargabad Airfield can surface the black-market cache; crate/smoke cleanup behaves normally. |

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

Use `-AllowKnownDisconnectScoreErrors` only if the only RPT `ERROR` lines are the existing disconnect score messages after intentionally disconnecting test clients.

## Notes To Capture

- Screenshot or coordinates for WEST/EAST start sightlines.
- Screenshot or coordinates for the central wall gaps that were driven/walked through.
- RPT excerpt for edge-guard init and, if tested, removal.
- RPT excerpt for the `Zargabad_RuntimeAudit.sqf` count/SV and economy/range lines.
- RPT excerpt for black-market cache surfacing.
- Any observed town where static defenses face the wrong route or block normal movement.
- Any economy issue where city/airfield income or vehicle pricing snowballs too fast in a 5v5-style test.
