// @covers AC-T049-001, AC-T049-002, AC-T049-003, AC-T049-004, AC-T049-005
// @spec: e2e-critical-path_spec.md
//
// Playwright configuration for Mereka Academy E2E tests.
//
// Target environments:
//   prod: https://academyv2.mereka.io  (MFEs at apps.academyv2.mereka.io)
//   dev:  https://academyv2.mereka.dev (MFEs at apps.academyv2.mereka.dev)
//
// Authentication: Open edX session-based auth via Authentik SSO.
// Credentials supplied via environment variables (never hardcoded).
//
// Usage:
//   BASE_URL=https://academyv2.mereka.io npx playwright test
//   BASE_URL=https://academyv2.mereka.dev npx playwright test
//   CI=true npx playwright test
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.BASE_URL ?? 'https://academyv2.mereka.io';

// Derive MFE and Studio URLs from BASE_URL host
const baseHost = new URL(BASE_URL).hostname; // e.g. academyv2.mereka.io
const MFE_BASE_URL = `https://apps.${baseHost}`;

export default defineConfig({
  testDir: './tests',
  // Global timeout for each test (network-dependent — SSO redirects can be slow)
  timeout: 90_000,
  expect: {
    timeout: 15_000,
  },
  // Retry once on CI to absorb transient network hiccups
  retries: process.env.CI ? 1 : 0,
  // Run tests serially to avoid session conflicts during login flows
  workers: 1,
  // Reporter: GitHub Actions summary + HTML report
  reporter: process.env.CI
    ? [['github'], ['html', { outputFolder: '../../var/e2e-report', open: 'never' }]]
    : [['list'], ['html', { outputFolder: '../../var/e2e-report', open: 'on-failure' }]],
  use: {
    baseURL: BASE_URL,
    // Persist auth state across tests within a worker
    storageState: process.env.E2E_AUTH_STATE ?? undefined,
    // Accept self-signed certs on dev environments
    ignoreHTTPSErrors: true,
    // Capture screenshots and traces only on failure
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    // Headless by default; override with HEADED=1
    headless: process.env.HEADED !== '1',
    // Generous navigation timeout for SSO redirect chains (6+ hops)
    navigationTimeout: 60_000,
    actionTimeout: 15_000,
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
    },
  },
  // Pass derived URLs to tests as custom config
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Allow passing custom config values via env
        baseURL: BASE_URL,
      },
    },
  ],
  // Output dir for test artifacts (traces, screenshots, videos)
  outputDir: '../../var/e2e-artifacts',
  // Custom env-based config accessible from tests
  metadata: {
    baseUrl: BASE_URL,
    mfeBaseUrl: MFE_BASE_URL,
  },
});
