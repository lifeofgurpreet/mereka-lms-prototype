## Summary

- What changed:
- Why:
- Owner layer: <!-- source | build/render | promotion | realization | runtime | proof -->

## Authority routing

- Governed scope tokens:
- Source of truth file(s) changed:
- Generated artifact(s) that must be checked:
- Canonical roots touched:
- Transitional roots touched:
- Archive roots touched:

## Documentation control-plane checklist

- [ ] I used the winning root for each artifact kind.
- [ ] I did not introduce new canonical content under transitional roots.
- [ ] I updated or added superseded stubs where paths moved.
- [ ] I regenerated derived artifacts instead of hand-editing them.
- [ ] If I changed winning-root docs, I updated `generated/catalogs/docs-catalog.json` in the same diff.
- [ ] I reviewed `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`.
- [ ] I reviewed `docs/guides/standards/DOCS_SPECS_CONTRACT.md` if specs or testmaps changed.

## Specs / verification

- Specs touched:
- Generated testmaps regenerated:
- Manual verification metadata touched:

## Change safety

- [ ] I patched the generator/source, not just the generated artifact
- [ ] Rendered/build artifact reflects my change (verified, not assumed)
- [ ] If runtime change: proof plan defined (route proof → asset verify → browser canary)
- [ ] If promotion: release object used (no manual SHA join)
- [ ] Rollback plan: <!-- how to revert if this breaks -->

## Validation

- [ ] `tools/docs/verify/verify-docs-policy.sh`
- [ ] `python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .`
- [ ] `scripts/qa/verify-docs-authority-invariants.sh`
- [ ] other relevant checks:

## Compatibility / migration notes

- Stubs added or updated:
- Legacy paths intentionally retained:
- Follow-up cleanup still needed:
