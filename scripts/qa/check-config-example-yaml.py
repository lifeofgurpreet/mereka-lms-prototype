#!/usr/bin/env python3
"""Validate that infrastructure/tutor/config.example.yml is valid YAML."""
import sys

import yaml

with open("infrastructure/tutor/config.example.yml") as f:
    config = yaml.safe_load(f)
    if not config:
        print("FAIL: config.example.yml is empty or null")
        sys.exit(1)
    print(f"OK: Config has {len(config)} top-level keys")
