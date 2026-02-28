import { test, expect, type Page } from '@playwright/test';

type RouteConfig = {
  label: string;
  path: string;
};

const BASE_MFE_ROUTES: RouteConfig[] = [
  { label: 'authn-login', path: '/authn/login' },
  { label: 'learner-dashboard', path: '/learner-dashboard/' },
  { label: 'account-settings', path: '/account/settings' },
  { label: 'profile-home', path: '/profile/u/' },
];

const LEARNING_ROUTE = (process.env.BRANDING_LEARNING_PATH ?? '').trim();

const MFE_ROUTES: RouteConfig[] = [
  ...BASE_MFE_ROUTES,
  ...(LEARNING_ROUTE
    ? [{ label: 'learning-route', path: LEARNING_ROUTE.startsWith('/') ? LEARNING_ROUTE : `/${LEARNING_ROUTE}` }]
    : []),
];

const REQUIRE_RUNTIME_THEME_URLS = process.env.REQUIRE_RUNTIME_THEME_URLS === '1';

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const baseHost = new URL(lmsBaseUrl).hostname;
  return `https://apps.${baseHost}`;
}

type ThemeContractMode = 'runtime-theme-urls' | 'embedded-theme-files';

async function detectThemeContractMode(page: Page, mfeBaseUrl: string): Promise<ThemeContractMode> {
  const mfeConfigResponse = await page.request.get(`${mfeBaseUrl}/api/mfe_config/v1`);
  expect(mfeConfigResponse.status()).toBeGreaterThanOrEqual(200);
  expect(mfeConfigResponse.status()).toBeLessThan(500);

  const mfeConfigBody = await mfeConfigResponse.text();
  const runtimeThemeEnabled = mfeConfigBody.includes('PARAGON_THEME_URLS')
    && mfeConfigBody.includes('/theme/core.min.css')
    && mfeConfigBody.includes('/theme/mereka-brand.min.css');

  if (!runtimeThemeEnabled) {
    return 'embedded-theme-files';
  }

  for (const cssPath of ['/theme/core.min.css', '/theme/mereka-brand.min.css']) {
    const cssResponse = await page.request.get(`${mfeBaseUrl}${cssPath}`);
    expect(cssResponse.status()).toBeGreaterThanOrEqual(200);
    expect(cssResponse.status()).toBeLessThan(400);
    expect((cssResponse.headers()['content-type'] || '').toLowerCase()).toContain('text/css');
  }

  return 'runtime-theme-urls';
}

test.describe('Branding smoke', () => {
  for (const route of MFE_ROUTES) {
    test(`theme assets + token bridge present on ${route.label}`, async ({ page, baseURL }, testInfo) => {
      const mfeBaseUrl = getMfeBaseUrl(baseURL!);
      const targetUrl = `${mfeBaseUrl}${route.path}`;

      const themeMode = await detectThemeContractMode(page, mfeBaseUrl);
      if (REQUIRE_RUNTIME_THEME_URLS) {
        expect(themeMode).toBe('runtime-theme-urls');
      }

      const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
      expect(response?.status() ?? 0).toBeGreaterThan(0);
      expect(response?.status() ?? 500).toBeLessThan(500);

      await page.waitForLoadState('networkidle').catch(() => {});
      const html = response ? await response.text() : '';
      expect(html).toContain('PARAGON_THEME');
      if (themeMode === 'embedded-theme-files') {
        expect(html).toMatch(/paragon-theme-core\.[a-z0-9]+\.css/i);
        expect(html).toMatch(/brand-theme-core\.[a-z0-9]+\.css/i);
      }

      await page.screenshot({
        path: testInfo.outputPath(`${route.label}.png`),
        fullPage: true,
      });
    });
  }
});
