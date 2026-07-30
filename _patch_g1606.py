# -*- coding: utf-8 -*-
from pathlib import Path
import re
import hashlib

root = Path(r"C:/Users/Steff/a2waspwarfare/.worktrees/sqf-locality-network-pv-g1606-20260730")
maps = [
    root / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    root / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    root / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]


def write_crlf(path: Path, text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\r\n")
    data = text.encode("utf-8")
    bare = data.replace(b"\r\n", b"").count(b"\n")
    if bare:
        raise SystemExit(f"bare LF count {bare} in {path}")
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()[:12]


def read_n(path: Path) -> str:
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")


SEND_OPT_OLD = """if (!isHostedServer) then {
\tCall Compile Format [\"WFBE_PVF_%1 = _pvf; publicVariableServer 'WFBE_PVF_%1';\", _func];
} else {
\t_pvf Spawn WFBE_SE_FNC_HandlePVF;
};"""

SEND_OPT_NEW = """//--- LOCALITY/PV (g1606 2026-07-30): isHostedServer is FALSE on dedicated, so the old branch
//--- always publicVariableServer'd from the server. publicVariableServer never fires the SENDING
//--- machine's own PVEH - every server-originated Call WFBE_CO_FNC_SendToServer was a silent
//--- no-op (Common_OnUnitKilled for server-local AI, Common_FireArtillery CounterBattery, etc.).
//--- isServer covers dedicated + listen host; pure clients/HC still PVS.
if (isServer) then {
\t_pvf Spawn WFBE_SE_FNC_HandlePVF;
} else {
\tCall Compile Format [\"WFBE_PVF_%1 = _pvf; publicVariableServer 'WFBE_PVF_%1';\", _func];
};"""

SEND_VAN_OLD = """if (!isHostedServer) then {
\tCall Compile Format [\"WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1';\", _func];
} else {
\t_pvf Spawn WFBE_SE_FNC_HandlePVF;
};"""

SEND_VAN_NEW = """//--- LOCALITY/PV (g1606 2026-07-30): same dedicated self-PV trap as SendToServerOptimized -
//--- publicVariable also does not fire the sender's own PVEH. Route server-local calls direct.
if (isServer) then {
\t_pvf Spawn WFBE_SE_FNC_HandlePVF;
} else {
\tCall Compile Format [\"WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1';\", _func];
};"""

CONST_OLD = 'if (isNil "WFBE_C_SUPPLY_SERVER_FIX") then {WFBE_C_SUPPLY_SERVER_FIX = 0};'
CONST_NEW = (
    'if (isNil "WFBE_C_SUPPLY_SERVER_FIX") then {WFBE_C_SUPPLY_SERVER_FIX = 2}; '
    "//--- g1606 2026-07-30: default APPLY (was 0 = silent no-op for every server/AI-originated "
    "ChangeSideSupply via publicVariableServer self-fire trap)"
)

PARAM_PAT = re.compile(
    r'class WFBE_C_SUPPLY_SERVER_FIX \{\n'
    r'title = "Server-side supply-change fix \(rollout stage\)";\n'
    r"values\[\] = \{0,1,2\};\n"
    r'texts\[\] = \{"Off \(default\)","Shadow \(log only\)","Apply"\};\n'
    r"default = 0;\n"
    r"\};"
)
PARAM_NEW = """class WFBE_C_SUPPLY_SERVER_FIX {
title = "Server-side supply-change fix (rollout stage)";
values[] = {0,1,2};
texts[] = {"Off (legacy no-op)","Shadow (log only)","Apply (default)"};
default = 2;
};"""

INIT_OLD = (
    'if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then '
    '{missionNamespace setVariable [format ["wfbe_supply_%1", str _side], '
    'missionNamespace getVariable Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]]};'
)
INIT_NEW = (
    'if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then '
    '{private ["_supKeyG1606"]; _supKeyG1606 = format ["wfbe_supply_%1", str _side]; '
    "missionNamespace setVariable [_supKeyG1606, missionNamespace getVariable Format "
    '["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]]; publicVariable _supKeyG1606}; '
    "//--- g1606: publish start supply so clients see seed without REQUEST_SUPPLY_VALUE round-trip"
)

GET_PAT = re.compile(
    r'(\t*)if \(isNil "_supplyTeam"\) then \{\n'
    r'\1\tREQUEST_SUPPLY_VALUE = player;\n'
    r'\1\tpublicVariableServer "REQUEST_SUPPLY_VALUE";\n'
    r"\n"
    r"\1\t//--- cmdcon44m: NON-BLOCKING like the resistance case below\. The old sleep-poll threw\n"
    r'\1\t//--- "Generic error" from every unscheduled caller \(victory/upgrade FSMs, PVFs\) whenever\n'
    r"\1\t//--- the var was nil - A2 cannot suspend there\. Return 0 now; the PV answer lands for the\n"
    r"\1\t//--- next read \(all callers poll on a cadence\)\.\n"
    r"\1\t_supplyTeam = 0;\n"
    r"\1\};"
)


def get_repl(mo: re.Match) -> str:
    ind = mo.group(1)
    return (
        f"{ind}if (isNil \"_supplyTeam\") then {{\n"
        f"{ind}\t//--- LOCALITY/PV (g1606 2026-07-30): never publicVariableServer FROM the server - that is a\n"
        f"{ind}\t//--- silent no-op and REQUEST_SUPPLY_VALUE = player is null on dedicated. Server-nil means\n"
        f"{ind}\t//--- the seed/apply path has not run; return 0. Clients still request a one-shot fill.\n"
        f"{ind}\tif (!isServer) then {{\n"
        f"{ind}\t\tREQUEST_SUPPLY_VALUE = player;\n"
        f'{ind}\t\tpublicVariableServer "REQUEST_SUPPLY_VALUE";\n'
        f"{ind}\t}};\n"
        f"\n"
        f"{ind}\t//--- cmdcon44m: NON-BLOCKING like the resistance case below. The old sleep-poll threw\n"
        f'{ind}\t//--- "Generic error" from every unscheduled caller (victory/upgrade FSMs, PVFs) whenever\n'
        f"{ind}\t//--- the var was nil - A2 cannot suspend there. Return 0 now; the PV answer lands for the\n"
        f"{ind}\t//--- next read (all callers poll on a cadence).\n"
        f"{ind}\t_supplyTeam = 0;\n"
        f"{ind}}};"
    )


results = []
for m in maps:
    print("MAP", m.name)

    p = m / "Common/Functions/Common_SendToServerOptimized.sqf"
    t = read_n(p)
    if SEND_OPT_OLD not in t:
        raise SystemExit(f"SEND_OPT missing in {p}")
    results.append((str(p.relative_to(root)), write_crlf(p, t.replace(SEND_OPT_OLD, SEND_OPT_NEW)), "SendToServerOptimized"))

    p = m / "Common/Functions/Common_SendToServer.sqf"
    t = read_n(p)
    if SEND_VAN_OLD not in t:
        raise SystemExit(f"SEND_VAN missing in {p}")
    results.append((str(p.relative_to(root)), write_crlf(p, t.replace(SEND_VAN_OLD, SEND_VAN_NEW)), "SendToServer"))

    p = m / "Common/Functions/Common_GetSideSupply.sqf"
    t = read_n(p)
    t2, nsub = GET_PAT.subn(get_repl, t)
    if nsub != 2:
        raise SystemExit(f"GetSideSupply expected 2 subs got {nsub} in {p}")
    results.append((str(p.relative_to(root)), write_crlf(p, t2), f"GetSideSupply x{nsub}"))

    p = m / "Common/Init/Init_CommonConstants.sqf"
    t = read_n(p)
    if CONST_OLD not in t:
        raise SystemExit(f"CONST missing in {p}")
    results.append((str(p.relative_to(root)), write_crlf(p, t.replace(CONST_OLD, CONST_NEW, 1)), "Constants"))

    p = m / "Rsc/Parameters.hpp"
    t = read_n(p)
    if not PARAM_PAT.search(t):
        idx = t.find("WFBE_C_SUPPLY_SERVER_FIX")
        raise SystemExit(f"PARAM missing in {p}: {t[idx:idx+300]!r}")
    results.append((str(p.relative_to(root)), write_crlf(p, PARAM_PAT.sub(PARAM_NEW, t, count=1)), "Parameters"))

    p = m / "Server/Init/Init_Server.sqf"
    t = read_n(p)
    if INIT_OLD not in t:
        idx = t.find("wfbe_supply_%1")
        raise SystemExit(f"INIT missing in {p}: {t[idx-100:idx+200]!r}")
    results.append((str(p.relative_to(root)), write_crlf(p, t.replace(INIT_OLD, INIT_NEW, 1)), "Init_Server"))

print("DONE")
for r in results:
    print(r)

# CH==TK==ZG byte parity for logical files
logical = [
    "Common/Functions/Common_SendToServerOptimized.sqf",
    "Common/Functions/Common_SendToServer.sqf",
    "Common/Functions/Common_GetSideSupply.sqf",
    "Common/Init/Init_CommonConstants.sqf",
    "Rsc/Parameters.hpp",
    "Server/Init/Init_Server.sqf",
]
for rel in logical:
    hashes = []
    for m in maps:
        data = (m / rel).read_bytes()
        # Constants and Parameters and Init_Server may differ across maps beyond our patch
        hashes.append(hashlib.sha256(data).hexdigest()[:12])
    print(rel, hashes, "SAME" if len(set(hashes)) == 1 else "DIFF-OK-IF-MAP")
