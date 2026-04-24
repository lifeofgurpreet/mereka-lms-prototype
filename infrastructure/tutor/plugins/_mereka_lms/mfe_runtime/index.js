// MFE runtime definitions — thin entrypoint.
// Imports from surface-specific modules and re-exports the composed config.
// This file is concatenated by mfe_runtime.py and injected into env.config.jsx
// via the mfe-env-config-runtime-definitions Tutor patch.
//
// Module load order matters: tenant-resolution.js must come first because all
// other modules reference getMerekaVariant, getMerekaShellCopy, etc.

// ── 1. Tenant resolution (data contracts + helpers) ─────────────────────────
// @include tenant-resolution.js

// ── 2. Header / menu components ─────────────────────────────────────────────
// @include header-menu.js

// ── 3. Dashboard surface components ─────────────────────────────────────────
// @include dashboard.js

// ── 4. Learning / courseware surface components ──────────────────────────────
// @include learning.js

// ── 5. Certificate, profile, account verification components ─────────────────
// @include certificate-profile.js

// ── 6. Studio / authoring hint components ────────────────────────────────────
// @include authoring.js

// ── 7. Footer component ───────────────────────────────────────────────────────
// @include footer.js
