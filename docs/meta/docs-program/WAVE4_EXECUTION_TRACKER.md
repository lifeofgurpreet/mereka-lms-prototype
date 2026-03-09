# Wave 4 Execution Tracker

## Current branch
- docs/wave4-unified-knowledge-control-plane

## Last completed batch
- commit: pending current packet HEAD
- scope: Wave 4 Packet D
- validators run:
  - python3 tools/knowledge/report_knowledge_control_plane.py --repo-root .
  - python3 tools/knowledge/build_knowledge_catalog.py --check --repo-root .
  - python3 tools/knowledge/build_knowledge_graph.py --check --repo-root .
  - python3 tools/knowledge/build_wrapper_retirement_ledger.py --repo-root .
  - python3 tools/knowledge/build_wrapper_retirement_ledger.py --check --repo-root .
  - python3 tools/specs/report_spec_metadata_coverage.py --repo-root .
  - python3 tools/specs/verify_spec_frontmatter.py --repo-root .
  - python3 tools/specs/verify_spec_taxonomy.py --repo-root .
  - python3 tools/specs/verify_spec_paths.py --repo-root .
  - python3 tools/specs/verify_docs_specs_boundary.py --repo-root .
  - python3 scripts/qa/spec-tools/build_spec_catalog.py --check --repo-root .
  - python3 tools/docs/verify/build-doc-catalog.py --root . --check
  - bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
  - python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
- result: complete

## Current target batch
- files:
  - docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md
  - tools/knowledge/build_wrapper_retirement_ledger.py
  - docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md
- goal:
  - inventory all compatibility wrappers
  - record canonical targets and non-generated live references
  - distinguish retain vs retire-candidate wrappers
- stop condition:
  - validators pass and one commit is created

## Decisions already locked
- Wave 3 stays frozen on its review branch
- docs/ and specs/ remain physically separate lanes
- Kajabi/MCT remains normative until a new contradiction appears

## Open residue
- wrapper retirement ledger not started yet
- merge-time governance is not started yet

## Next queued batch
- Packet E: merge-time governance
