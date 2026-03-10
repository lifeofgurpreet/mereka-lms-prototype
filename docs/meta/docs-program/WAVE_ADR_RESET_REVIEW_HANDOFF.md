# Wave ADR Reset Review Handoff

## Review focus

Review this wave as an ADR-ledger reset, not as a broad docs rewrite.

Questions to verify:
- Does `docs/adr/` root now contain only current accepted ADRs?
- Are historical and RFC files clearly separated from the root hot path?
- Do moved program/governance docs now live in more appropriate homes?
- Is ADR frontmatter now the authored source of truth?
- Are `README.md` and `_generated/*` projections reproducible from file metadata?

## Read-first review order

1. `docs/adr/README.md`
2. `docs/adr/_generated/hot-path.md`
3. `docs/meta/docs-program/WAVE_ADR_RESET_TRACKER.md`
4. `docs/meta/docs-program/WAVE_ADR_RESET_CLOSEOUT.md`
5. `docs/adr/rfc/README.md`

## High-signal diffs

- root accepted ADR surface trimmed to 14 files
- historical ADRs moved out of root
- RFC queue normalized under `docs/adr/rfc/`
- non-ADR files moved out of ADR space
- frontmatter-driven ADR generation and verification added

## Validation commands

```bash
python3 tools/docs/build_adr_ledger.py --check
python3 tools/docs/verify/verify_adr_frontmatter.py --repo-root .
python3 tools/docs/verify/verify_adr_ledger_integrity.py --repo-root .
python3 tools/docs/verify/verify_adr_hot_path.py
python3 tools/docs/verify/build-doc-catalog.py --root . --check
bash scripts/qa/run-adr-gates.sh
```
