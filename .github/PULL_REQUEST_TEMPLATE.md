## Summary

- What changed:
- Why:

## Authority routing

- Governed scope tokens:
- Canonical roots touched:
- Transitional roots touched:
- Archive roots touched:

## Documentation control-plane checklist

- [ ] I used the winning root for each artifact kind.
- [ ] I did not introduce new canonical content under transitional roots.
- [ ] I updated or added superseded stubs where paths moved.
- [ ] I regenerated derived artifacts instead of hand-editing them.
- [ ] I reviewed `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`.
- [ ] I reviewed `docs/guides/standards/DOCS_SPECS_CONTRACT.md` if specs or testmaps changed.

## Specs / verification

- Specs touched:
- Generated testmaps regenerated:
- Manual verification metadata touched:

## Validation

- [ ] `tools/docs/verify/verify-docs-policy.sh`
- [ ] `python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .`
- [ ] other relevant checks:

## Compatibility / migration notes

- Stubs added or updated:
- Legacy paths intentionally retained:
- Follow-up cleanup still needed:
