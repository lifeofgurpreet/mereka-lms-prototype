# Doc Delivery Checklist

> Verify before publishing documentation.

## Structure
- [ ] Correct doc type chosen (ADR, Runbook, Onboarding, Architecture, Migration, Quickref)
- [ ] File placed in correct `docs/` subdirectory
- [ ] Filename uses kebab-case slug

## Content Quality
- [ ] Written for target audience (not too technical for stakeholders, not too vague for operators)
- [ ] Concrete examples included (copy-pasteable commands, real file paths)
- [ ] No placeholder text remaining
- [ ] Links to related specs are valid

## ADR-Specific
- [ ] Status field present (proposed/accepted/deprecated/superseded)
- [ ] Context explains the problem clearly
- [ ] Decision is stated unambiguously
- [ ] Consequences list positive AND negative outcomes

## Runbook-Specific
- [ ] "When to Use" trigger conditions defined
- [ ] Prerequisites listed (access, tools, context)
- [ ] Steps are numbered and verifiable
- [ ] Rollback procedure included
- [ ] Escalation path defined

## Final
- [ ] No broken links
- [ ] No hardcoded secrets or credentials
- [ ] Spell-checked
