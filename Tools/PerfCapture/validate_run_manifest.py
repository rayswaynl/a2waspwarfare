#!/usr/bin/env python3
"""Validate and finalize an a2wasp performance run manifest.

The validator is dependency-free. It implements the JSON Schema draft-07
keywords used by run-manifest.schema.json, then applies deterministic cross-field
rules for identities, topology, timing, lifecycle state, and artifact naming.

Finalization is one-way: canonical JSON bytes are written atomically and a
MANIFEST.sha256 seal is created. A matching seal is idempotent; a mismatching
seal is never overwritten.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
from typing import Any


HERE = Path(__file__).resolve().parent
DEFAULT_SCHEMA = HERE / "run-manifest.schema.json"
SEAL_NAME = "MANIFEST.sha256"

_JSON_TYPES: dict[str, type | tuple[type, ...]] = {
    "object": dict,
    "array": list,
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "null": type(None),
}


def load_schema(path: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    schema_path = Path(path) if path is not None else DEFAULT_SCHEMA
    with schema_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def canonical_bytes(document: dict[str, Any]) -> bytes:
    text = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return (text + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _type_ok(value: Any, specification: str | list[str]) -> bool:
    names = specification if isinstance(specification, list) else [specification]
    for name in names:
        python_type = _JSON_TYPES.get(name)
        if python_type is None:
            continue
        if name in {"integer", "number"} and isinstance(value, bool):
            continue
        if isinstance(value, python_type):
            return True
    return False


def _resolve_ref(root: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValueError(f"only local schema references are supported: {reference}")
    node: Any = root
    for token in reference[2:].split("/"):
        token = token.replace("~1", "/").replace("~0", "~")
        node = node[token]
    if not isinstance(node, dict):
        raise ValueError(f"schema reference is not an object: {reference}")
    return node


def _parse_utc(value: str) -> datetime:
    if not value.endswith("Z"):
        raise ValueError("timestamp must use the UTC Z designator")
    parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ValueError("timestamp must be UTC")
    return parsed


def _walk_schema(
    node: dict[str, Any],
    data: Any,
    path: str,
    errors: list[str],
    root: dict[str, Any],
) -> None:
    if "$ref" in node:
        _walk_schema(_resolve_ref(root, node["$ref"]), data, path, errors, root)
        return

    if "const" in node and data != node["const"]:
        errors.append(f"{path}: expected constant {node['const']!r}, got {data!r}")
    if "enum" in node and data not in node["enum"]:
        errors.append(f"{path}: {data!r} is not one of {node['enum']!r}")

    if "type" in node and not _type_ok(data, node["type"]):
        errors.append(f"{path}: expected type {node['type']!r}, got {type(data).__name__}")
        return

    if isinstance(data, str):
        if "minLength" in node and len(data) < node["minLength"]:
            errors.append(f"{path}: string is shorter than {node['minLength']}")
        if "pattern" in node and re.fullmatch(node["pattern"], data) is None:
            errors.append(f"{path}: {data!r} does not match {node['pattern']!r}")
        if node.get("format") == "date-time":
            try:
                _parse_utc(data)
            except (TypeError, ValueError) as exc:
                errors.append(f"{path}: invalid UTC date-time ({exc})")

    if isinstance(data, (int, float)) and not isinstance(data, bool):
        if not math.isfinite(data):
            errors.append(f"{path}: numeric value must be finite")
        if "minimum" in node and data < node["minimum"]:
            errors.append(f"{path}: {data!r} is below minimum {node['minimum']!r}")

    if isinstance(data, dict):
        for key in node.get("required", []):
            if key not in data:
                errors.append(f"{path}.{key}: MISSING required field")
        properties = node.get("properties", {})
        if node.get("additionalProperties", True) is False:
            for key in data:
                if key not in properties:
                    errors.append(f"{path}.{key}: UNEXPECTED key (additionalProperties:false)")
        for key, child in properties.items():
            if key in data:
                _walk_schema(child, data[key], f"{path}.{key}", errors, root)

    if isinstance(data, list):
        if "minItems" in node and len(data) < node["minItems"]:
            errors.append(f"{path}: expected at least {node['minItems']} items")
        if "items" in node:
            for index, item in enumerate(data):
                _walk_schema(node["items"], item, f"{path}[{index}]", errors, root)


def _duplicate_values(values: list[Any]) -> list[Any]:
    seen: set[Any] = set()
    duplicates: list[Any] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def _cross_field_errors(document: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    identity_keys = ("date_utc", "regime", "scenario", "arm", "run_id", "build_id")
    if all(isinstance(document.get(key), str) for key in identity_keys):
        expected_directory = "_".join(document[key] for key in identity_keys)
        if document.get("artifact_directory") != expected_directory:
            errors.append(
                "$.artifact_directory: artifact_directory must equal "
                f"{expected_directory!r}"
            )

    specimens = document.get("specimens")
    specimen_by_id: dict[str, dict[str, Any]] = {}
    if isinstance(specimens, list):
        ids = [item.get("id") for item in specimens if isinstance(item, dict)]
        for duplicate in _duplicate_values(ids):
            errors.append(f"$.specimens: duplicate specimen id {duplicate!r}")
        specimen_by_id = {
            item["id"]: item
            for item in specimens
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        }
        present_kinds = {
            item.get("kind") for item in specimens if isinstance(item, dict)
        }
        for required_kind in ("executable", "dll", "mission_pbo", "config", "tool"):
            if required_kind not in present_kinds:
                errors.append(
                    f"$.specimens: missing required specimen kind: {required_kind}"
                )

    mission = document.get("mission")
    if isinstance(mission, dict):
        pbo_id = mission.get("mission_pbo_specimen_id")
        pbo = specimen_by_id.get(pbo_id)
        if pbo_id is not None and pbo is None:
            errors.append(
                f"$.mission.mission_pbo_specimen_id: unknown specimen {pbo_id!r}"
            )
        elif pbo is not None and pbo.get("kind") != "mission_pbo":
            errors.append(
                "$.mission.mission_pbo_specimen_id: referenced specimen is not mission_pbo"
            )

    topology = document.get("process_topology")
    hc_count = 0
    if isinstance(topology, list):
        roles = [item.get("role") for item in topology if isinstance(item, dict)]
        pids = [item.get("pid") for item in topology if isinstance(item, dict)]
        for duplicate in _duplicate_values(roles):
            errors.append(f"$.process_topology: duplicate process role {duplicate!r}")
        for duplicate in _duplicate_values(pids):
            errors.append(f"$.process_topology: duplicate PID {duplicate!r}")
        for index, process in enumerate(topology):
            if not isinstance(process, dict):
                continue
            role = process.get("role")
            if isinstance(role, str) and role.startswith("hc-"):
                hc_count += 1
            specimen_id = process.get("executable_specimen_id")
            specimen = specimen_by_id.get(specimen_id)
            if specimen_id is not None and specimen is None:
                errors.append(
                    f"$.process_topology[{index}].executable_specimen_id: "
                    f"unknown executable specimen {specimen_id!r}"
                )
            elif specimen is not None and specimen.get("kind") != "executable":
                errors.append(
                    f"$.process_topology[{index}].executable_specimen_id: "
                    "referenced specimen is not executable"
                )

    if isinstance(mission, dict) and isinstance(mission.get("expected_hcs"), int):
        if mission["expected_hcs"] != hc_count:
            errors.append(
                "$.mission.expected_hcs: expected_hcs does not match declared hc roles "
                f"({mission['expected_hcs']} != {hc_count})"
            )

    workload = document.get("workload")
    if isinstance(workload, dict):
        requested = workload.get("requested")
        if (
            isinstance(requested, dict)
            and isinstance(mission, dict)
            and requested.get("hcs") is not None
            and requested.get("hcs") != mission.get("expected_hcs")
        ):
            errors.append("$.workload.requested.hcs: must equal mission.expected_hcs")

    timing = document.get("timing")
    parsed_times: dict[str, datetime] = {}
    if isinstance(timing, dict):
        for key in ("start_utc", "warmup_end_utc", "end_utc"):
            value = timing.get(key)
            if isinstance(value, str):
                try:
                    parsed_times[key] = _parse_utc(value)
                except ValueError:
                    pass
        start = parsed_times.get("start_utc")
        warmup = parsed_times.get("warmup_end_utc")
        end = parsed_times.get("end_utc")
        if start is not None and warmup is not None and warmup < start:
            errors.append("$.timing.warmup_end_utc: must not be before start_utc")
        if start is not None and end is not None and end < start:
            errors.append("$.timing.end_utc: must not be before start_utc")
        if warmup is not None and end is not None and warmup > end:
            errors.append("$.timing.warmup_end_utc: warmup_end_utc must not be after end_utc")
        if start is not None and document.get("date_utc") != start.strftime("%Y%m%d"):
            errors.append("$.date_utc: must match timing.start_utc UTC date")

    created_value = document.get("created_utc")
    start = parsed_times.get("start_utc")
    if isinstance(created_value, str) and start is not None:
        try:
            if _parse_utc(created_value) > start:
                errors.append("$.created_utc: must not be after timing.start_utc")
        except ValueError:
            pass

    if isinstance(topology, list) and start is not None:
        for index, process in enumerate(topology):
            if not isinstance(process, dict) or not isinstance(process.get("start_utc"), str):
                continue
            try:
                if _parse_utc(process["start_utc"]) > start:
                    errors.append(
                        f"$.process_topology[{index}].start_utc: process starts after run"
                    )
            except ValueError:
                pass

    validation = document.get("validation")
    status = validation.get("status") if isinstance(validation, dict) else None
    invalid_reasons = (
        validation.get("invalid_reasons") if isinstance(validation, dict) else None
    )
    attained = workload.get("attained") if isinstance(workload, dict) else None
    end_value = timing.get("end_utc") if isinstance(timing, dict) else None

    if status == "pending":
        if end_value is not None:
            errors.append("$.timing.end_utc: pending manifest end_utc must be null")
        if invalid_reasons:
            errors.append("$.validation.invalid_reasons: pending manifest must have none")
        if isinstance(attained, dict):
            scalar_keys = (
                "label",
                "ai_total",
                "groups_total",
                "vehicles_total",
                "active_towns",
                "hcs",
                "players",
            )
            if any(attained.get(key) is not None for key in scalar_keys) or attained.get(
                "parameters"
            ):
                errors.append(
                    "$.workload.attained: pending manifest attained fields must be null"
                )
    elif status == "valid":
        if end_value is None:
            errors.append("$.timing.end_utc: valid manifest requires end_utc")
        if invalid_reasons:
            errors.append("$.validation.invalid_reasons: valid manifest must have no invalid_reasons")
        if not isinstance(attained, dict) or attained.get("label") is None:
            errors.append("$.workload.attained.label: valid manifest requires attained label")
        artifacts = document.get("artifacts")
        if isinstance(artifacts, list):
            for index, artifact in enumerate(artifacts):
                if (
                    isinstance(artifact, dict)
                    and artifact.get("required") is True
                    and artifact.get("sha256") is None
                ):
                    errors.append(
                        f"$.artifacts[{index}].sha256: required artifact must be hashed"
                    )
    elif status == "invalid":
        if end_value is None:
            errors.append("$.timing.end_utc: invalid manifest requires end_utc")
        if not invalid_reasons:
            errors.append(
                "$.validation.invalid_reasons: invalid manifest requires at least one reason"
            )

    artifacts = document.get("artifacts")
    if isinstance(artifacts, list):
        paths = [item.get("path") for item in artifacts if isinstance(item, dict)]
        for duplicate in _duplicate_values(paths):
            errors.append(f"$.artifacts: duplicate artifact path {duplicate!r}")

    return errors


def validate_document(
    document: dict[str, Any], schema: dict[str, Any] | None = None
) -> list[str]:
    active_schema = schema if schema is not None else load_schema()
    errors: list[str] = []
    _walk_schema(active_schema, document, "$", errors, active_schema)
    if isinstance(document, dict):
        errors.extend(_cross_field_errors(document))
    return errors


def _seal_path(manifest_path: Path) -> Path:
    return manifest_path.with_name(SEAL_NAME)


def _read_seal(path: Path) -> tuple[str | None, str | None]:
    if not path.exists():
        return None, None
    try:
        text = path.read_text(encoding="ascii").strip()
    except (OSError, UnicodeError) as exc:
        return None, f"cannot read seal: {exc}"
    match = re.fullmatch(r"([a-f0-9]{64})  MANIFEST\.json", text)
    if match is None:
        return None, "invalid MANIFEST.sha256 format"
    return match.group(1), None


def validate_file(
    manifest_path: str | os.PathLike[str],
    schema_path: str | os.PathLike[str] | None = None,
) -> tuple[int, list[str]]:
    path = Path(manifest_path)
    errors: list[str] = []
    try:
        raw = path.read_bytes()
    except OSError as exc:
        return 0, [f"{path}: cannot read manifest ({exc})"]

    seal, seal_error = _read_seal(_seal_path(path))
    if seal_error is not None:
        errors.append(f"{_seal_path(path)}: {seal_error}")
    elif seal is not None:
        actual = sha256_bytes(raw)
        if actual != seal:
            errors.append(
                f"{path}: seal mismatch (expected {seal}, actual {actual})"
            )

    try:
        document = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        return 0, errors + [f"{path}: invalid UTF-8 JSON ({exc})"]
    if not isinstance(document, dict):
        return 1, errors + ["$: manifest root must be an object"]

    try:
        schema = load_schema(schema_path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        return 1, errors + [f"schema: cannot load ({exc})"]
    errors.extend(validate_document(document, schema))
    return 1, errors


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(
        mode="wb", prefix=path.name + ".tmp-", dir=path.parent, delete=False
    )
    temp_path = Path(handle.name)
    try:
        with handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    except BaseException:
        try:
            temp_path.unlink(missing_ok=True)
        finally:
            raise


def finalize_manifest(
    manifest_path: str | os.PathLike[str],
    schema_path: str | os.PathLike[str] | None = None,
) -> str:
    path = Path(manifest_path)
    raw = path.read_bytes()
    seal_path = _seal_path(path)
    existing_seal, seal_error = _read_seal(seal_path)
    if seal_error is not None:
        raise ValueError(seal_error)
    if existing_seal is not None:
        actual = sha256_bytes(raw)
        if existing_seal != actual:
            raise ValueError("sealed manifest does not match MANIFEST.sha256")

    document = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(document, dict):
        raise ValueError("manifest root must be an object")
    errors = validate_document(document, load_schema(schema_path))
    if errors:
        raise ValueError("manifest is invalid:\n" + "\n".join(errors))
    if document.get("validation", {}).get("status") == "pending":
        raise ValueError("pending manifest cannot be finalized")

    if existing_seal is not None:
        return existing_seal

    canonical = canonical_bytes(document)
    digest = sha256_bytes(canonical)
    _atomic_write(path, canonical)
    _atomic_write(seal_path, f"{digest}  MANIFEST.json\n".encode("ascii"))
    return digest


def _self_test() -> int:
    fixtures = [
        HERE / "fixtures" / "valid-pending" / "MANIFEST.json",
        HERE / "fixtures" / "valid-final" / "MANIFEST.json",
    ]
    failed = False
    for fixture in fixtures:
        _, errors = validate_file(fixture)
        if errors:
            failed = True
            for error in errors:
                print(f"{fixture}: {error}", file=sys.stderr)
    if failed:
        return 1
    print(f"PASS: {len(fixtures)} manifest fixtures")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", help="path to MANIFEST.json")
    parser.add_argument("--schema", help="override schema path")
    parser.add_argument(
        "--finalize",
        action="store_true",
        help="canonicalize and seal a completed valid/invalid manifest",
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test()
    if args.manifest is None:
        parser.error("manifest is required unless --self-test is used")

    if args.finalize:
        try:
            digest = finalize_manifest(args.manifest, args.schema)
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            print(f"FAIL: {exc}", file=sys.stderr)
            return 1
        print(f"PASS: finalized {args.manifest} sha256={digest}")
        return 0

    count, errors = validate_file(args.manifest, args.schema)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {args.manifest} ({count} manifest)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
