#!/usr/bin/env python3
"""Build an isolated WASP proving-ground mission from current source.

The builder copies the current Chernarus source into a generated directory, then applies
test-only topology/config/telemetry overlays. It never edits Missions/ or deploys anything.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

# The optional shared PBO packer is loaded dynamically.  Keep ordinary lab
# builds from leaving __pycache__ artefacts in the source tree.
sys.dont_write_bytecode = True


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SCENARIOS_PATH = HERE / "scenarios.json"
SOURCE_MISSION = REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
UTES_TEMPLATE = HERE / "templates" / "mission.utes.sqm"
OVERLAY_ROOT = HERE / "mission"
OUTPUT_ROOT = (HERE / "out").resolve()
MANIFEST_NAME = "WASP-LAB-MANIFEST.json"
MANIFEST_SCHEMA = "wasp-proving-ground-build-v1"
SAFE_LABEL_RE = re.compile(r"[A-Za-z0-9_.-]+")
GROUP_PARTITION_ARMS = (4, 6, 8, 10, 12)
GROUP_PARTITION_UNITS_PER_ANCHOR = 120
GROUP_PARTITION_TARGET_UNITS = (240, 360)
PARTITION_ID_EXCLUDED_FIELDS = frozenset(
    ("description", "name", "syntheticGroups", "unitsPerGroup", "batchGroups")
)

PREINIT_CALL = 'call compile preprocessFileLineNumbers "test\\ProvingGround_PreInit.sqf";'
PARAMS_ANCHOR = 'if (isMultiplayer) then {Call Compile preprocessFileLineNumbers "Common\\Init\\Init_Parameters.sqf"}; //--- In MP, we get the parameters.'
PV_ALLOW_ANCHOR = "WFBE_CL_PVF_ALLOWED = [];"
HC_ALLOW_ANCHOR = "\t_hcAllowed = false;"
VICTORY_ANCHOR = '\t\t[] execVM "Server\\FSM\\server_victory_threeway.sqf";'


def read_catalog(path: Path = SCENARIOS_PATH) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "wasp-proving-ground-v1":
        raise ValueError(f"unsupported scenario schema in {path}")
    if not isinstance(data.get("defaults"), dict) or not isinstance(data.get("scenarios"), dict):
        raise ValueError(f"malformed scenario catalog in {path}")
    return data


def validate_label(value: str, option: str, max_length: int) -> str:
    if not isinstance(value, str) or not (1 <= len(value) <= max_length) or not SAFE_LABEL_RE.fullmatch(value):
        raise ValueError(
            f"{option} must be 1-{max_length} characters: letters, digits, dot, underscore or dash"
        )
    return value


def resolve_scenario(name: str, catalog: dict[str, Any]) -> dict[str, Any]:
    recipes = catalog["scenarios"]
    if name not in recipes:
        raise KeyError(f"unknown scenario {name!r}; choose from: {', '.join(sorted(recipes))}")
    spec = dict(catalog["defaults"])
    default_flags = dict(spec.get("featureFlags", {}))
    recipe = dict(recipes[name])
    recipe_flags = dict(recipe.pop("featureFlags", {}))
    spec.update(recipe)
    default_flags.update(recipe_flags)
    spec["featureFlags"] = default_flags
    spec["name"] = name
    validate_scenario(spec)
    return spec


def is_group_partition(spec: dict[str, Any]) -> bool:
    name = spec.get("name")
    return isinstance(name, str) and name in {
        f"density-{units_per_group}" for units_per_group in GROUP_PARTITION_ARMS
    }


def derive_workload_fields(spec: dict[str, Any]) -> None:
    """Derive requested members and the equal 120-member density anchors."""
    groups = spec["syntheticGroups"]
    units_per_group = spec["unitsPerGroup"]
    if not isinstance(groups, int) or isinstance(groups, bool):
        raise ValueError(f"{spec['name']}: syntheticGroups must be an integer")
    if not isinstance(units_per_group, int) or isinstance(units_per_group, bool):
        raise ValueError(f"{spec['name']}: unitsPerGroup must be an integer")

    target_units = groups * units_per_group
    declared_target = spec.get("targetSyntheticUnits")
    if declared_target is not None and declared_target != target_units:
        raise ValueError(
            f"{spec['name']}: targetSyntheticUnits={declared_target!r} does not match "
            f"syntheticGroups*unitsPerGroup={target_units}"
        )
    spec["targetSyntheticUnits"] = target_units

    if not is_group_partition(spec):
        spec.setdefault("spawnAnchors", 0)
        return

    if spec["terrain"] != "utes":
        raise ValueError(f"{spec['name']}: group-partition recipes require the Utes terrain")
    expected_arm = int(str(spec["name"]).rsplit("-", 1)[1])
    if units_per_group != expected_arm:
        raise ValueError(
            f"{spec['name']}: unitsPerGroup must remain {expected_arm} so the arm is not mislabeled"
        )
    if spec["syntheticMode"] != "path-loop":
        raise ValueError(f"{spec['name']}: group-partition recipes require path-loop mode")
    if spec["vehicleEvery"] != 0:
        raise ValueError(f"{spec['name']}: group-partition recipes require vehicleEvery=0")
    if spec["expectedHcs"] != 0:
        raise ValueError(f"{spec['name']}: group-partition recipes require expectedHcs=0")
    if spec["busRate"] != 0:
        raise ValueError(f"{spec['name']}: group-partition recipes require busRate=0")
    if spec["schedulerMode"] != "off":
        raise ValueError(f"{spec['name']}: group-partition recipes require schedulerMode=off")
    if target_units <= 0 or target_units % GROUP_PARTITION_UNITS_PER_ANCHOR != 0:
        raise ValueError(
            f"{spec['name']}: target workload must divide into exact "
            f"{GROUP_PARTITION_UNITS_PER_ANCHOR}-member anchors"
        )

    anchors = target_units // GROUP_PARTITION_UNITS_PER_ANCHOR
    if anchors > 3:
        raise ValueError(
            f"{spec['name']}: derived spawnAnchors={anchors} exceeds the three fixed Utes anchors"
        )
    if target_units not in GROUP_PARTITION_TARGET_UNITS:
        raise ValueError(
            f"{spec['name']}: group-partition target must be exactly 240 or 360 synthetic units"
        )
    if groups % anchors != 0:
        raise ValueError(
            f"{spec['name']}: {groups} groups cannot be divided equally across {anchors} anchors"
        )
    groups_per_anchor = groups // anchors
    if groups_per_anchor * units_per_group != GROUP_PARTITION_UNITS_PER_ANCHOR:
        raise ValueError(f"{spec['name']}: unequal requested member workload per anchor")
    declared_anchors = spec.get("spawnAnchors")
    if declared_anchors is not None and declared_anchors != anchors:
        raise ValueError(
            f"{spec['name']}: spawnAnchors={declared_anchors!r} does not match "
            f"the derived equal-work count {anchors}"
        )
    spec["spawnAnchors"] = anchors


def validate_scenario(spec: dict[str, Any]) -> None:
    if spec["terrain"] not in ("utes", "chernarus"):
        raise ValueError(f"{spec['name']}: terrain must be utes or chernarus")
    bounds = {
        "durationSec": (60, 14400), "sampleSec": (5, 300), "warmupSec": (0, 3600),
        "expectedHcs": (0, 4), "popTierPin": (-1, 64), "teamCap": (0, 16),
        "townCap": (-1, 64), "syntheticGroups": (0, 120), "unitsPerGroup": (1, 12),
        "batchGroups": (1, 10), "batchIntervalSec": (5, 600), "vehicleEvery": (0, 20),
        "settleSec": (0, 600),
        "busRate": (0, 50), "minBusAttainmentPct": (0, 100), "minFps": (1, 60), "minHcFps": (1, 60),
        "minHcPct": (0, 100),
        "maxHcImbalancePct": (0, 100), "maxStuckPct": (0, 100), "startingDistance": (100, 10000),
    }
    for key, (low, high) in bounds.items():
        value = spec.get(key)
        if (
            not isinstance(value, (int, float))
            or isinstance(value, bool)
            or not math.isfinite(value)
            or value < low
            or value > high
        ):
            raise ValueError(f"{spec['name']}: {key}={value!r} outside [{low}, {high}]")
    if spec["syntheticMode"] not in ("none", "idle", "path-loop", "combat"):
        raise ValueError(f"{spec['name']}: unsupported syntheticMode={spec['syntheticMode']!r}")
    if spec["schedulerMode"] not in ("off", "shadow", "active"):
        raise ValueError(f"{spec['name']}: schedulerMode must be off, shadow or active")
    if spec["syntheticMode"] == "none" and spec["syntheticGroups"] != 0:
        raise ValueError(f"{spec['name']}: syntheticMode none requires syntheticGroups=0")
    derive_workload_fields(spec)
    if is_group_partition(spec) and spec["sampleSec"] > spec["durationSec"]:
        raise ValueError(
            f"{spec['name']}: group-partition sampleSec must not exceed durationSec"
        )
    for key, (low, high) in {
        "targetSyntheticUnits": (0, 1440),
        "spawnAnchors": (0, 3),
    }.items():
        value = spec.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value < low or value > high:
            raise ValueError(f"{spec['name']}: {key}={value!r} outside integer range [{low}, {high}]")
    if not isinstance(spec.get("featureFlags"), dict):
        raise ValueError(f"{spec['name']}: featureFlags must be an object")
    for key, value in spec["featureFlags"].items():
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            raise ValueError(f"{spec['name']}: unsafe SQF variable name {key!r}")
        if not isinstance(value, (bool, int, float, str, list)):
            raise ValueError(f"{spec['name']}: unsupported value for {key}")


def sqf_literal(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return '"' + value.replace('"', '""') + '"'
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if not math.isfinite(value):
            raise ValueError(f"cannot render non-finite number {value!r} as SQF")
        return str(value)
    if isinstance(value, list):
        return "[" + ",".join(sqf_literal(item) for item in value) + "]"
    raise TypeError(f"cannot render {value!r} as SQF")


def config_digest(spec: dict[str, Any], workload_only: bool = False) -> str:
    payload = json.loads(json.dumps(spec))
    if workload_only:
        payload.pop("variant", None)
        payload.pop("schedulerMode", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:16]


def partition_digest(spec: dict[str, Any]) -> str:
    """Identify runtime config except non-runtime text and the intentional arm shape."""
    payload = json.loads(json.dumps(spec))
    for field in PARTITION_ID_EXCLUDED_FIELDS:
        payload.pop(field, None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:16]


def render_config(
    spec: dict[str, Any], candidate: str = "validate", sha: str = "validate",
    source_id: str = "validate", lab_id: str = "validate",
) -> str:
    variables: list[tuple[str, Any]] = [
        ("WASP_LAB_ENABLED", True),
        ("WASP_LAB_SCENARIO", spec["name"]),
        ("WASP_LAB_VARIANT", spec.get("variant", "control")),
        ("WASP_LAB_CANDIDATE", candidate),
        ("WASP_LAB_GIT", sha),
        ("WASP_LAB_SOURCE_ID", source_id),
        ("WASP_LAB_CODE_ID", lab_id),
        ("WASP_LAB_CONFIG_ID", config_digest(spec)),
        ("WASP_LAB_WORKLOAD_ID", config_digest(spec, workload_only=True)),
        ("WASP_LAB_PARTITION_ID", partition_digest(spec)),
        ("WASP_LAB_DURATION_SEC", spec["durationSec"]),
        ("WASP_LAB_SAMPLE_SEC", spec["sampleSec"]),
        ("WASP_LAB_WARMUP_SEC", spec["warmupSec"]),
        ("WASP_LAB_EXPECTED_HCS", spec["expectedHcs"]),
        ("WASP_LAB_SCHEDULER_MODE", spec["schedulerMode"]),
        ("WASP_LAB_SYNTHETIC_MODE", spec["syntheticMode"]),
        ("WASP_LAB_SYNTHETIC_GROUPS", spec["syntheticGroups"]),
        ("WASP_LAB_TARGET_SYNTHETIC_UNITS", spec["targetSyntheticUnits"]),
        ("WASP_LAB_UNITS_PER_GROUP", spec["unitsPerGroup"]),
        ("WASP_LAB_SPAWN_ANCHORS", spec["spawnAnchors"]),
        ("WASP_LAB_SETTLE_SEC", spec["settleSec"]),
        ("WASP_LAB_BATCH_GROUPS", spec["batchGroups"]),
        ("WASP_LAB_BATCH_INTERVAL_SEC", spec["batchIntervalSec"]),
        ("WASP_LAB_VEHICLE_EVERY", spec["vehicleEvery"]),
        ("WASP_LAB_BUS_RATE", spec["busRate"]),
        ("WASP_LAB_MIN_BUS_ATTAINMENT_PCT", spec["minBusAttainmentPct"]),
        ("WASP_LAB_CLEANUP", spec["cleanup"]),
        ("WASP_LAB_MIN_FPS", spec["minFps"]),
        ("WASP_LAB_MIN_HC_FPS", spec["minHcFps"]),
        ("WASP_LAB_MIN_HC_PCT", spec["minHcPct"]),
        ("WASP_LAB_MAX_HC_IMBALANCE_PCT", spec["maxHcImbalancePct"]),
        ("WASP_LAB_MAX_STUCK_PCT", spec["maxStuckPct"]),
        ("WASP_LAB_DISABLE_VICTORY", True),
        ("WFBE_C_TEST_POPTIER_PIN", spec["popTierPin"]),
        ("WFBE_C_TEST_TEAM_CAP", spec["teamCap"]),
        ("WFBE_C_TEST_TOWN_CAP", spec["townCap"]),
    ]
    variables.extend(sorted(spec["featureFlags"].items()))
    lines = [
        "// Generated by Tools/ProvingGround/build.py. Test mission only.",
        "// Values are deliberately installed before Init_CommonConstants.sqf.",
    ]
    for key, value in variables:
        lines.append(f'missionNamespace setVariable ["{key}", {sqf_literal(value)}];')
    lines.append('diag_log "WASPLAB|v1|CONFIG|loaded=1";')
    return "\n".join(lines) + "\n"


def git_sha() -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def git_dirty(paths: list[Path]) -> bool:
    try:
        result = subprocess.run(
            ["git", "-C", str(REPO), "status", "--porcelain", "--"] + [str(path) for path in paths],
            check=True, capture_output=True, text=True,
        )
        return bool(result.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        return True


def content_digest(
    paths: list[Path], skip_names: frozenset[str] = frozenset(),
    skip_suffixes: tuple[str, ...] = (),
) -> str:
    digest = hashlib.sha256()
    entries: list[tuple[str, Path]] = []
    for root in paths:
        root = root.resolve()
        if root.is_file():
            entries.append((root.name, root))
        elif root.is_dir():
            entries.extend(
                (root.name + "/" + item.relative_to(root).as_posix(), item)
                for item in root.rglob("*")
                if item.is_file() and "__pycache__" not in item.parts
            )
    for label, path in sorted(entries, key=lambda item: item[0].lower()):
        if path.name in skip_names or path.name.lower().endswith(skip_suffixes):
            continue
        digest.update(label.encode("utf-8") + b"\x00")
        digest.update(path.read_bytes())
        digest.update(b"\x00")
    return digest.hexdigest()[:16]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise ValueError(f"{label}: expected one anchor, found {count}: {old!r}")
    return text.replace(old, new, 1)


def render_version(template: str, spec: dict[str, Any], candidate: str, sha: str) -> str:
    candidate = validate_label(candidate, "--candidate", 64)
    terrain = spec["terrain"]
    mission_name = f"WASP LAB {spec['name']} ({terrain.title()})"
    marker = f'#define WF_RELEASE_MARKER "WASPRELEASE|v1|candidate={candidate}|git={sha}|terrain={terrain}"'
    template, count = re.subn(r'^#define WF_RELEASE_MARKER .+$', marker, template, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("version template: WF_RELEASE_MARKER anchor missing")
    template, count = re.subn(r'^#define WF_MISSIONNAME .+$', f'#define WF_MISSIONNAME "{mission_name}"', template, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("version template: WF_MISSIONNAME anchor missing")
    max_players = 56 if terrain == "utes" else 36
    template, count = re.subn(r'^#define WF_MAXPLAYERS .+$', f"#define WF_MAXPLAYERS {max_players}", template, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("version template: WF_MAXPLAYERS anchor missing")
    template, count = re.subn(r'^#define STARTING_DISTANCE .+$', f"#define STARTING_DISTANCE {int(spec['startingDistance'])}", template, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("version template: STARTING_DISTANCE anchor missing")
    if terrain == "utes":
        template, count = re.subn(r'^#define IS_NAVAL_MAP\s*$', '//#define IS_NAVAL_MAP // WASP LAB: Chernarus-coordinate naval systems disabled', template, count=1, flags=re.MULTILINE)
        if count != 1:
            raise ValueError("version template: expected one active IS_NAVAL_MAP anchor for Utes")
    if re.search(r'^\s*#define\s+WF_DEBUG\b', template, flags=re.MULTILINE):
        raise ValueError("refusing to render a proving ground with WF_DEBUG active")
    return template


def modernize_utes_sqm(text: str, title: str) -> str:
    """Keep historical editor geometry, but replace its forced-HC slot with two current-style CIV slots."""
    text = replace_once(text, "\t\titems=82;", "\t\titems=83;", "Utes group count")
    groups_end = text.index("\n\tclass Markers")
    groups = text[:groups_end]
    suffix = text[groups_end:]
    # Make room for a second top-level group. Nested vehicle Item0 classes have deeper indentation.
    def bump(match: re.Match[str]) -> str:
        number = int(match.group(1))
        return f"\t\tclass Item{number + 1 if number >= 55 else number}"
    groups = re.sub(r"(?m)^\t\tclass Item(\d+)$", bump, groups)
    start = groups.index("\t\tclass Item54\n")
    end = groups.index("\t\tclass Item56\n", start)
    hc = """\t\tclass Item54
