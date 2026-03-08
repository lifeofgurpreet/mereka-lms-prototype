# Copy/Terminology Consistency Contract

**Purpose**: Define canonical product names, banned strings, and verification scope for user-facing copy in Mereka Academy.

**Status**: Active
**Last verified**: 2026-02-17
**Acceptance Criteria**: AC-UICOPY-001, AC-UICOPY-002, AC-UICOPY-003

---

## Overview

This contract ensures consistent branding and terminology across all user-facing surfaces of Mereka Academy. It defines:

1. **Canonical Product Names** — Approved brand names and where each is used
2. **Banned Strings** — Strings that must NOT appear in user-facing templates
3. **Scope** — Which files are scanned for copy consistency
4. **Multi-Domain Strategy** — How different domains map to brand names
5. **Verification** — Machine-checkable tests to enforce the contract

---

## Canonical Product Names (AC-UICOPY-002)

### Primary Brands

| Brand Name | Domain | Usage Context |
|------------|--------|---------------|
| **Mereka Academy** | academyv2.mereka.io | Primary brand, default LMS/CMS/MFE |
| **Biji-Biji Academy** | academy.biji-biji.com | Secondary brand, Biji-Biji Initiative community |
| **Skill Our Future Academy** | skillourfuture.academy.mereka.io | Tertiary brand, workforce development programs |

### Configuration Mapping

| Setting | Expected Value | Location |
|---------|---------------|----------|
| `PLATFORM_NAME` | "Mereka Academy" (or variant) | `tutor config.yml` |
| `SITE_NAME` | Domain-specific | Multi-tenancy middleware |
| `LMS_DEFAULT_SITE_THEME` | "mereka" | `tutor config.yml` |

**Multi-Domain Logic**:
- `PLATFORM_NAME` should contain "Academy" (e.g., "Mereka Academy", "Biji-Biji Academy")
- `SITE_NAME` can be empty (defaults to `PLATFORM_NAME`) or domain-specific
- Multi-tenancy plugin dynamically switches branding based on request domain

---

## Banned Strings (AC-UICOPY-001)

### User-Facing Violations

These strings are **prohibited** in user-facing templates, SCSS, and JS/JSX:

| Banned String | Reason | Known Gap |
|---------------|--------|-----------|
| `"Powered by Open edX"` | Default Open edX branding | `footer.html:71` (documented) |
| `"Powered by Tutor"` | Default Tutor branding | None |
| `"Open edX"` (standalone, user-visible) | Generic platform name | Allowed in docs/comments |
| `"edX"` (standalone) | Parent brand, not ours | Allowed in docs/comments |
| `"Your Platform Name Here"` | Template placeholder | None |
| `"Example University"` | Template placeholder | None |

**Exceptions**:
- **Documentation** (`.md` files) — Open edX references are allowed
- **Code comments** (lines starting with `#`, `//`, `{#`, `<!-- -->`) — Technical references allowed
- **Backend code** — Python modules and configs are exempt (only templates/SCSS/JS scanned)
- **Test/fixture files** — Mock data is excluded from checks

### Current Known Gaps

| Gap | Location | Status | Notes |
|-----|----------|--------|-------|
| `"Powered by Open edX and Tutor"` | `infrastructure/tutor/themes/mereka/lms/templates/footer.html:71` | **WARN** | Documented technical debt; removing requires footer redesign |

**Resolution Plan**: Footer redesign in Q2 2026 (bead tracked separately).

---

## Scope (AC-UICOPY-001)

### Included Files

Verification scans the following for banned strings:

```
infrastructure/tutor/themes/
├── mereka/lms/templates/       # Mako templates (*.html)
│   └── footer.html             # Known gap: "Powered by Open edX and Tutor"
├── mereka/cms/templates/       # Studio templates
└── mereka/scss/                # LMS/CMS SCSS (*.scss)

infrastructure/tutor/custom-apps/
├── */templates/                # Custom app templates (*.html)
└── */static/                   # Custom app SCSS/JS (*.scss, *.js, *.jsx)
```

**File Types Scanned**:
- Templates: `*.html` (Mako/Jinja2)
- Stylesheets: `*.scss`
- JavaScript: `*.js`, `*.jsx` (only in `themes/` and `custom-apps/`)

### Excluded Files

The following are **NOT** scanned:

```
docs/                           # Documentation (*.md, *.txt, *.rst)
scripts/                        # Automation scripts
deploy/                         # K8s manifests
specs/                          # Specifications
*.py                            # Python backend code
*/tests/                        # Test files
*/fixtures/                     # Mock data
```

**Comment Exclusion**:
- Mako comments: `{# ... #}`, `## ...`
- HTML comments: `<!-- ... -->`
- JS/SCSS comments: `// ...`, `/* ... */`
- Python comments: `# ...`

Lines containing these comment markers are **excluded** from banned string checks.

---

## Multi-Domain Brand Mapping (AC-UICOPY-003)

### Domain → Brand Strategy

Mereka Academy supports **three branded domains** with unique copy per domain:

