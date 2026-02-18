# A11y Contrast + Focus-Visible Gate

**Script**: `scripts/qa/verify-a11y-contrast-focus.sh`
**AC coverage**: AC-A11Y-001, AC-A11Y-002, AC-A11Y-003, AC-A11Y-004
**CI job**: `a11y-contrast-focus`

---

## WCAG AA Thresholds

| Text category | Minimum contrast ratio | Definition |
|---|---|---|
| Normal text | **4.5:1** | Body copy ≤18px regular, ≤14px bold |
| Large text | **3:1** | ≥18px regular or ≥14px bold |
| UI components / graphical objects | **3:1** | Buttons, form borders, icons that convey meaning |
| Decorative / placeholder text | Advisory | Not legally required, but warn if below 3:1 |

Reference: [WCAG 2.1 SC 1.4.3 (Contrast Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
and [SC 1.4.11 (Non-text Contrast)](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html).

---

## Token Pairs Checked

The script reads computed hex values from
`infrastructure/tutor/themes/mereka/scss/_tokens.scss` and evaluates each pair.

| Pair label | Foreground token | Background token | Threshold | Rationale |
|---|---|---|---|---|
| Body text | `$color-ink-900` | `$color-neutral-100` | 4.5:1 | Primary body copy |
| Secondary text | `$color-ink-700` | `$color-neutral-100` | 4.5:1 | Navigation, labels |
| Muted text | `$color-ink-500` | `$color-neutral-100` | 4.5:1 | Subtext, captions at 16px |
| Placeholder / caption | `$color-ink-300` | `$color-neutral-100` | 4.5:1 (WARN if below) | Placeholder-only contexts may be exempt |
| Heading (large) | `$color-ink-900` | `$color-neutral-100` | 3:1 | H1–H6 at design-system sizes |
| Link default | `$color-blue` | `$color-neutral-100` | 4.5:1 | Inline links |
| Link hover | `$color-teal` | `$color-neutral-100` | 4.5:1 | Hover / focus state link colour |
| Btn primary: white on magenta | `#ffffff` | `$color-magenta` | 3:1 | Button gradient start (UI component) |
| Btn primary: white on teal | `#ffffff` | `$color-teal` | 3:1 | Button gradient mid (UI component) |
| Btn primary: white on blue | `#ffffff` | `$color-blue` | 3:1 | Button gradient end (UI component) |
| Success text | `$color-forest` | `$color-neutral-100` | 4.5:1 | Status / success messages |
| Danger text | `$color-burgundy` | `$color-neutral-100` | 4.5:1 | Error / danger messages |
| Badge: teal on teal-12 | `$color-teal` | `~#eef5f5` (blended approx.) | 3:1 | `.mereka-badge` label |

### Adding New Contrast Pairs

1. Open `scripts/qa/verify-a11y-contrast-focus.sh`.
2. Find the section labelled `# ── Body text (normal, 16px)`.
3. Add a `check_pair` call with the signature:

   ```bash
   check_pair "<human label>" "$FOREGROUND_VAR" "$BACKGROUND_VAR" <threshold> "<size note>"
   ```

   where `threshold` is `4.5` (normal) or `3.0` (large / UI component) and
   `size_note` is one of `"normal text"`, `"large text"`, `"UI component"`.

4. If the token is not already extracted, add a `get_scss_color` line near the top
   of the palette extraction block.
5. Update this table with the new row.
6. Run `./scripts/qa/verify-a11y-contrast-focus.sh` locally before committing.

---

## Focus Visibility Requirements

All interactive elements **must** have a visible focus indicator when reached via
keyboard navigation.  WCAG 2.1 SC 2.4.7 (Focus Visible — Level AA) requires this.

### Mereka implementation rules

1. **Do not use bare `outline: none` or `outline: 0`** on interactive elements
   (buttons, links, form controls, nav items) unless an equally visible alternative
   is provided in the **same CSS rule block**.

2. **Acceptable replacement** for `outline: none`:

   ```css
   outline: none;
   box-shadow: 0 0 0 4px var(--mereka-mfe-focus);   /* teal glow */
   ```

3. **`box-shadow: none` inside `:focus` selectors** is a blocking finding.
   It explicitly cancels the glow-based replacement ring.

4. **Preferred future pattern** (`Q2 2026`): migrate to `:focus-visible` so the
   focus ring appears for keyboard users but not mouse clicks.

   ```css
   :focus:not(:focus-visible) { outline: none; box-shadow: none; }
   :focus-visible { outline: 3px solid var(--mereka-color-teal); outline-offset: 2px; }
   ```

5. **Paragon token bridge** (`Q2 2026`): wire `--pgn-focus-ring-color` to
   `--mereka-color-teal` in `_tokens.scss` so Paragon components inherit the
   brand focus ring automatically.

### Scanned files

The script scans all `*.scss` and `*.css` under
`infrastructure/tutor/themes/mereka/` (excluding `node_modules`).

---

## Exception Process

When a finding cannot be fixed immediately (e.g., upstream library imposes the
pattern, or a design decision intentionally deviates), follow this process:

### 1. Raise a reviewer-approved exception

Create or update `docs/operations/A11Y_EXCEPTIONS.md` (create if absent) with
an entry in this format:

```markdown
### EXC-A11Y-<NNN> — <Short description>

| Field        | Value |
|---|---|
| Finding      | e.g. `ink-300 on neutral-100 = 2.1:1 (below 4.5:1)` |
| Context      | e.g. placeholder text inside a search input |
| WCAG SC      | 1.4.3 / 1.4.11 / 2.4.7 |
| Severity     | Low / Medium / High |
| Justification | Why the deviation is acceptable for this context |
| Approved by  | @reviewer GitHub handle |
| Approved at  | YYYY-MM-DD |
| Remediation  | Target date or "accepted permanent exception" |
```

### 2. Reference the exception in CI

If the finding maps to a WARN (not a FAIL), the gate passes automatically.
For items that would be a FAIL:

- Add the exception entry to `docs/operations/A11Y_EXCEPTIONS.md`.
- A second reviewer must approve the PR (no self-review).
- CI will still report the FAIL, but the PR may be merged with documented
  override by using the label `a11y-exception-approved` in GitHub.

### 3. Blocking findings that cannot be excepted

The following are **never acceptable exceptions**:

- Body text contrast below **3:1** (any ratio under 3 is a hard block).
- `box-shadow: none` inside a `:focus` selector with no alternative.
- Total removal of focus styling (`outline: none` + `box-shadow: none`) on
  interactive elements with no replacement.

---

## CI Integration

The gate runs as a dedicated job (`a11y-contrast-focus`) in
`.github/workflows/ci.yml` and also has a syntax-check entry in the
`monitoring-guardrails` job.

**Triggers**: PRs touching any of:

- `assets/branding/tokens.css`
- `infrastructure/tutor/themes/mereka/**`
- `scripts/qa/verify-a11y-contrast-focus.sh`
- `docs/operations/A11Y_*.md`

**Artifacts**: The script writes `var/a11y-contrast-focus-gate.txt` with
machine-readable counters for downstream consumption.

**Strict mode**: Set `A11Y_STRICT=1` to promote WARN findings to FAIL
(useful for pre-release hardening runs).

---

## Related Documents

- `docs/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md` — Platform-wide a11y policy
- `docs/operations/A11Y_EXCEPTIONS.md` — Active exception log (create when first needed)
- `scripts/qa/verify-accessibility-conformance.sh` — Broader WCAG conformance gate
- `scripts/qa/verify-contrast-compliance.sh` — Original token contrast gate
- `scripts/qa/verify-branding-token-integrity.sh` — Token cross-check + body contrast
