#!/usr/bin/env python3
"""Summarize the opt-in CLIENTFRAME|v1| Arma 2 OA telemetry stream."""

from __future__ import print_function

import argparse
import datetime
import json
import math
import os
import re
import sys


SCHEMA = "wasp-client-frame-telemetry-v1"
TIMESTAMP_RE = re.compile(r"^\s*(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}|\d{2}:\d{2}:\d{2})")


def as_float(value, default=None):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def as_int(value, default=0):
    number = as_float(value)
    if number is None:
        return default
    return int(number)


def percentile(values, percent):
    ordered = sorted(values)
    if not ordered:
        return None
    if len(ordered) == 1:
        return round(ordered[0], 3)
    rank = (percent / 100.0) * (len(ordered) - 1)
    lower = int(math.floor(rank))
    upper = int(math.ceil(rank))
    if lower == upper:
        return round(ordered[lower], 3)
    weight = rank - lower
    return round((ordered[lower] * (1.0 - weight)) + (ordered[upper] * weight), 3)


def parse_timestamp(line):
    match = TIMESTAMP_RE.search(line)
    if not match:
        return None
    value = match.group(1)
    try:
        if len(value) == 8:
            return datetime.datetime.combine(
                datetime.date.today(), datetime.datetime.strptime(value, "%H:%M:%S").time()
            )
        return datetime.datetime.strptime(value.replace("T", " "), "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def parse_frame_line(line):
    marker = "CLIENTFRAME|v1|"
    if marker not in line:
        return None
    payload = line.split(marker, 1)[1].strip()
    fields = {}
    for part in payload.split("|"):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value

    frame_values = []
    for value in fields.get("frameMs", "").split(","):
        number = as_float(value.strip())
        if number is not None and number > 0:
            frame_values.append(number)
    if not frame_values:
        return None
    return {
        "fields": fields,
        "frames": frame_values,
        "timestamp": parse_timestamp(line),
        "raw": line.rstrip("\r\n"),
    }


def read_telemetry(path):
    rows = []
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            row = parse_frame_line(line)
            if row is not None:
                rows.append(row)
    return rows


def parse_runtime_timestamp(value):
    if not value:
        return None
    text = str(value).replace("Z", "")
    for pattern in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.datetime.strptime(text, pattern)
        except ValueError:
            continue
    return None


def read_runtime(path):
    if not path:
        return []
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read().strip()
    if not text:
        return []
    if text.startswith("["):
        values = json.loads(text)
    else:
        values = [json.loads(line) for line in text.splitlines() if line.strip()]
    for value in values:
        value["_timestamp"] = parse_runtime_timestamp(value.get("wallTime"))
    return values


def correlate_runtime(rows, runtime, max_gap_seconds):
    if not runtime:
        return {"status": "not_provided", "samples": 0}
    normalized_runtime = []
    for item in runtime:
        value = dict(item)
        if "_timestamp" not in value:
            value["_timestamp"] = parse_runtime_timestamp(value.get("wallTime"))
        normalized_runtime.append(value)
    pairs = []
    for row in rows:
        if row["timestamp"] is None:
            continue
        candidates = [
            item for item in normalized_runtime
            if item.get("_timestamp") is not None
        ]
        if not candidates:
            continue
        nearest = min(candidates, key=lambda item: abs((item["_timestamp"] - row["timestamp"]).total_seconds()))
        gap = abs((nearest["_timestamp"] - row["timestamp"]).total_seconds())
        if gap <= max_gap_seconds:
            pairs.append(nearest)
    cpu = [as_float(item.get("processCpuPct")) for item in pairs]
    cpu = [value for value in cpu if value is not None]
    working_set = [as_float(item.get("workingSetMb")) for item in pairs]
    working_set = [value for value in working_set if value is not None]
    tiers = [str(item.get("hardwareTier")) for item in pairs if item.get("hardwareTier")]
    tier = None
    if tiers:
        tier = max(set(tiers), key=tiers.count)
    return {
        "status": "matched" if pairs else "unavailable_no_timestamp_match",
        "samples": len(pairs),
        "hardwareTier": tier,
        "processCpuPctAvg": round(sum(cpu) / len(cpu), 3) if cpu else None,
        "processCpuPctP95": percentile(cpu, 95),
        "workingSetMbAvg": round(sum(working_set) / len(working_set), 3) if working_set else None,
        "workingSetMbP95": percentile(working_set, 95),
    }


def summarize(rows, runtime=None, max_gap_seconds=30):
    frames = [frame for row in rows for frame in row["frames"]]
    fps = [1000.0 / frame for frame in frames]
    weighted = float(len(frames)) or 1.0

    def weighted_context(field):
        values = []
        for row in rows:
            value = as_float(row["fields"].get(field))
            if value is not None:
                values.extend([value] * len(row["frames"]))
        return round(sum(values) / len(values), 3) if values else None

    first = rows[0]["fields"] if rows else {}
    last = rows[-1]["fields"] if rows else {}
    p99_frame = percentile(frames, 99)
    return {
        "schema": SCHEMA,
        "status": "baseline_ready" if rows else "no_data",
        "sessionId": first.get("sid"),
        "map": last.get("map"),
        "reports": len(rows),
        "frameSamples": len(frames),
        "frameTimeMs": {
            "p50": percentile(frames, 50),
            "p95": percentile(frames, 95),
            "p99": p99_frame,
            "max": max(frames) if frames else None,
        },
        "fps": {
            "average": round(sum(fps) / weighted, 3) if frames else None,
            "p50": percentile(fps, 50),
            "p01LowProxy": round(1000.0 / p99_frame, 3) if p99_frame else None,
            "min": min(fps) if fps else None,
        },
        "longFrames": {
            "over50ms": sum(1 for frame in frames if frame >= 50.0),
            "over100ms": sum(1 for frame in frames if frame >= 100.0),
            "rateOver50ms": round(sum(1 for frame in frames if frame >= 50.0) / weighted, 6) if frames else None,
        },
        "state": {
            "mapOpenPct": weighted_context("mapOpenPct"),
            "gpsOpenPct": weighted_context("gpsOpenPct"),
            "dialogOpenPct": weighted_context("dialogOpenPct"),
        },
        "contextLast": {
            "players": as_int(last.get("players"), None),
            "ai": as_int(last.get("ai"), None),
            "units": as_int(last.get("units"), None),
            "vehicles": as_int(last.get("vehicles"), None),
            "markers": as_int(last.get("markers"), None),
            "aarMarkers": as_int(last.get("aarMarkers"), None),
            "viewDistance": as_float(last.get("vd")),
            "profileViewDistance": as_float(last.get("pvd")),
            "terrainGrid": as_float(last.get("terrainGrid")),
        },
        "timeToPlayableSec": as_float(first.get("ttPlayable")),
        "runtimeCorrelation": correlate_runtime(rows, runtime or [], max_gap_seconds),
    }


def write_report(path, summary, input_path, runtime_path):
    lines = [
        "# Client frame telemetry baseline",
        "",
        "- Schema: `{}`".format(summary["schema"]),
        "- Status: `{}`".format(summary["status"]),
        "- Input: `{}`".format(input_path),
        "- Runtime sidecar: `{}`".format(runtime_path or "not provided"),
        "",
        "## Frame pacing",
        "",
        "| Metric | Value |",
        "|---|---:|",
        "| Frame-time p50 (ms) | {} |".format(summary["frameTimeMs"]["p50"]),
        "| Frame-time p95 (ms) | {} |".format(summary["frameTimeMs"]["p95"]),
        "| Frame-time p99 (ms) | {} |".format(summary["frameTimeMs"]["p99"]),
        "| Long frames >=50 ms | {} |".format(summary["longFrames"]["over50ms"]),
        "| Long frames >=100 ms | {} |".format(summary["longFrames"]["over100ms"]),
        "| FPS average | {} |".format(summary["fps"]["average"]),
        "| FPS 1-percent-low proxy | {} |".format(summary["fps"]["p01LowProxy"]),
        "",
        "## Interpretation",
        "",
        "Frame time is an inverse-`diag_fps` proxy sampled by a low-frequency scheduled SQF loop; it is not a per-render-present timestamp. The 1-percent-low proxy is `1000 / p99(frameMs)`. Compare sessions with the same map, player/AI load, view settings, and hardware tier.",
        "",
        "Runtime CPU/working-set values are matched only when the RPT has wall-clock timestamps and the sidecar has a nearby `wallTime`; otherwise the report deliberately says unavailable rather than implying correlation.",
    ]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Arma RPT containing CLIENTFRAME|v1| lines")
    parser.add_argument("--output", required=True, help="JSON summary path")
    parser.add_argument("--runtime", help="optional JSON/JSONL runtime sidecar")
    parser.add_argument("--max-runtime-gap-sec", type=float, default=30.0)
    parser.add_argument("--report", help="optional Markdown report path")
    args = parser.parse_args(argv)

    rows = read_telemetry(args.input)
    runtime = read_runtime(args.runtime)
    summary = summarize(rows, runtime, args.max_runtime_gap_sec)
    summary["source"] = {"input": os.path.abspath(args.input), "runtime": os.path.abspath(args.runtime) if args.runtime else None}
    output_parent = os.path.dirname(os.path.abspath(args.output))
    if output_parent:
        os.makedirs(output_parent, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)
        handle.write("\n")
    report_path = args.report or os.path.splitext(args.output)[0] + ".md"
    write_report(report_path, summary, args.input, args.runtime)
    print("reports={} frameSamples={} p95_ms={} p99_ms={}".format(
        summary["reports"], summary["frameSamples"], summary["frameTimeMs"]["p95"], summary["frameTimeMs"]["p99"]
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
