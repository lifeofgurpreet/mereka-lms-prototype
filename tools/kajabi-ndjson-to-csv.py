#!/usr/bin/env python3
"""
Convert Kajabi NDJSON dumps into CSVs for quick inspection.

Usage:
  python tools/kajabi-ndjson-to-csv.py \
      --ndjson-dir exports/kajabi \
      --csv-dir exports/kajabi/csv

Optional:
  --file contacts.ndjson   # convert only one file
"""

import argparse
import csv
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Kajabi NDJSON → CSV converter")
    parser.add_argument("--ndjson-dir", default="exports/kajabi", help="Directory with *.ndjson files")
    parser.add_argument("--csv-dir", default="exports/kajabi/csv", help="Directory to write CSV outputs")
    parser.add_argument("--file", action="append", help="Specific NDJSON file(s) to convert")
    return parser.parse_args()


def load_lines(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def flatten_record(record):
    # Handle submissions wrapper
    if "submission" in record and isinstance(record["submission"], dict):
        base = {"form_id": record.get("form_id")}
        submission = record["submission"]
        base.update(flatten_kajabi_record(submission))
        return base
    return flatten_kajabi_record(record)


def flatten_kajabi_record(record):
    row = {}
    if "id" in record:
        row["id"] = record.get("id")
    elif "data" in record and isinstance(record["data"], dict):
        row["id"] = record["data"].get("id")
    if "type" in record:
        row["type"] = record.get("type")
    elif "data" in record and isinstance(record["data"], dict):
        row["type"] = record["data"].get("type")

    attrs = record.get("attributes")
    if attrs is None and isinstance(record.get("data"), dict):
        attrs = record["data"].get("attributes")
    if isinstance(attrs, dict):
        for key, value in attrs.items():
            row[f"attr_{key}"] = value

    rels = record.get("relationships")
    if rels is None and isinstance(record.get("data"), dict):
        rels = record["data"].get("relationships")
    if rels is not None:
        row["relationships_json"] = json.dumps(rels, ensure_ascii=False)

    # copy any other primitive top-level keys to aid debugging
    for key, value in record.items():
        if key in {"attributes", "relationships", "data"}:
            continue
        if key in row:
            continue
        if isinstance(value, (str, int, float, bool)) or value is None:
            row[key] = value
    return row


def write_csv(rows, output_path: Path):
    if not rows:
        output_path.write_text("")
        return
    fieldnames = sorted({key for row in rows for key in row.keys()})
    with output_path.open("w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def convert_file(ndjson_path: Path, csv_path: Path):
    rows = [flatten_record(rec) for rec in load_lines(ndjson_path)]
    write_csv(rows, csv_path)
    print(f"{ndjson_path.name}: {len(rows)} records → {csv_path}")


def main():
    args = parse_args()
    ndjson_dir = Path(args.ndjson_dir)
    csv_dir = Path(args.csv_dir)
    csv_dir.mkdir(parents=True, exist_ok=True)

    if args.file:
        files = [Path(ndjson_dir, name) for name in args.file]
    else:
        files = sorted(ndjson_dir.glob("*.ndjson"))

    for ndjson_file in files:
        if not ndjson_file.exists():
            print(f"[skip] {ndjson_file} not found")
            continue
        csv_file = csv_dir / (ndjson_file.stem + ".csv")
        convert_file(ndjson_file, csv_file)


if __name__ == "__main__":
    main()
