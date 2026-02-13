# Agent Spec System Rules

These are non-negotiable rules for all AI agents working with specs in this repository.

## 7 Non-Negotiable Rules

1. **Specs are contracts, not documentation.** Every spec defines machine-checkable acceptance criteria. If you can't write a test for it, it doesn't belong in a spec.

2. **Never create a spec without frontmatter.** Every spec MUST have YAML frontmatter with at least: title, type, status, owner, vehicle, last_updated. Use `specs/_TEMPLATE.md`.

3. **Every AC gets a testmap entry.** When you add an AC, it must appear in the corresponding `specs/testmaps/{spec_name}.testmap.yml`. Use `make generate-testmaps` to regenerate.

4. **Cross-cutting requirements are inherited, not duplicated.** Reference `specs/cross-cutting-requirements_spec.md` in related_specs. Only specify domain-specific overrides.

5. **Use @covers annotations in all verification scripts.** Every script that verifies an AC must have `# @covers AC-XXX` and `# @spec: {spec_name}` annotations.

6. **Run lint before submitting.** `make lint-specs` must pass with zero errors. Warnings are acceptable during development but should be resolved before merge.

7. **Never edit generated testmaps by hand.** Testmaps are generated from @covers annotations. Edit the verification scripts, then `make generate-testmaps`.