\t\t{
\t\t\tside=\"CIV\";
\t\t\tclass Vehicles
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tposition[]={2226.2813,7.2136145,3789.3579};
\t\t\t\t\tid=9001;
\t\t\t\t\tside=\"CIV\";
\t\t\t\t\tvehicle=\"Civilian\";
\t\t\t\t\tplayer=\"PLAY CDG\";
\t\t\t\t\tleader=1;
\t\t\t\t\trank=\"LIEUTENANT\";
\t\t\t\t\tskill=0.60000002;
\t\t\t\t\tinit=\"removeAllWeapons this\";
\t\t\t\t\tdescription=\"RESERVED -- HC / do not use\";
\t\t\t\t\tsynchronizations[]={48};
\t\t\t\t};
\t\t\t};
\t\t};
\t\tclass Item55
\t\t{
\t\t\tside=\"CIV\";
\t\t\tclass Vehicles
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tposition[]={2228.2813,7.2136145,3789.3579};
\t\t\t\t\tid=9002;
\t\t\t\t\tside=\"CIV\";
\t\t\t\t\tvehicle=\"Civilian\";
\t\t\t\t\tplayer=\"PLAY CDG\";
\t\t\t\t\tleader=1;
\t\t\t\t\trank=\"LIEUTENANT\";
\t\t\t\t\tskill=0.60000002;
\t\t\t\t\tinit=\"removeAllWeapons this\";
\t\t\t\t\tdescription=\"RESERVED -- HC / do not use\";
\t\t\t\t\tsynchronizations[]={48};
\t\t\t\t};
\t\t\t};
\t\t};
"""
    groups = groups[:start] + hc + groups[end:]
    groups = replace_once(
        groups,
        "synchronizations[]={33,43,34,35,44,45,36,37,46,47,38,39,40,41,42,49,50,51,52,53,55,57,56,58,59,60,61};",
        "synchronizations[]={33,43,34,35,44,45,36,37,46,47,38,39,40,41,42,49,50,51,52,53,55,57,56,58,59,60,61,9001,9002};",
        "Utes WEST owner HC synchronization",
    )
    text = groups + suffix
    text, count = re.subn(r'briefingName="[^"]*";', f'briefingName="{title}";', text, count=1)
    if count != 1:
        raise ValueError("Utes mission.sqm briefingName anchor missing")
    text, count = re.subn(r'briefingDescription="[^"]*";', 'briefingDescription="Generated WASP AI, HC, pathfinding and performance proving ground.";', text, count=1)
    if count != 1:
        raise ValueError("Utes mission.sqm briefingDescription anchor missing")
    if text.count('description="RESERVED -- HC / do not use";') != 2:
        raise ValueError("Utes mission.sqm must contain exactly two current-style HC slots")
    if "forceHeadlessClient" in text:
        raise ValueError("obsolete forced HC slot survived Utes modernization")
    return text


def patch_generated_mission(destination: Path, spec: dict[str, Any]) -> None:
    init_path = destination / "initJIPCompatible.sqf"
    init_text = init_path.read_text(encoding="utf-8")
    if PREINIT_CALL in init_text:
        raise ValueError("generated init already contains ProvingGround pre-init")
    init_text = PREINIT_CALL + "\n" + init_text
    # Lobby params are positional and overwrite globals. Re-apply the generated lab config immediately
    # afterwards so a cached test-box paramsArray cannot silently change the benchmark recipe.
    params_reapply = (
        PARAMS_ANCHOR
        + '\ncall compile preprocessFileLineNumbers "test\\ProvingGround_ResetParams.sqf"; // WASP LAB generated copy: shipped defaults.'
        + '\ncall compile preprocessFileLineNumbers "test\\ProvingGround_Config.sqf"; // WASP LAB generated copy: deterministic recipe overrides.'
    )
    init_text = replace_once(init_text, PARAMS_ANCHOR, params_reapply, "post-params lab config")
    init_path.write_text(init_text, encoding="utf-8", newline="\n")

    pv_path = destination / "Common" / "Init" / "Init_PublicVariables.sqf"
    pv_text = pv_path.read_text(encoding="utf-8")
    pv_insert = (
        '// WASP LAB generated-copy handlers; absent from every production mission.\n'
        '_clientCommandPV = _clientCommandPV + ["LabPing"];\n'
        '_serverCommandPV = _serverCommandPV + ["LabPong"];\n\n'
        + PV_ALLOW_ANCHOR
    )
    pv_path.write_text(replace_once(pv_text, PV_ALLOW_ANCHOR, pv_insert, "PV registration"), encoding="utf-8", newline="\n")

    handler_path = destination / "Client" / "Functions" / "Client_HandlePVF.sqf"
    handler_text = handler_path.read_text(encoding="utf-8")
    hc_insert = HC_ALLOW_ANCHOR + '\n\tif (_script == "CLTFNCLabPing") then {_hcAllowed = true}; // WASP LAB generated copy only.'
    handler_path.write_text(replace_once(handler_text, HC_ALLOW_ANCHOR, hc_insert, "HC LabPing allowlist"), encoding="utf-8", newline="\n")

    server_init = destination / "Server" / "Init" / "Init_Server.sqf"
    server_text = server_init.read_text(encoding="utf-8")
    victory = (
        '\t\tif ((missionNamespace getVariable ["WASP_LAB_DISABLE_VICTORY", false])) then {\n'
        '\t\t\tdiag_log "WASPLAB|v1|VICTORY|disabled=1";\n'
        '\t\t} else {\n'
        + VICTORY_ANCHOR + '\n\t\t};'
    )
    server_init.write_text(replace_once(server_text, VICTORY_ANCHOR, victory, "victory worker"), encoding="utf-8", newline="\n")

    if spec["terrain"] == "utes":
        params_path = destination / "Rsc" / "Parameters.hpp"
        params_text = params_path.read_text(encoding="utf-8")
        old = 'class WFBE_C_GUER_PLAYERSIDE {\n\t\ttitle = "GUER Insurgents (playable faction)";\n\t\tvalues[] = {0,1};\n\t\ttexts[] = {"$STR_WF_Disabled","$STR_WF_Enabled"};\n\t\tdefault = 1;'
        new = old[:-2] + '0; // WASP LAB Utes has no playable-GUER owner topology.'
        params_path.write_text(replace_once(params_text, old, new, "Utes GUER parameter"), encoding="utf-8", newline="\n")


def copy_overlay(destination: Path) -> None:
    for source in OVERLAY_ROOT.rglob("*"):
        if not source.is_file():
            continue
        target = destination / source.relative_to(OVERLAY_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def safe_destination(path: Path, source: Path) -> Path:
    resolved = path.resolve()
    source = source.resolve()
    repo = REPO.resolve()

    # Refuse both directions: a destination below the source would recursively
    # copy itself, while an ancestor (Missions, the repository, or `/`) could
    # erase the source when --force removes an old output.
    if resolved == source or source in resolved.parents or resolved in source.parents:
        raise ValueError(f"refusing destination at, inside, or above source mission: {resolved}")

    # Generated files may live in this tool's gitignored out/ tree.  A custom
    # external staging path is also valid, but no other repository path is.
    if resolved == OUTPUT_ROOT:
        raise ValueError(f"refusing the proving-ground output root itself: {resolved}")
    if resolved == repo or repo in resolved.parents:
        if OUTPUT_ROOT not in resolved.parents:
            raise ValueError(f"refusing destination inside repository outside {OUTPUT_ROOT}: {resolved}")
    return resolved


def assert_owned_destination(path: Path) -> dict[str, Any]:
    """Require the sentinel written by this builder before recursive removal."""
    if not path.is_dir():
        raise ValueError(f"refusing to replace non-directory output: {path}")
    manifest_path = path / MANIFEST_NAME
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(
            f"refusing to replace unowned directory (missing/invalid {MANIFEST_NAME}): {path}"
        ) from exc
    if not isinstance(manifest, dict):
        raise ValueError(f"refusing to replace directory with malformed WASP LAB sentinel: {path}")
    if manifest.get("schema") != MANIFEST_SCHEMA or manifest.get("mission") != path.name:
        raise ValueError(f"refusing to replace directory with mismatched WASP LAB sentinel: {path}")
    return manifest


def prepare_destination(path: Path, force: bool) -> None:
    if not path.exists():
        return
    if not force:
        raise FileExistsError(f"output exists; use --force to replace it: {path}")
    assert_owned_destination(path)
    shutil.rmtree(path)


def safe_pbo_destination(path: Path, mission_dir: Path, source: Path, force: bool) -> Path:
    resolved = path.resolve()
    mission_dir = mission_dir.resolve()
    source = source.resolve()
    repo = REPO.resolve()

    if resolved.suffix.lower() != ".pbo":
        raise ValueError(f"--pbo output must end in .pbo: {resolved}")
    if resolved == mission_dir or mission_dir in resolved.parents or resolved in mission_dir.parents:
        raise ValueError(f"refusing PBO output at, inside, or above generated mission directory: {resolved}")
    if resolved == source or source in resolved.parents or resolved in source.parents:
        raise ValueError(f"refusing PBO output at, inside, or above source mission: {resolved}")
    if resolved == repo or repo in resolved.parents:
        if OUTPUT_ROOT not in resolved.parents:
            raise ValueError(f"refusing PBO output inside repository outside {OUTPUT_ROOT}: {resolved}")
    if resolved.exists():
        if not resolved.is_file():
            raise ValueError(f"refusing to replace non-file PBO output: {resolved}")
        if not force:
            raise FileExistsError(f"PBO exists; use --force-pbo to replace it: {resolved}")
    return resolved


def verify_pbo(path: Path, expected_prefix: str, expected_files: list[tuple[str, bytes]]) -> None:
    """Parse the complete generated PBO, including file bodies and SHA1 trailer."""
    data = path.read_bytes()
    if len(data) < 43:
        raise RuntimeError(f"PBO self-check failed: truncated file {path}")

    def read_asciiz(offset: int) -> tuple[str, int]:
        try:
            end = data.index(b"\x00", offset)
        except ValueError as exc:
            raise RuntimeError("PBO self-check failed: unterminated header string") from exc
        return data[offset:end].decode("latin-1"), end + 1

    trailer_at = len(data) - 21
    if data[trailer_at] != 0 or hashlib.sha1(data[:trailer_at]).digest() != data[trailer_at + 1:]:
        raise RuntimeError("PBO self-check failed: SHA1 trailer mismatch")

    offset = 0
    name, offset = read_asciiz(offset)
    if name != "" or offset + 20 > trailer_at:
        raise RuntimeError("PBO self-check failed: invalid version header")
    version = struct.unpack_from("<5I", data, offset)
    offset += 20
    if version[0] != 0x56657273:
        raise RuntimeError("PBO self-check failed: invalid version magic")

    properties: dict[str, str] = {}
    while True:
        key, offset = read_asciiz(offset)
        if key == "":
            break
        value, offset = read_asciiz(offset)
        properties[key] = value
    if properties.get("prefix") != expected_prefix:
        raise RuntimeError("PBO self-check failed: prefix property mismatch")

    entries: list[tuple[str, int]] = []
    while True:
        entry_name, offset = read_asciiz(offset)
        if offset + 20 > trailer_at:
            raise RuntimeError("PBO self-check failed: truncated file header")
        fields = struct.unpack_from("<5I", data, offset)
        offset += 20
        if entry_name == "":
            if any(fields):
                raise RuntimeError("PBO self-check failed: malformed header terminator")
            break
        if fields[1] != fields[4]:
            raise RuntimeError(f"PBO self-check failed: size mismatch for {entry_name}")
        entries.append((entry_name, fields[4]))

    if [entry[0] for entry in entries] != [item[0] for item in expected_files]:
        raise RuntimeError("PBO self-check failed: packaged file list mismatch")
    for (entry_name, size), (expected_name, expected_body) in zip(entries, expected_files):
        if entry_name != expected_name or size != len(expected_body):
            raise RuntimeError(f"PBO self-check failed: header mismatch for {entry_name}")
        end = offset + size
        if end > trailer_at or data[offset:end] != expected_body:
            raise RuntimeError(f"PBO self-check failed: body mismatch for {entry_name}")
        offset = end
    if offset != trailer_at:
        raise RuntimeError("PBO self-check failed: body/trailer boundary mismatch")


def pack_pbo(mission_dir: Path, out_path: Path, prefix: str) -> None:
    module_path = REPO / "Tools" / "Stresstest" / "pack_stresstest.py"
    module_spec = importlib.util.spec_from_file_location("wasp_stresstest_packer", module_path)
    if module_spec is None or module_spec.loader is None:
        raise RuntimeError(f"cannot load shared PBO packer: {module_path}")
    packer = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(packer)
    packer.assert_version_sqf(mission_dir)
    files = packer.collect_files(mission_dir)
    packer.assert_version_sqf_in_files(files)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = packer.build_pbo_bytes(prefix, files)
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=f".{out_path.name}.", suffix=".tmp", dir=str(out_path.parent), delete=False
        ) as handle:
            temp_name = Path(handle.name)
            handle.write(payload)
            handle.flush()
        packer.selfcheck_pbo(temp_name)
        verify_pbo(temp_name, prefix, files)
        temp_name.replace(out_path)
        temp_name = None
    finally:
        if temp_name is not None:
            try:
                temp_name.unlink()
            except FileNotFoundError:
                pass


def validate_inputs(spec: dict[str, Any], source: Path) -> None:
    required = [
        source / "version.sqf.template", source / "mission.sqm", source / "initJIPCompatible.sqf",
        source / "Common" / "Init" / "Init_PublicVariables.sqf",
        source / "Client" / "Functions" / "Client_HandlePVF.sqf",
        source / "Server" / "Init" / "Init_Server.sqf",
        OVERLAY_ROOT / "test" / "ProvingGround_PreInit.sqf",
        OVERLAY_ROOT / "test" / "ProvingGround_Server.sqf",
        OVERLAY_ROOT / "test" / "RuntimeScheduler.sqf",
        OVERLAY_ROOT / "test" / "ProvingGround_ResetParams.sqf",
        OVERLAY_ROOT / "Client" / "PVFunctions" / "LabPing.sqf",
        OVERLAY_ROOT / "Server" / "PVFunctions" / "LabPong.sqf",
    ]
    if spec["terrain"] == "utes":
        required.append(UTES_TEMPLATE)
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing proving-ground inputs:\n" + "\n".join(missing))
    replace_once((source / "Common" / "Init" / "Init_PublicVariables.sqf").read_text(encoding="utf-8"), PV_ALLOW_ANCHOR, PV_ALLOW_ANCHOR, "PV registration")
    replace_once((source / "initJIPCompatible.sqf").read_text(encoding="utf-8"), PARAMS_ANCHOR, PARAMS_ANCHOR, "post-params lab config")
    replace_once((source / "Client" / "Functions" / "Client_HandlePVF.sqf").read_text(encoding="utf-8"), HC_ALLOW_ANCHOR, HC_ALLOW_ANCHOR, "HC allowlist")
    replace_once((source / "Server" / "Init" / "Init_Server.sqf").read_text(encoding="utf-8"), VICTORY_ANCHOR, VICTORY_ANCHOR, "victory worker")
    render_version((source / "version.sqf.template").read_text(encoding="utf-8"), spec, "validate", "validate")
    if spec["terrain"] == "utes":
        modernize_utes_sqm(UTES_TEMPLATE.read_text(encoding="utf-8"), "WASP LAB validate (Utes)")
    render_config(spec)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scenario", nargs="?", help="scenario name from scenarios.json")
    parser.add_argument("--list", action="store_true", help="list scenarios and exit")
    parser.add_argument("--source", type=Path, default=SOURCE_MISSION, help="current mission source to copy")
    parser.add_argument("--out", type=Path, help="generated unpacked mission directory")
    parser.add_argument("--pbo", type=Path, help="also write a PBO using the reviewed Stresstest packer")
    parser.add_argument("--force-pbo", action="store_true", help="replace an existing --pbo file")
    parser.add_argument("--candidate", help="release marker label (default: wasplab-<scenario>)")
    parser.add_argument("--variant", default="control", help="A/B label recorded in config/manifest/telemetry")
    parser.add_argument("--expected-hcs", type=int, help="override expected HC count (use with variants hc0/hc1/hc2)")
    parser.add_argument("--scheduler-mode", choices=("off", "shadow", "active"), help="lab scheduler mode")
    parser.add_argument("--duration-sec", type=int, help="override recipe duration")
    parser.add_argument("--sample-sec", type=int, help="override telemetry cadence")
    parser.add_argument("--groups", type=int, help="override synthetic group target")
    parser.add_argument("--units-per-group", type=int, help="override synthetic units per group")
    parser.add_argument("--bus-rate", type=int, help="override Common_Send round trips per second")
    parser.add_argument("--team-cap", type=int, help="override per-side AICOM test cap")
    parser.add_argument("--pop-pin", type=int, help="override effective human-count test pin")
    parser.add_argument("--force", action="store_true", help="replace an existing generated output")
    parser.add_argument("--validate-only", action="store_true", help="validate recipe and source anchors without writing")
    args = parser.parse_args(argv)

    catalog = read_catalog()
    if args.list:
        for name, raw in sorted(catalog["scenarios"].items()):
            print(f"{name:20} {raw.get('description', '')}")
        return 0
    if not args.scenario:
        parser.error("scenario is required unless --list is used")
    try:
        spec = resolve_scenario(args.scenario, catalog)
        validate_label(args.variant, "--variant", 48)
        spec["variant"] = args.variant
        candidate = validate_label(args.candidate or f"wasplab-{args.scenario}", "--candidate", 64)
        if args.force_pbo and not args.pbo:
            raise ValueError("--force-pbo requires --pbo")
        overrides = {
            "expectedHcs": args.expected_hcs, "durationSec": args.duration_sec,
            "schedulerMode": args.scheduler_mode,
            "sampleSec": args.sample_sec, "syntheticGroups": args.groups,
            "unitsPerGroup": args.units_per_group, "busRate": args.bus_rate,
            "teamCap": args.team_cap, "popTierPin": args.pop_pin,
        }
        for key, value in overrides.items():
            if value is not None:
                spec[key] = value
        if args.groups is not None or args.units_per_group is not None:
            # Catalog values document the 240-member recipes. CLI scale overrides
            # must re-derive both requested members and their equal anchor count.
            spec.pop("targetSyntheticUnits", None)
            spec.pop("spawnAnchors", None)
        # A 0-HC control is intentionally server-only, so an HC ownership gate
        # and HC round-trip load would be contradictory even when the recipe
        # normally expects HCs.
        if spec["expectedHcs"] == 0:
            spec["minHcPct"] = 0
            if not is_group_partition(spec):
                spec["busRate"] = 0
        validate_scenario(spec)
        source = args.source.resolve()
        validate_inputs(spec, source)
        if args.validate_only:
            print(json.dumps(spec, indent=2, sort_keys=True))
            print("validation: OK")
            return 0

        head_sha = git_sha()
        dirty = git_dirty([source, HERE])
        sha = head_sha + ("-dirty" if dirty else "")
        source_id = content_digest(
            [source], skip_names=frozenset(("version.sqf",)), skip_suffixes=(".bak", ".orig")
        )
        lab_id = content_digest([HERE / "build.py", SCENARIOS_PATH, OVERLAY_ROOT, UTES_TEMPLATE])
        variant_suffix = "" if args.variant == "control" else f"_{args.variant}"
        leaf = f"WASP_ProvingGround_{args.scenario}{variant_suffix}.{spec['terrain']}"
        destination = safe_destination(args.out or (HERE / "out" / leaf), source)
        pbo = None
        if args.pbo:
            pbo = safe_pbo_destination(args.pbo, destination, source, args.force_pbo)
        prepare_destination(destination, args.force)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, destination, ignore=shutil.ignore_patterns("version.sqf", "*.bak", "*.orig"))

        title = f"WASP LAB {args.scenario} ({spec['terrain'].title()})"
        if spec["terrain"] == "utes":
            sqm = modernize_utes_sqm(UTES_TEMPLATE.read_text(encoding="utf-8"), title)
            (destination / "mission.sqm").write_text(sqm, encoding="utf-8", newline="\n")
        copy_overlay(destination)
        (destination / "test" / "ProvingGround_Config.sqf").write_text(
            render_config(spec, candidate, sha, source_id, lab_id), encoding="utf-8", newline="\n"
        )
        patch_generated_mission(destination, spec)

        version = render_version((source / "version.sqf.template").read_text(encoding="utf-8"), spec, candidate, sha)
        (destination / "version.sqf").write_text(version, encoding="utf-8", newline="\n")
        source_id_after = content_digest(
            [source], skip_names=frozenset(("version.sqf",)), skip_suffixes=(".bak", ".orig")
        )
        lab_id_after = content_digest([HERE / "build.py", SCENARIOS_PATH, OVERLAY_ROOT, UTES_TEMPLATE])
        if source_id_after != source_id or lab_id_after != lab_id:
            raise RuntimeError("source/lab inputs changed during build; discard the partial output and retry")
        artifact_id = content_digest([destination])
        manifest = {
            "schema": MANIFEST_SCHEMA, "scenario": spec, "git": sha, "headGit": head_sha, "dirty": dirty,
            "candidate": candidate, "source": str(source), "mission": destination.name,
            "configId": config_digest(spec), "workloadId": config_digest(spec, workload_only=True),
            "partitionId": partition_digest(spec),
            "sourceId": source_id, "labCodeId": lab_id,
            "artifactId": artifact_id,
            "editorVerificationRequired": spec["terrain"] == "utes",
        }
        (destination / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        print(f"Built:      {destination}")
        print(f"Scenario:   {args.scenario}")
        print(f"Terrain:    {spec['terrain']}")
        print(f"Git:        {sha}")
        if spec["terrain"] == "utes":
            print("Gate:       UNVERIFIED Utes topology - dedicated/editor boot test required before any release use")
        if pbo is not None:
            pack_pbo(destination, pbo, destination.name)
            print(f"PBO:        {pbo}")
        return 0
    except (FileNotFoundError, FileExistsError, KeyError, TypeError, ValueError, RuntimeError) as exc:
        print(f"ABORT: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
