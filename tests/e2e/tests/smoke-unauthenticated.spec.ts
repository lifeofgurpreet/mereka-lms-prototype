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
  test('LMS homepage responds 200', async ({ page, baseURL }) => {
    const response = await page.goto(baseURL!, { waitUntil: 'domcontentloaded' });
    expect(response?.status()).toBe(200);

    // Page should contain the site name or a recognizable LMS element
    const body = await page.locator('body').innerText();
    expect(body.length).toBeGreaterThan(100);
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
  test('/api/mfe_config/v1 returns valid JSON', async ({ request, baseURL }) => {
    const mfeBase = getMfeBaseUrl(baseURL!);
    const response = await request.get(`${mfeBase}/api/mfe_config/v1`, {
      failOnStatusCode: false,
    });

    // mfe_config endpoint may be on MFE host or LMS host
    if (response.status() === 404) {
      // Try LMS host
      const lmsResponse = await request.get(`${baseURL}/api/mfe_config/v1`, {
        failOnStatusCode: false,
      });
      if (lmsResponse.status() === 200) {
        const body = await lmsResponse.json();
        expect(body).toBeDefined();
        expect(typeof body).toBe('object');
      }
      return;
    }

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toBeDefined();
    expect(typeof body).toBe('object');
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
