# Attack Wave Authority Playbook

This route is kept for older links. Current attack-wave authority evidence lives in [Deep-review findings](Deep-Review-Findings) DR-41 and [Public variable channel index](Public-Variable-Channel-Index).

Treat `ATTACK_WAVE_INIT` as a direct public-variable authority surface outside the generic PVF dispatcher.

Arma 2 OA `addPublicVariableEventHandler` exposes the variable name and value, not a trusted sender identity. The current `ATTACK_WAVE_INIT` payload is only `[_supply, _side]`, so future code work must not rely on `_remoteSender`, `remoteExecutedOwner` or any hidden PV sender. Add a server-verifiable requester/team anchor or redesign the request around server-owned side state before validating authority.
