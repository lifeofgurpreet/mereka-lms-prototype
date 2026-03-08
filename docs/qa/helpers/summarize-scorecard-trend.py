#!/usr/bin/env python3
"""Append docs scorecard trend summary to GitHub step summary."""
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    trend = json.load(fp)

with open(sys.argv[2], "a", encoding="utf-8") as fp:
    fp.write("### Docs Scorecard Trend\n")
    fp.write(f"- base_ref={trend['base_ref']}\n")
    fp.write(f"- base_score={trend['base_score']}\n")
    fp.write(f"- current_score={trend['current_score']}\n")
    fp.write(f"- score_drop={trend['score_drop']}\n")
    fp.write(f"- max_allowed_drop={trend['max_allowed_drop']}\n")
    fp.write(f"- status={trend['status']}\n")
