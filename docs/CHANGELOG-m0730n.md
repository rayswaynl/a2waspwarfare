# WASP m0730n / m0730o — crash fix live, broadcast kit folded

**m0730n** (auto-deployed by the empty-server watcher): the register-level-proven crash
014EFCF4 fix — seated-corpse trash defer with its leak repaired (wfbe_trashed reset so the
collector actually retries), AirResp crew-delete yield, and always-on WASPCRASH014E seat-state
instrumentation. Plus everything from m0730m (vehicle-cam velocity feed-forward, in-shot cut
suppression, vehicle standoff/FOV scaling, steady card).

**m0730o** adds, all dark or inert:
- **Broadcast HUD** [WFBE_C_SPECTATOR_BROADCAST_HUD default 0]: styled cutRsc overlay on layer
  12456 (H cycles FULL -> MINIMAL -> OFF, stream-readable sizes) + M-key map dialog
  (RscMapControl, follows the camera, click-to-teleport). Flag 0 = the current cutText card,
  byte-identical behaviour.
- **Join-ACK gate clock fix** (correctness, unflagged): the gate now measures its 120s failover
  on the mission clock like the deadspawn watchdog it must outrun, closing the confirmed
  vulnerable-in-the-holding-area race; the sleep counter stays as a 135s stall backstop.

**Not folded, needs adversarial review first:** the dedicated CIV caster slot lane came back
touching 168 files (it rewired every real-player check in the tree) — pushed as
fable/caster-civ-slot-20260731 for review; it does not ride a live build until it passes.
