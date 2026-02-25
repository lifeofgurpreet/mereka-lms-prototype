# Translation Workflow

OEP-58 aligned translation workflow for Mereka Academy Open edX deployment.

## Supported Locales

| Code | Language | Role |
|------|----------|------|
| `en` | English | Primary (source) |
| `id` | Indonesian | Required ≥ 80% coverage |
| `zh_CN` | Chinese (Simplified) | Required ≥ 80% coverage |
| `vi` | Vietnamese | Required ≥ 80% coverage |
| `fil` | Filipino | Required ≥ 80% coverage |

## Atlas Pull Workflow (OEP-58)

```bash
# Install openedx-atlas
pip install openedx-atlas

# Export Transifex token
export TRANSIFEX_TOKEN=<your_token>

# Pull all locales (platform + MFE)
./scripts/infra/sync-translations.sh

# Dry-run (no network writes)
./scripts/infra/sync-translations.sh --dry-run

# Verify coverage after pull
./scripts/qa/verify-translations.sh --offline
```

## atlas.yml

`atlas.yml` at the repo root configures locale targets and output paths.
Edit `locales:` to add or remove locale support.

## Adding a New Locale

1. Add the locale code to `atlas.yml` under `locales:`
2. Add it to `TARGET_LANGS` in `scripts/infra/sync-translations.sh`
3. Add it to `TARGET_LANGS` in `scripts/qa/verify-translations.sh`
4. Pull translations: `./scripts/infra/sync-translations.sh`
5. Verify coverage: `./scripts/qa/verify-translations.sh --offline`

## Coverage Requirements

- All non-English locales must reach **≥ 80%** key coverage vs `en`
- Platform `.po` files must be present for each supported locale
- MFE `messages.json` files must be present for each supported locale
- Coverage is enforced by CI (`translation-check` workflow, weekly + on PR)

## CI Validation

Translation files are validated on every PR touching locale paths and weekly on Mondays.

The CI job (`translation-check.yml`) runs `verify-translations.sh --offline` which checks:
- Locale directory structure exists
- `.po` / `messages.json` files are parseable (valid JSON / UTF-8)
- No broken Python-style format strings (`%(name)s`) in translated strings
- Key coverage ≥ 80% for all non-English locales

Validation runs offline (no Transifex token needed in CI).

## Locale Directory Layout

```
tutor_env/env/build/openedx/locale/   # Platform (LMS/CMS) — gitignored
  id/django.po
  zh_CN/django.po
  vi/django.po
  fil/django.po

infrastructure/tutor/themes/mereka/mfe/   # MFE locale files
  frontend-app-authn/
    en/messages.json
    id/messages.json
    zh_CN/messages.json
    vi/messages.json
    fil/messages.json
```
