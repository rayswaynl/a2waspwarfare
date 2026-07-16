# Wasp Peach+ playtest reporting

`wasp-playtest-box.ps1` runs on the test box and reads the server, HC1, and sandboxed
HC2 RPTs with `FileShare.ReadWrite`. It returns bounded records and byte watermarks;
it does not write to the game or restart a process.

On the operator host, install the collector at the reviewed box path and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\wasp-playtest-report.ps1 -Action Start -LocalCollector .\wasp-playtest-box.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\wasp-playtest-report.ps1 -Action Tick -LocalCollector .\wasp-playtest-box.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\wasp-playtest-report.ps1 -Action Stop -LocalCollector .\wasp-playtest-box.ps1
```

For production ticks omit `-LocalSourceDirectory`; for a dry-run against harvested live
RPTs provide that directory and `-NoSend`. The reporter uses UTC for window duration and
box freshness, splits the server's `players` roster into humans and the two
`HC-AI-Control-*` clients, and sends all digests/alerts/summaries through the existing
single Peach+ DM endpoint. Alerts are transition/cooldown controlled so an FPS breach,
error spike, crash/desync marker, or mid-test human-player drop does not spam the channel.
