# Generated Testmaps

_Status: active generated verification mapping surface_

This directory contains the current generated verification maps for specifications. Use this path when you need the active testmap for a spec.

## What this directory is for

- generated AC-to-verification mapping artifacts
- reader-facing verification snapshots derived from the current source of truth
- compatibility output for tools and reviewers that still consume YAML testmaps

## Source of truth

The generated files here are derived from:

- specification acceptance criteria under `specs/**`
- `@covers` annotations in tests and verification scripts
- `specs/plans/manual_verifications.yaml`

## Hard rules

- Do not hand-edit files here.
- Regenerate this directory through the supported tooling.
- Treat `specs/testmaps/**` as frozen legacy compatibility only.

## Legacy path

If you see a similarly named file under `specs/testmaps/**`, that is the frozen legacy compatibility path.

- Active generated output lives here: `specs/_generated/testmaps/**`
- Legacy compatibility remains there: `specs/testmaps/**`
