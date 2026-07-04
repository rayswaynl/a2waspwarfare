# Air Factory Heli Waive - No-Change Verification

Lane 345 asked whether the AI Commander heli-waive path treats destroyed Aircraft Factory structures as valid. Current Build84 already guards that path correctly, so no SQF patch is needed.

Current implementation:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:312-324` builds the `_hasAirFactory` scan and sets `_airHeliWaive`.
- Line 320 sets `_hasAirFactory = true` only from a structure matching the Aircraft Factory class and passing `alive _x`.
- Line 324 then gates heli-only air-tier waiver on `_hasAirFactory` plus `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:423` already registers `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 1` with the comment that planes still need a held airfield.

Maintained mirror check:

- The same `typeOf _x == _afStructClass && {alive _x}` guard exists in the Takistan and Zargabad `AI_Commander_Teams.sqf` mirrors at line 320.
- The same `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` default exists in the Takistan and Zargabad `Init_CommonConstants.sqf` mirrors at line 423.

Conclusion:

The prompt-listed issue is already fixed on the Build84 target. Changing mission SQF would either duplicate the existing guard or risk conflicts in the hot `AI_Commander_Teams.sqf` stack without improving behavior. This PR deliberately leaves mission behavior unchanged and records the verified no-change result for future agents.