| Domain | Brand Name | Footer Variant | Logo | Color Theme |
|--------|-----------|----------------|------|-------------|
| `academyv2.mereka.io` | Mereka Academy | Default (teal/magenta) | `logo.png` | `--mereka-teal` primary |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji variant | `biji-biji-logo.png` | `--biji-blue` primary |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | SOF variant | `sof-logo.png` | `--sof-green` primary |

**Implementation**:
- Multi-tenancy middleware (`infrastructure/tutor/plugins/multi-tenancy/`) detects request domain
- `SITE_NAME` overridden dynamically per request
- MFE footer component reads `SITE_NAME` from `env.config.jsx` and renders appropriate variant
- See `docs/runbooks/architecture/FOOTER_SLOT_MIGRATION.md` for footer slot wiring

**Config Requirements**:
- All domains must have `PLATFORM_NAME` containing "Academy"
- Each domain must have unique `SITE_NAME` in multi-tenancy plugin config
- Footer variants must be registered in `MerekaFooter v2` component

---

## Verification Script

### Script Location

```
scripts/qa/verify-copy-terminology.sh
```

### Checks Performed

| Check | Type | Acceptance Criteria |
|-------|------|---------------------|
| Contract document exists | FAIL if missing | AC-UICOPY-001 |
| Required sections present | FAIL if missing | AC-UICOPY-001 |
| Scan templates for banned strings | FAIL if found | AC-UICOPY-001 |
| Scan SCSS for banned strings | FAIL if found | AC-UICOPY-001 |
| `footer.html` "Powered by" string | **WARN** (known gap) | AC-UICOPY-001 |
| `PLATFORM_NAME` contains "Mereka" or variant | WARN if missing | AC-UICOPY-002 |
| `SITE_NAME` config exists | WARN if missing | AC-UICOPY-002 |
| No template placeholders | FAIL if found | AC-UICOPY-001 |

**CI Integration**:
- Script syntax checked in `.github/workflows/ci.yml` (`monitoring-guardrails` job)
- Run locally: `./scripts/qa/verify-copy-terminology.sh`

---

## Acceptance Criteria

### AC-UICOPY-001: Banned String Gate

**Requirement**: No banned strings (except known gaps) in user-facing templates.

**Verification**:
```bash
./scripts/qa/verify-copy-terminology.sh
# Expected: 0 FAIL (WARN for footer.html known gap is acceptable)
```

**Covered Files**:
- `infrastructure/tutor/themes/mereka/lms/templates/*.html`
- `infrastructure/tutor/themes/mereka/cms/templates/*.html`
- `infrastructure/tutor/themes/mereka/scss/*.scss`
- `infrastructure/tutor/custom-apps/*/templates/*.html`
- `infrastructure/tutor/custom-apps/*/static/*.scss`

**Excludes**: Documentation, Python code, comments, test files.

---

### AC-UICOPY-002: Canonical Term Verification

**Requirement**: Platform name configuration uses canonical brand terms.

**Verification**:
```bash
# Check PLATFORM_NAME in plugin settings
grep -r "PLATFORM_NAME" infrastructure/tutor/plugins/mereka_lms.py
# Expected: "Mereka Academy" or domain-specific variant

# Check SITE_NAME configuration exists
grep -r "SITE_NAME" infrastructure/tutor/plugins/multi-tenancy/
# Expected: domain-to-brand mappings present
```

**Contract Check**:
- `verify-copy-terminology.sh` checks that `PLATFORM_NAME` config references "Mereka" or "Academy"
- WARN if `PLATFORM_NAME` is missing or generic

---

### AC-UICOPY-003: Multi-Domain Brand Mapping

**Requirement**: Three domains have unique brand names and footer variants.

**Verification**:
```bash
# Check multi-tenancy middleware configuration
grep -A 10 "domain_mappings" infrastructure/tutor/plugins/multi-tenancy/middleware.py
# Expected: academyv2.mereka.io, academy.biji-biji.com, skillourfuture

# Check MFE footer variants
grep -A 5 "FOOTER_VARIANT" infrastructure/tutor/plugins/mereka_lms.py
# Expected: 3 footer variants defined
```

**Contract Check**:
- `verify-copy-terminology.sh` verifies multi-domain config exists
- WARN if fewer than 3 domains mapped

---

## Maintenance

### When to Update This Contract

1. **New brand domain added** → Update domain mapping table, add footer variant
2. **New banned string discovered** → Add to banned strings table
3. **Scope changes** (new file type scanned) → Update "Scope" section
4. **Known gap resolved** → Remove from "Known Gaps" table

### Review Cadence

- **Quarterly**: Review banned strings list for new template placeholders
- **Per-release**: Verify all domains still mapped in multi-tenancy config
- **After theme changes**: Re-run `verify-copy-terminology.sh` to catch regressions

---

## Related Documentation

- **MFE Footer v2 Design**: `docs/runbooks/architecture/FOOTER_SLOT_MIGRATION.md` — Footer variant mapping
- **Tenant Branding Contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` — Brand pack schema
- **Frontend Audit Checklist**: `../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md` — Copy/Terminology section
- **Branding System Spec**: `specs/branding-system_spec.md` — Branding requirements

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-17 | Initial contract (bead 15lf) |
