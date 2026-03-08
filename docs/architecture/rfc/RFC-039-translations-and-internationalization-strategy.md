# RFC-039 Translations And Internationalization Strategy

Status: proposed
Source record: `docs/adr/039-translations-and-internationalization-strategy.md`

## Intent

Treat translations and i18n as architecture rather than a best-effort content activity.

## Why This Is Still An RFC

The team has direction and checks, but not yet an accepted steady-state multilingual contract.

## Candidate Invariants

- Message keys are stable.
- Locale fallback is explicit.
- Translation release validation is required.
