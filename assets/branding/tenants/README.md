# Tenant Brand Sources

This directory is the canonical source-of-truth for non-default tenant brand package assets.

- `assets/branding/` remains the canonical source for the default `mereka` brand.
- `assets/branding/tenants/biji-biji/` is canonical for `infrastructure/tutor/brand-biji-biji/`.
- `assets/branding/tenants/skillourfuture/` is canonical for `infrastructure/tutor/brand-skillourfuture/`.

Sync all brand package consumers:

```bash
./scripts/branding/sync-brand-assets.sh
```

Verify drift across theme targets and all `brand-*` packages:

```bash
./scripts/qa/verify-brand-asset-drift.sh
```
