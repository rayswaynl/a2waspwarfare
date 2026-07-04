# Respawn Map Zoom Persist - No-Change Verification

Lane 246 proposed persisting the respawn minimap zoom by sampling the map control scale while the respawn dialog is open, then restoring that value on the next death.

Current Build84 already has a tunable initial respawn-map zoom:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_RespawnMenu.sqf:23-25` reads `WFBE_C_RESPAWN_MAP_ZOOM` once and passes it to `ctrlMapAnimAdd`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1930` registers the default as `0.03`.

The missing part is not persistence storage; it is an A2 OA-safe way to read the player's live map zoom after mouse-wheel interaction. The obvious command named in the lane, `ctrlMapScale`, is explicitly documented in this repo as unavailable for A2 OA:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1359-1363` states that `ctrlMapScale` is Arma-3-only, unavailable in A2 OA 1.64, and should not be replaced with a zoom hack.
- A maintained-root grep finds `ctrlMapScale` only in those comments, not in executable mission code.
- A maintained-root grep finds no existing `WFBE_PERSISTENT_RESPAWN_MAP_ZOOM` or `WFBE_C_RESPAWN_MAP_ZOOM_PERSIST` implementation.

Therefore, implementing lane 246 as written would either introduce an A3-only command or fake a zoom value without reading the actual control state. Both violate the Build84 agent rules. No SQF change is safe for this lane until an A2 OA-compatible map zoom read source is proven.

Safe future options:

- If an A2 OA-safe zoom read command is proven, store that scalar in `profileNamespace` from the existing `GUI_RespawnMenu.sqf` loop and restore it before the current `ctrlMapAnimAdd`.
- If no read command exists, add explicit respawn-menu zoom controls whose chosen value is owned by the mission UI rather than inferred from mouse-wheel map state.

This PR deliberately leaves mission behavior unchanged.
