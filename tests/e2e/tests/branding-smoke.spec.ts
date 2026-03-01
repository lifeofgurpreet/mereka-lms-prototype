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
const REQUIRE_BRANDING_MARKERS = process.env.REQUIRE_BRANDING_MARKERS !== '0';

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const parsed = new URL(lmsBaseUrl);
  const host = parsed.hostname.startsWith('apps.') ? parsed.hostname : `apps.${parsed.hostname}`;
  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${host}${port}`;
}

type ThemeContractMode = 'runtime-theme-urls' | 'embedded-theme-files';

const BRANDING_MARKER_SELECTORS = {
  authnBranding: '.mereka-authn-login-branding',
  headerLogo: '.mereka-header-logo',
  footer: '.mereka-footer',
  dashboardHeader: '.mereka-dashboard-header-slot',
  learningHeader: '.mereka-learning-course-header',
} as const;

type BrandingMarkerCounts = Record<keyof typeof BRANDING_MARKER_SELECTORS, number>;

async function safeCountSelector(page: Page, selector: string): Promise<number> {
  const retries = 3;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      return await page.locator(selector).count();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const isTransientNavigationError =
        message.includes('Execution context was destroyed')
        || message.includes('Target page, context or browser has been closed');
      if (!isTransientNavigationError || attempt === retries - 1) {
        return 0;
      }
      await page.waitForTimeout(250);
    }
  }
  return 0;
}

async function getBrandingMarkerCounts(page: Page): Promise<BrandingMarkerCounts> {
  const counts = {} as BrandingMarkerCounts;
  for (const [key, selector] of Object.entries(BRANDING_MARKER_SELECTORS) as Array<
    [keyof typeof BRANDING_MARKER_SELECTORS, string]
  >) {
    counts[key] = await safeCountSelector(page, selector);
  }
  return counts;
}

function getBrandingMarkerHitCount(counts: BrandingMarkerCounts): number {
  return Object.values(counts).reduce((sum, value) => sum + value, 0);
}

async function detectThemeContractMode(page: Page, mfeBaseUrl: string): Promise<ThemeContractMode> {
  // Prefer the rendered authn shell as the source of truth for theme loading mode.
  // /api/mfe_config/v1 payload shape can vary across Open edX releases.
  const authnShellResponse = await page.request.get(`${mfeBaseUrl}/authn/login`);
  const authnShellStatus = authnShellResponse.status();
  if (authnShellStatus >= 200 && authnShellStatus < 500) {
    const authnShellHtml = await authnShellResponse.text();
    const runtimeThemeFromHtml = authnShellHtml.includes('/theme/core.min.css')
      && authnShellHtml.includes('/theme/mereka-brand.min.css');
    if (runtimeThemeFromHtml) {
      for (const cssPath of ['/theme/core.min.css', '/theme/mereka-brand.min.css']) {
        const cssResponse = await page.request.get(`${mfeBaseUrl}${cssPath}`);
        expect(cssResponse.status()).toBeGreaterThanOrEqual(200);
        expect(cssResponse.status()).toBeLessThan(400);
        expect((cssResponse.headers()['content-type'] || '').toLowerCase()).toContain('text/css');
      }
      return 'runtime-theme-urls';
    }

    const embeddedThemeFromHtml = /paragon-theme-core\.[a-z0-9]+\.css/i.test(authnShellHtml)
      && /brand-theme-core\.[a-z0-9]+\.css/i.test(authnShellHtml);
    if (embeddedThemeFromHtml) {
      return 'embedded-theme-files';
    }
  }

  // Fallback for older shells where authn markers are absent.
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

      let markerCounts = await getBrandingMarkerCounts(page);
      if (REQUIRE_BRANDING_MARKERS) {
        const maxAttempts = 8;
        for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
          const authnMarkerReady = markerCounts.authnBranding > 0;
          const anyMarkerReady = getBrandingMarkerHitCount(markerCounts) > 0;
          const markerReady = route.label === 'authn-login' ? authnMarkerReady : anyMarkerReady;
          if (markerReady) {
            break;
          }
          await page.waitForTimeout(500);
          markerCounts = await getBrandingMarkerCounts(page);
        }

        if (route.label === 'authn-login') {
          expect(
            markerCounts.authnBranding,
            `Expected authn branding marker (${BRANDING_MARKER_SELECTORS.authnBranding}) on ${targetUrl}; current URL=${page.url()} counts=${JSON.stringify(markerCounts)}`,
          ).toBeGreaterThan(0);
        } else {
          expect(
            getBrandingMarkerHitCount(markerCounts),
            `Expected at least one branded marker on ${targetUrl}; current URL=${page.url()} counts=${JSON.stringify(markerCounts)}`,
          ).toBeGreaterThan(0);
        }
      }

      await testInfo.attach('branding-markers.json', {
        body: JSON.stringify({ route: route.label, targetUrl, currentUrl: page.url(), markerCounts }, null, 2),
        contentType: 'application/json',
      });

      await page.screenshot({
        path: testInfo.outputPath(`${route.label}.png`),
        fullPage: true,
      });
    });
  }
});
