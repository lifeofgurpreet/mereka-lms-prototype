# Documentation Style Guide
_Audience: Everyone • Owner: Infra Team • Last verified: 2025-11-09_

Use this checklist whenever you create or update docs in this repository. Consistency keeps the team fast.

## 1. Location

- **Quick start / Daily workflow:** `docs/quickstart/`
- **Operations / Infra / Secrets:** `docs/ops/`
- **Migrations:** `docs/migrations/<domain>/`
- **Analytics / Reporting:** `docs/analytics/`
- **Integrations (OAuth, SSO, etc.):** `docs/integrations/`
- Add a `README.md` to any new subfolder that aggregates the docs living there.

## 2. Metadata Block

Every doc should start with a metadata line:

```
_Audience: <role> • Owner: <team/driver> • Last verified: YYYY‑MM‑DD_
```

- **Audience** – who should read it (e.g., “Platform Eng”, “Data/Analytics”, “Everyone”).
- **Owner** – the team or person accountable for updates.
- **Last verified** – when the doc was last checked against reality.

## 3. Structure

1. **Purpose statement** (1–2 sentences).
2. **Prerequisites** (if any).
3. **Procedure** broken into numbered steps or sections.
4. **Troubleshooting / FAQs** for known issues.
5. **Related links** back to the docs index or companion guides.

## 4. Cross-linking

- Link relative to `docs/` (e.g., `[Quickstart](quickstart/WORKFLOW_LOCAL.md)`).
- When referencing scripts/tools, link to their repo path (`scripts/migrations/kajabi/scripts/...`).
- Update `docs/README.md` whenever you add, remove, or substantially change a doc.

## 5. Verification Workflow

1. After testing a procedure, update the “Last verified” date.
2. If a doc becomes stale, add a warning banner and open an issue/task to refresh it.
3. For production-impacting docs (deployments, migrations), capture the Tutor version or release in the metadata if it matters.

## 6. Naming Conventions

- Use uppercase with underscores for multi-word filenames (`KAJABI_MIGRATION.md`).
- Keep filenames scoped to their folder (e.g., `SETUP.md` inside `docs/integrations/oauth/` is ambiguous—prefer `GOOGLE_OAUTH_SETUP.md`).

Following this guide means anyone on the team can find accurate information in seconds. When in doubt, ask in the workflow doc or open a PR to refine the style guide.
