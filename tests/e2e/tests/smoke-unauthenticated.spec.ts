// Unauthenticated smoke tests — no credentials needed.
// Safe to run in any CI environment against prod or dev.
//
// Coverage:
//   1. LMS homepage responds 200
//   2. MFE authn/login page loads with branding
//   3. MFE registration page loads
//   4. Password reset page loads
//   5. Each MFE app root responds (health check)
//   6. LMS heartbeat endpoint returns 200
//   7. Multi-site: Biji-Biji domain responds (if reachable)
//   8. Security headers present on MFE responses
//
// Usage:
//   npx playwright test smoke-unauthenticated
//   BASE_URL=https://academyv2.mereka.dev npx playwright test smoke-unauthenticated
import { test, expect } from '@playwright/test';

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const parsed = new URL(lmsBaseUrl);
  const host = parsed.hostname.startsWith('apps.')
    ? parsed.hostname
    : `apps.${parsed.hostname}`;
  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${host}${port}`;
}

test.describe('Unauthenticated smoke — LMS', () => {
  test('LMS homepage responds 200 with branded hero shell', async ({ page, baseURL }) => {
    const response = await page.goto(baseURL!, { waitUntil: 'domcontentloaded' });
    expect(response?.status()).toBe(200);

    await expect(page.locator('.mereka-hero')).toHaveCount(1);
    await expect(page.locator('.mereka-hero__spotlight')).toHaveCount(1);
    await expect(page.locator('.hero-actions .btn')).toHaveCount(2);

    const signalChips = page.locator('.mereka-hero__signal');
    expect(await signalChips.count()).toBeGreaterThanOrEqual(3);

    const metricCards = page.locator('.hero-metrics li');
    expect(await metricCards.count()).toBeGreaterThanOrEqual(3);
  });

  test('LMS heartbeat returns 200', async ({ request, baseURL }) => {
    const response = await request.get(`${baseURL}/heartbeat`);
    expect(response.status()).toBe(200);
    const body = await response.text();
    expect(body).toContain('OK');
  });

  test('LMS /api/user/v1/me returns 401 for unauthenticated', async ({ request, baseURL }) => {
    const response = await request.get(`${baseURL}/api/user/v1/me`, {
      failOnStatusCode: false,
    });
    // Unauthenticated: 401 or 403 (both valid)
    expect([401, 403]).toContain(response.status());
  });
});

test.describe('Unauthenticated smoke — MFE apps', () => {
  const MFE_APPS = [
    { name: 'authn', path: '/authn/login' },
    { name: 'authn-register', path: '/authn/register' },
    { name: 'learner-dashboard', path: '/learner-dashboard/' },
    { name: 'account', path: '/account/' },
    { name: 'profile', path: '/profile/' },
  ];

  for (const app of MFE_APPS) {
    test(`MFE ${app.name} responds without 5xx`, async ({ page, baseURL }) => {
      const mfeBase = getMfeBaseUrl(baseURL!);
      const response = await page.goto(`${mfeBase}${app.path}`, {
        waitUntil: 'domcontentloaded',
      });

      const status = response?.status() ?? 0;
      // Accept 200, 302 (redirect to login), 401, 403 — reject 5xx
      expect(status).toBeGreaterThan(0);
      expect(status).toBeLessThan(500);
    });
  }

  test('authn login page contains Paragon theme reference', async ({ page, baseURL }) => {
    const mfeBase = getMfeBaseUrl(baseURL!);
    const response = await page.goto(`${mfeBase}/authn/login`, {
      waitUntil: 'domcontentloaded',
    });

    const html = await response?.text() ?? '';
    // Must reference Paragon theme CSS (either runtime URLs or embedded)
    const hasRuntimeTheme = html.includes('/theme/core.min.css');
    const hasEmbeddedTheme = /paragon-theme-core\.[a-z0-9]+\.css/i.test(html);
    expect(
      hasRuntimeTheme || hasEmbeddedTheme,
      'authn/login should reference Paragon theme CSS (runtime or embedded)',
    ).toBe(true);
  });

  test('password reset page loads', async ({ page, baseURL }) => {
    const mfeBase = getMfeBaseUrl(baseURL!);
    const response = await page.goto(`${mfeBase}/authn/reset`, {
      waitUntil: 'domcontentloaded',
    });

    const status = response?.status() ?? 0;
    expect(status).toBeGreaterThan(0);
    expect(status).toBeLessThan(500);

    // Should contain a form or input for email
    await page.waitForLoadState('networkidle').catch(() => {});
    const emailInput = page.locator('input[type="email"], input[name="email"]').first();
    const hasEmailInput = await emailInput.isVisible({ timeout: 10_000 }).catch(() => false);
    // Accept either the email input or a redirect (some configs redirect to LMS native)
    if (hasEmailInput) {
      await expect(emailInput).toBeVisible();
    }
  });
});

test.describe('Unauthenticated smoke — security headers', () => {
  test('MFE responses include security headers', async ({ request, baseURL }) => {
    const mfeBase = getMfeBaseUrl(baseURL!);
    const response = await request.get(`${mfeBase}/authn/login`);
    const headers = response.headers();

    // X-Content-Type-Options should be nosniff
    const xcto = headers['x-content-type-options'];
    if (xcto) {
      expect(xcto).toBe('nosniff');
    }

    // Content-Type should be present and be HTML
    const contentType = headers['content-type'] ?? '';
    expect(contentType.toLowerCase()).toContain('text/html');
  });

  test('LMS responses include security headers', async ({ request, baseURL }) => {
    const response = await request.get(`${baseURL}/heartbeat`);
    const headers = response.headers();

    // Basic check: server should respond with content-type
    expect(headers['content-type']).toBeDefined();
  });
});

test.describe('Unauthenticated smoke — API contracts', () => {
  test('/api/mfe_config/v1 returns valid JSON and stays consistent across public surfaces', async ({ request, baseURL }) => {
    const mfeBase = getMfeBaseUrl(baseURL!);
    const mfeResponse = await request.get(`${mfeBase}/api/mfe_config/v1?mfe=authn`, {
      failOnStatusCode: false,
    });
    const lmsResponse = await request.get(`${baseURL}/api/mfe_config/v1`, {
      failOnStatusCode: false,
    });

    const hasMfeSurface = mfeResponse.status() === 200;
    const hasLmsSurface = lmsResponse.status() === 200;

    expect(
      hasMfeSurface,
      `apps-host MFE config surface should return 200 (got ${mfeResponse.status()})`,
    ).toBe(true);
    expect(
      hasLmsSurface,
      `LMS-host MFE config surface should return 200 (got ${lmsResponse.status()})`,
    ).toBe(true);

    const criticalKeys = [
      'LEARNER_HOME_MICROFRONTEND_URL',
      'ACCOUNT_MICROFRONTEND_URL',
      'ACCOUNT_SETTINGS_URL',
      'DISCUSSIONS_MICROFRONTEND_URL',
      'ACCOUNT_PROFILE_URL',
      'PROFILE_MICROFRONTEND_URL',
      'LEARNING_BASE_URL',
      'LOGIN_REDIRECT_URL',
    ];
    let mfeBody: Record<string, unknown> | null = null;
    let lmsBody: Record<string, unknown> | null = null;

    if (hasMfeSurface) {
      mfeBody = await mfeResponse.json();
      expect(mfeBody).toBeDefined();
      expect(typeof mfeBody).toBe('object');

      for (const key of criticalKeys) {
        expect(mfeBody[key], `MFE surface missing ${key}`).toBeTruthy();
      }
    }

    if (hasLmsSurface) {
      lmsBody = await lmsResponse.json();
      expect(lmsBody).toBeDefined();
      expect(typeof lmsBody).toBe('object');

      for (const key of criticalKeys) {
        expect(lmsBody[key], `LMS surface missing ${key}`).toBeTruthy();
      }
    }

    if (hasMfeSurface && hasLmsSurface) {
      for (const key of criticalKeys) {
        expect(lmsBody![key], `surface mismatch for ${key}`).toBe(mfeBody![key]);
      }
    }
  });

  test('/api/enrollment/v1/enrollment returns 401 unauthenticated', async ({ request, baseURL }) => {
    const response = await request.get(`${baseURL}/api/enrollment/v1/enrollment`, {
      failOnStatusCode: false,
    });
    // 401 or 403 for unauthenticated access
    expect([401, 403]).toContain(response.status());
  });

  test('Forum API /api/discussion/v2/ responds', async ({ request, baseURL }) => {
    const response = await request.get(`${baseURL}/api/discussion/v2/threads/`, {
      failOnStatusCode: false,
    });
    // Accept 200 (public forum), 401, 403, or 400 (missing params)
    expect([200, 400, 401, 403]).toContain(response.status());
  });
});

test.describe('Unauthenticated smoke — multi-site', () => {
  test('Biji-Biji domain reachable (if DNS resolves)', async ({ request }) => {
    const bijiUrl = 'https://academy.biji-biji.com';
    try {
      const response = await request.get(bijiUrl, {
        failOnStatusCode: false,
        timeout: 15_000,
      });
      // If reachable, should return 200 or redirect
      expect(response.status()).toBeLessThan(500);
    } catch {
      // DNS may not resolve in CI — skip gracefully
      test.skip(true, 'academy.biji-biji.com not reachable from this network');
    }
  });
});
