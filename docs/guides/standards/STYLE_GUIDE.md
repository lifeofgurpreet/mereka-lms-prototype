# Documentation Style Guide
_Audience: Everyone • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this checklist when writing or editing docs in this repository. This guide is for style, naming, and practical writing quality. Use the documentation authority resolver for root ownership.

## 1. Choose the right root

- `docs/guides/**` for human workflows and onboarding
- `docs/ops/**` for operator procedures and quick references
- `docs/concepts/architecture/**` for living architecture narratives and standards
- `docs/reference/**` for factual reference
- `docs/policies/**` for boundary rules and policy
- `docs/evidence/**` for active proof
- `docs/status/**` for active reporting
- `docs/adr/**` for decisions and proposals

Do not create new canonical docs under transitional roots such as `docs/operations/**` or `docs/runbooks/**`.

## 2. Metadata block

Every canonical doc should start with a metadata line:

```markdown
_Audience: <role> • Owner: <team/driver> • Last verified: YYYY-MM-DD • Status: canonical_
```

## 3. Keep structure obvious

Most docs should let a reader find the key answer in the first screenful.

Default pattern:
1. Purpose
2. Scope or prerequisites
3. Main content
4. Verification, troubleshooting, or related links

Use a different structure only when the artifact type clearly requires it.

## 4. Write for scanning

- Start sections with the most important fact.
- Prefer bullets and short paragraphs over dense prose.
- Use numbered lists for procedures.
- Use headings that describe the question being answered.
- Link to the canonical source rather than restating whole sections from another doc.

## 5. Formatting rules

- Use inline code for commands, paths, URLs, variables, services, and identifiers.
- Use fenced code blocks with a language tag for multi-line examples.
- Keep filenames descriptive and scoped to their folder.
- Prefer semantic names over generic names like `SETUP.md` when ambiguity is likely.

## 6. Cross-linking rules

- Link relative to the current doc.
- Update the nearest canonical `README.md` when discoverability changes.
- Update `docs/README.md` when the front door or hot-path reading sequence changes.

## 7. What gets rejected

- A correct doc in the wrong root.
- Missing metadata on a canonical doc.
- Links that send readers into superseded roots without an explicit legacy reason.
- New docs that are not reachable from a relevant canonical index.
- Docs that should really be specs.

## 8. Minimal checks

```bash
bash tools/docs/verify/verify-docs-policy.sh --range HEAD~1...HEAD
python3 tools/docs/verify/verify-doc-catalog-governance.py --range HEAD~1...HEAD
```

Following this guide means readers can find the right document quickly and trust that it lives where the repository says truth lives.
