import { test, expect, type Page } from '@playwright/test';
import { getMfeBaseUrl } from '../support/urls';

type RouteConfig = {
  label: string;
  path: string;
};

const BASE_MFE_ROUTES: RouteConfig[] = [
  { label: 'authn-login', path: '/authn/login' },
  { label: 'authn-register', path: '/authn/register' },
  { label: 'authn-reset', path: '/authn/reset' },
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
const OPTIONAL_MARKER_ROUTES = new Set([
  'learner-dashboard',
  'account-settings',
  'profile-home',
  'learning-route',
]);
let cachedThemeMode: ThemeContractMode | null = null;

function isAuthnRouteUrl(urlValue: string): boolean {
  try {
    return new URL(urlValue).pathname.startsWith('/authn/');
  } catch {
    return urlValue.includes('/authn/');
  }
}

function normalizeHostname(hostname: string): string {
  return hostname.toLowerCase().replace(/^www\./, '');
}

function deriveVariantCandidates(hostname: string): string[] {
  const normalizedHostname = normalizeHostname(hostname);
  if (!normalizedHostname) {
    return [];
  }

  const candidates: string[] = [];
  const queue = [normalizedHostname];
  const enqueue = (candidate: string) => {
    if (candidate && !candidates.includes(candidate)) {
      candidates.push(candidate);
      queue.push(candidate);
    }
  };

  while (queue.length > 0) {
    const candidate = queue.shift();
    if (!candidate) {
      continue;
    }

    enqueue(candidate.replace(/^(?:staging\.)?apps\./, ''));
    enqueue(candidate.replace(/^apps\./, ''));
    enqueue(candidate.replace(/^staging\./, ''));
    enqueue(candidate.replace(/\.mereka\.dev$/, '.mereka.io'));
  }

  return candidates;
}

function getExpectedThemeCss(mfeBaseUrl: string): { brandCore: string; brandLight: string } {
  const hostname = new URL(mfeBaseUrl).hostname;
  const variantThemeMap: Record<string, { brandCore: string; brandLight: string }> = {
    'academy.biji-biji.com': {
      brandCore: '/theme/biji-biji-brand.min.css',
      brandLight: '/theme/biji-biji-brand-light.min.css',
    },
    'skillourfuture.academy.mereka.io': {
      brandCore: '/theme/sof-brand.min.css',
      brandLight: '/theme/sof-brand-light.min.css',
    },
  };

  for (const candidate of deriveVariantCandidates(hostname)) {
    const variant = variantThemeMap[candidate];
    if (variant) {
      return variant;
    }
  }

  return {
    brandCore: '/theme/mereka-brand.min.css',
    brandLight: '/theme/mereka-brand-light.min.css',
  };
}

function getRuntimeThemeReferences(cssPath: string): string[] {
  const normalizedPath = cssPath.startsWith('/') ? cssPath : `/${cssPath}`;
  return [normalizedPath];
}

function htmlContainsAnyThemeReference(html: string, cssPath: string): boolean {
  return getRuntimeThemeReferences(cssPath).some((reference) => html.includes(reference));
}

type ThemeContractMode = 'runtime-theme-urls' | 'embedded-theme-files';

type TenantPalette = {
  primary: string;
  secondary: string;
  accent: string;
  textOnPrimary: string;
};

type TenantPaletteAliasMap = {
  [K in keyof typeof TENANT_PALETTE_CSS_VARIABLES]: keyof TenantPalette;
};

const TENANT_PALETTE_CSS_VARIABLES = {
  primary: '--tenant-color-primary',
  secondary: '--tenant-color-secondary',
  accent: '--tenant-color-accent',
  textOnPrimary: '--tenant-color-text-on-primary',
  merekaMagenta: '--mereka-color-magenta',
  merekaTeal: '--mereka-color-teal',
  merekaBlue: '--mereka-color-blue',
  merekaInfo: '--mereka-color-info',
  pgnPrimaryBase: '--pgn-color-primary-base',
  pgnSecondaryBase: '--pgn-color-secondary-base',
  pgnInfoBase: '--pgn-color-info-base',
  pgnBrandBase: '--pgn-color-brand-base',
  pgnLinkColor: '--pgn-link-color',
  pgnLinkHoverColor: '--pgn-link-hover-color',
} as const;

const TENANT_PALETTE_ALIAS_SOURCE: TenantPaletteAliasMap = {
  primary: 'primary',
  secondary: 'secondary',
  accent: 'accent',
  textOnPrimary: 'textOnPrimary',
  merekaMagenta: 'primary',
  merekaTeal: 'secondary',
  merekaBlue: 'accent',
  merekaInfo: 'accent',
  pgnPrimaryBase: 'primary',
  pgnSecondaryBase: 'secondary',
  pgnInfoBase: 'accent',
  pgnBrandBase: 'primary',
  pgnLinkColor: 'primary',
  pgnLinkHoverColor: 'secondary',
};

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
  if (cachedThemeMode) {
    return cachedThemeMode;
  }

  const expectedThemeCss = getExpectedThemeCss(mfeBaseUrl);

  // Prefer the rendered authn shell as the source of truth for theme loading mode.
  // /api/mfe_config/v1 payload shape can vary across Open edX releases.
  const authnShellResponse = await page.request.get(`${mfeBaseUrl}/authn/login`);
  const authnShellStatus = authnShellResponse.status();
  if (authnShellStatus >= 200 && authnShellStatus < 500) {
    const authnShellHtml = await authnShellResponse.text();
    const runtimeThemeFromHtml = htmlContainsAnyThemeReference(authnShellHtml, '/theme/core.min.css')
      && htmlContainsAnyThemeReference(authnShellHtml, expectedThemeCss.brandCore)
      && htmlContainsAnyThemeReference(authnShellHtml, expectedThemeCss.brandLight);
    if (runtimeThemeFromHtml) {
      for (const cssPath of ['/theme/core.min.css', expectedThemeCss.brandCore, expectedThemeCss.brandLight]) {
        const cssResponse = await page.request.get(`${mfeBaseUrl}${cssPath}`);
        expect(cssResponse.status()).toBeGreaterThanOrEqual(200);
        expect(cssResponse.status()).toBeLessThan(400);
        expect((cssResponse.headers()['content-type'] || '').toLowerCase()).toContain('text/css');
      }
      cachedThemeMode = 'runtime-theme-urls';
      return cachedThemeMode;
    }

    const embeddedThemeFromHtml = /paragon-theme-core\.[a-z0-9]+\.css/i.test(authnShellHtml)
      && /brand-theme-core\.[a-z0-9]+\.css/i.test(authnShellHtml);
    if (embeddedThemeFromHtml) {
      cachedThemeMode = 'embedded-theme-files';
      return cachedThemeMode;
    }
  }

  // Fallback for older shells where authn markers are absent.
  // Treat >=500/timeout from mfe_config as transient and avoid hard-failing smoke runs.
  let mfeConfigBody = '';
  let mfeConfigStatus = 0;
  const maxConfigAttempts = 3;
  for (let attempt = 1; attempt <= maxConfigAttempts; attempt += 1) {
    try {
      const mfeConfigResponse = await page.request.get(`${mfeBaseUrl}/api/mfe_config/v1`, { timeout: 15000 });
      mfeConfigStatus = mfeConfigResponse.status();
      if (mfeConfigStatus >= 200 && mfeConfigStatus < 500) {
        mfeConfigBody = await mfeConfigResponse.text();
        break;
      }
    } catch {
      mfeConfigStatus = 0;
    }
    if (attempt < maxConfigAttempts) {
      await page.waitForTimeout(300 * attempt);
    }
  }

  const runtimeThemeEnabled = mfeConfigBody.includes('PARAGON_THEME_URLS')
    && mfeConfigBody.includes('/theme/core.min.css')
    && mfeConfigBody.includes(expectedThemeCss.brandCore)
    && mfeConfigBody.includes(expectedThemeCss.brandLight);

  if (!runtimeThemeEnabled) {
    // If mfe_config stayed unavailable (>=500/timeout), default to embedded mode in non-strict smoke.
    cachedThemeMode = 'embedded-theme-files';
    return cachedThemeMode;
  }

  for (const cssPath of ['/theme/core.min.css', expectedThemeCss.brandCore, expectedThemeCss.brandLight]) {
    const cssResponse = await page.request.get(`${mfeBaseUrl}${cssPath}`);
    expect(cssResponse.status()).toBeGreaterThanOrEqual(200);
    expect(cssResponse.status()).toBeLessThan(400);
    expect((cssResponse.headers()['content-type'] || '').toLowerCase()).toContain('text/css');
  }

  cachedThemeMode = 'runtime-theme-urls';
  return cachedThemeMode;
}

function normalizePaletteValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

async function expectTenantPaletteBridge(page: Page, mfeBaseUrl: string): Promise<void> {
  const configResponse = await page.request.get(`${mfeBaseUrl}/api/mfe_config/v1`, { timeout: 15000 });
  expect(configResponse.status()).toBeGreaterThanOrEqual(200);
  expect(configResponse.status()).toBeLessThan(500);

  const configPayload = await configResponse.json().catch(() => ({} as Record<string, unknown>));
  const expectedPalette: TenantPalette = {
    primary: normalizePaletteValue(configPayload.PRIMARY_COLOR),
    secondary: normalizePaletteValue(configPayload.SECONDARY_COLOR),
    accent: normalizePaletteValue(configPayload.ACCENT_COLOR),
    textOnPrimary: normalizePaletteValue(configPayload.TEXT_ON_PRIMARY),
  };

  for (const [key, value] of Object.entries(expectedPalette)) {
    expect(value, `Expected ${key} palette value in ${mfeBaseUrl}/api/mfe_config/v1`).toBeTruthy();
  }

  const actualPalette = await page.evaluate((cssVariables) => {
    const rootStyle = getComputedStyle(document.documentElement);
    return Object.fromEntries(
      Object.entries(cssVariables).map(([key, cssVariable]) => [key, rootStyle.getPropertyValue(cssVariable).trim()]),
    );
  }, TENANT_PALETTE_CSS_VARIABLES);

  for (const [key, cssVariable] of Object.entries(TENANT_PALETTE_CSS_VARIABLES) as Array<
    [keyof typeof TENANT_PALETTE_CSS_VARIABLES, string]
  >) {
    const expectedValue = expectedPalette[TENANT_PALETTE_ALIAS_SOURCE[key]];
    expect(
      actualPalette[key],
      `Expected ${key} (${cssVariable}) on ${mfeBaseUrl} to equal ${expectedValue}; got ${actualPalette[key]}`,
    ).toBe(expectedValue);
  }
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
      } else {
      const expectedThemeCss = getExpectedThemeCss(mfeBaseUrl);
      expect(htmlContainsAnyThemeReference(html, '/theme/core.min.css')).toBeTruthy();
      expect(htmlContainsAnyThemeReference(html, expectedThemeCss.brandCore)).toBeTruthy();
      expect(htmlContainsAnyThemeReference(html, expectedThemeCss.brandLight)).toBeTruthy();
    }

      await expectTenantPaletteBridge(page, mfeBaseUrl);

      let markerCounts = await getBrandingMarkerCounts(page);
      const isAuthnRoute = route.label.startsWith('authn-');
      const currentUrl = page.url();
      let redirectedToAuthn = !isAuthnRoute && isAuthnRouteUrl(currentUrl);
      if (REQUIRE_BRANDING_MARKERS && !OPTIONAL_MARKER_ROUTES.has(route.label) && !redirectedToAuthn) {
        const maxAttempts = 8;
        for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
          redirectedToAuthn = !isAuthnRoute && isAuthnRouteUrl(page.url());
          if (redirectedToAuthn) {
            break;
          }
          const authnMarkerReady = markerCounts.authnBranding > 0;
          const anyMarkerReady = getBrandingMarkerHitCount(markerCounts) > 0;
          const markerReady = isAuthnRoute ? authnMarkerReady : anyMarkerReady;
          if (markerReady) {
            break;
          }
          await page.waitForTimeout(500);
          markerCounts = await getBrandingMarkerCounts(page);
        }

        if (redirectedToAuthn) {
          const title = await page.title();
          const hasAuthnMarker = markerCounts.authnBranding > 0;
          const hasLoginTitle = /(login|sign in|register|reset|password|auth)/i.test(title);
          expect(
            hasAuthnMarker || hasLoginTitle,
            `Expected branded authn shell signal after redirect from ${targetUrl}; current URL=${page.url()} title=${title} counts=${JSON.stringify(markerCounts)}`,
          ).toBeTruthy();
        } else if (isAuthnRoute) {
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
        body: JSON.stringify({ route: route.label, targetUrl, currentUrl, redirectedToAuthn, markerCounts }, null, 2),
        contentType: 'application/json',
      });

      await page.screenshot({
        path: testInfo.outputPath(`${route.label}.png`),
        fullPage: true,
      });
    });
  }
});
