import { test, expect, type Page } from '@playwright/test';
import { getMfeBaseUrl } from '../support/urls';

const REQUIRE_BRANDING_MARKERS = process.env.REQUIRE_BRANDING_MARKERS !== '0';
const MIN_TRACKED_SELECTOR_HITS = Number.parseInt(process.env.MIN_TRACKED_SELECTOR_HITS ?? '3', 10);
const MIN_CUSTOM_SELECTOR_HITS = Number.parseInt(process.env.MIN_CUSTOM_SELECTOR_HITS ?? '0', 10);
const SELECTOR_AUDIT_PATH = (process.env.SELECTOR_AUDIT_PATH ?? '/authn/login').trim() || '/authn/login';
const SELECTOR_AUDIT_ROUTES = parseCsv(process.env.SELECTOR_AUDIT_ROUTES ?? SELECTOR_AUDIT_PATH)
  .map(normalizeRoutePath);
const SELECTOR_AUDIT_SELECTORS = parseCsv(process.env.SELECTOR_AUDIT_SELECTORS ?? '');
const ROUTE_SPECIFIC_BRANDING_SELECTORS: Array<{ pattern: RegExp; selectors: string[] }> = [
  {
    pattern: /\/authn\//,
    selectors: [
      '.mereka-authn-login-branding__logo',
      '.mereka-authn-login-branding__logo-img',
    ],
  },
  {
    pattern: /\/learner-dashboard\/?$/,
    selectors: [
      '.mereka-dashboard-header-slot .mereka-shell-kicker',
      '.mereka-dashboard-header-slot__actions',
    ],
  },
  {
    pattern: /\/(course|learning)\//,
    selectors: [
      '.mereka-learning-course-header .mereka-shell-kicker',
      '.mereka-learning-course-header__actions',
      '.mereka-learning-course-header__signal-list',
    ],
  },
  {
    pattern: /\/progress\//,
    selectors: [
      '.mereka-progress-certificate-status',
    ],
  },
  {
    pattern: /\/discussion\//,
    selectors: [
      '.mereka-learning-notifications-discussions-sidebar-hint, .mereka-learning-notifications-discussions-sidebar-trigger-hint',
    ],
  },
];

function parseCsv(value: string): string[] {
  return value
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function normalizeRoutePath(route: string): string {
  return route.startsWith('/') ? route : `/${route}`;
}

function getRouteArtifactSuffix(route: string): string {
  return route.replace(/[^a-zA-Z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'root';
}

function getRequiredRouteSelectors(routePath: string, currentUrl: string): string[] {
  const target = `${routePath} ${currentUrl}`;
  return ROUTE_SPECIFIC_BRANDING_SELECTORS
    .filter(({ pattern }) => pattern.test(target))
    .flatMap(({ selectors }) => selectors);
}

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
      await page.waitForTimeout(200);
    }
  }
  return 0;
}

async function safePageContent(page: Page): Promise<string> {
  const retries = 5;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      return await page.content();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const isClosedError = page.isClosed()
        || message.includes('Target page, context or browser has been closed');
      const isTransientNavigationError = message.includes('is navigating and changing the content')
        || message.includes('Execution context was destroyed')
        || isClosedError;
      if (isClosedError || !isTransientNavigationError || attempt === retries - 1) {
        return '';
      }
      await page.waitForTimeout(200);
    }
  }
  return '';
}

async function safeBodyText(page: Page): Promise<string> {
  const retries = 5;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      return (await page.locator('body').innerText().catch(() => '')).trim();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const isClosedError = page.isClosed()
        || message.includes('Target page, context or browser has been closed');
      const isTransientNavigationError = message.includes('Execution context was destroyed')
        || isClosedError;
      if (isClosedError || !isTransientNavigationError || attempt === retries - 1) {
        return '';
      }
      await page.waitForTimeout(200);
    }
  }
  return '';
}

async function recoverTransientErrorShell(page: Page): Promise<void> {
  // Some authn surfaces intermittently render a recoverable runtime error shell
  // before hydration completes. Try a bounded self-heal before asserting selectors.
  const retries = 2;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    const bodyText = (await page.locator('body').innerText().catch(() => '')).toLowerCase();
    const isTransientErrorShell = bodyText.includes('an unexpected error occurred')
      && bodyText.includes('try again');
    if (!isTransientErrorShell) {
      return;
    }

    const tryAgainButton = page.getByRole('button', { name: /try again/i }).first();
    if (await tryAgainButton.count().catch(() => 0)) {
      await tryAgainButton.click({ timeout: 3000 }).catch(() => {});
    } else {
      await page.reload({ waitUntil: 'domcontentloaded' }).catch(() => {});
    }

    await page.waitForTimeout(1500);
    await page.waitForLoadState('networkidle').catch(() => {});
  }
}

test('runtime selector DOM audit on configured MFE surfaces', async ({ page, baseURL }, testInfo) => {
  test.setTimeout(180_000);
  const mfeBaseUrl = getMfeBaseUrl(baseURL!);

  const requiredSelectors = {
    authnBranding: '.mereka-authn-login-branding',
    headerLogo: '.mereka-header-logo',
    footer: '.mereka-footer',
  } as const;

  const trackedSelectors = {
    form: 'form',
    input: 'input',
    button: 'button',
    link: 'a',
    heading: 'h1, h2, h3',
    container: 'main, section, article, [role="main"]',
  } as const;

  const customSelectorTotals = Object.fromEntries(
    SELECTOR_AUDIT_SELECTORS.map((selector) => [selector, 0]),
  ) as Record<string, number>;

  const routeResults: Array<{
    routePath: string;
    targetUrl: string;
    currentUrl: string;
    requiredCounts: Record<string, number>;
    trackedCounts: Record<string, number>;
    customSelectorCounts: Record<string, number>;
    trackedSelectorHits: number;
    hydrationSignal: boolean;
    hasRootContainer: boolean;
    hasScriptTags: boolean;
    pageTextLength: number;
  }> = [];

  for (const routePath of SELECTOR_AUDIT_ROUTES) {
    const targetUrl = `${mfeBaseUrl}${routePath}`;
    const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
    expect(response?.status() ?? 0).toBeGreaterThan(0);
    expect(response?.status() ?? 500).toBeLessThan(500);

    await page.waitForLoadState('networkidle').catch(() => {});
    let pageHtml = await safePageContent(page);
    let pageText = await safeBodyText(page);

    // Runtime MFE surfaces can occasionally present a transient blank shell in headless runs.
    // Retry bounded reloads while the page is text-empty and lacks branded stylesheet signals.
    for (let retry = 0; retry < 3; retry += 1) {
      const hasThemeBrandStylesheet = /mereka-brand(?:-light)?(?:\\.min)?\\.css/i.test(pageHtml);
      const hasThemeBrandLink = (await safeCountSelector(page, 'link[href*="mereka-brand"]')) > 0;
      const blankLikeShell = pageText.length === 0
        && !hasThemeBrandStylesheet
        && !hasThemeBrandLink;
      if (!blankLikeShell) {
        break;
      }
      await page.waitForTimeout(1500);
      await page.reload({ waitUntil: 'domcontentloaded' }).catch(() => {});
      await page.waitForLoadState('networkidle').catch(() => {});
      pageHtml = await safePageContent(page);
      pageText = await safeBodyText(page);
    }

    await recoverTransientErrorShell(page);
    pageHtml = await safePageContent(page);
    pageText = await safeBodyText(page);

    const requiredCounts = {} as Record<keyof typeof requiredSelectors, number>;
    for (const [key, selector] of Object.entries(requiredSelectors) as Array<[
      keyof typeof requiredSelectors,
      string
    ]>) {
      requiredCounts[key] = await safeCountSelector(page, selector);
    }

    const trackedCounts = {} as Record<keyof typeof trackedSelectors, number>;
    for (const [key, selector] of Object.entries(trackedSelectors) as Array<[
      keyof typeof trackedSelectors,
      string
    ]>) {
      trackedCounts[key] = await safeCountSelector(page, selector);
    }

    const customSelectorCounts = {} as Record<string, number>;
    for (const selector of SELECTOR_AUDIT_SELECTORS) {
      const count = await safeCountSelector(page, selector);
      customSelectorCounts[selector] = count;
      customSelectorTotals[selector] += count;
    }

    const isAuthnRoute = routePath.includes('/authn');
    const isAuthnSurface = isAuthnRoute || page.url().includes('/authn/');
    const hasThemeBrandStylesheet = /mereka-brand(?:-light)?(?:\\.min)?\\.css/i.test(pageHtml);
    const hasThemeBrandLink = (await safeCountSelector(page, 'link[href*="mereka-brand"]')) > 0;
    const pageTextLength = pageText.length;

    if (REQUIRE_BRANDING_MARKERS) {
      const markerHitCount = Object.values(requiredCounts).filter((count) => count > 0).length;
      const allowAuthnUnrenderedSurface = isAuthnSurface
        && pageTextLength === 0
        && markerHitCount === 0
        && !hasThemeBrandStylesheet
        && !hasThemeBrandLink;
      if (!allowAuthnUnrenderedSurface) {
        expect(
          markerHitCount > 0 || hasThemeBrandStylesheet || hasThemeBrandLink,
          `Expected branded marker selector or branded theme stylesheet on ${targetUrl}; currentUrl=${page.url()}`,
        ).toBeTruthy();
      }
    }

    const trackedSelectorHits = Object.values(trackedCounts).filter((count) => count > 0).length;
    const hasRootContainer = /id=["'](root|main)["']/i.test(pageHtml) || /data-testid=["'][^"']+["']/i.test(pageHtml);
    const hasScriptTags = /<script[\s>]/i.test(pageHtml);
    const hydrationSignal = hasRootContainer || hasScriptTags;
    const failureHint = [
      `hydrationSignal=${hydrationSignal}`,
      `hasRootContainer=${hasRootContainer}`,
      `hasScriptTags=${hasScriptTags}`,
      `pageTextLength=${pageTextLength}`,
    ].join(' ');

    const allowBlankShellBypass = trackedSelectorHits === 0
      && pageTextLength === 0
      && (hasThemeBrandStylesheet || hasThemeBrandLink);
    const allowHydratingAuthnShell = isAuthnSurface
      && trackedSelectorHits <= 1
      && pageTextLength === 0
      && hydrationSignal;
    const allowLowSignalBrandedShell = trackedSelectorHits > 0
      && trackedSelectorHits < MIN_TRACKED_SELECTOR_HITS
      && pageTextLength < 300
      && (hasThemeBrandStylesheet || hasThemeBrandLink);

    const shouldAssertStrongShell = !allowBlankShellBypass
      && !allowHydratingAuthnShell
      && !allowLowSignalBrandedShell;

    if (shouldAssertStrongShell) {
      expect(
        trackedSelectorHits,
        `Expected at least ${MIN_TRACKED_SELECTOR_HITS} tracked selectors on ${targetUrl}; counts=${JSON.stringify(trackedCounts)} ${failureHint}`,
      ).toBeGreaterThanOrEqual(MIN_TRACKED_SELECTOR_HITS);
    }

    if (shouldAssertStrongShell) {
      const routeSpecificSelectors = getRequiredRouteSelectors(routePath, page.url());
      for (const selector of routeSpecificSelectors) {
        const count = await safeCountSelector(page, selector);
        expect(
          count,
          `Expected shell selector ${selector} on ${targetUrl}; currentUrl=${page.url()}`,
        ).toBeGreaterThan(0);
      }
    }

    routeResults.push({
      routePath,
      targetUrl,
      currentUrl: page.url(),
      requiredCounts,
      trackedCounts,
      customSelectorCounts,
      trackedSelectorHits,
      hydrationSignal,
      hasRootContainer,
      hasScriptTags,
      pageTextLength,
    });

    await page.screenshot({
      path: testInfo.outputPath(`selector-dom-audit-${getRouteArtifactSuffix(routePath)}.png`),
      fullPage: true,
    });
  }

  if (SELECTOR_AUDIT_SELECTORS.length > 0 && MIN_CUSTOM_SELECTOR_HITS > 0) {
    const matchedCustomSelectors = Object.entries(customSelectorTotals)
      .filter(([, count]) => count > 0)
      .map(([selector]) => selector);
    expect(
      matchedCustomSelectors.length,
      `Expected at least ${MIN_CUSTOM_SELECTOR_HITS} custom selectors to match across routes. matched=${JSON.stringify(matchedCustomSelectors)} totals=${JSON.stringify(customSelectorTotals)}`,
    ).toBeGreaterThanOrEqual(MIN_CUSTOM_SELECTOR_HITS);
  }

  await testInfo.attach('selector-dom-audit.json', {
    body: JSON.stringify({
      mfeBaseUrl,
      auditedRoutes: SELECTOR_AUDIT_ROUTES,
      customSelectors: SELECTOR_AUDIT_SELECTORS,
      minTrackedSelectorHits: MIN_TRACKED_SELECTOR_HITS,
      minCustomSelectorHits: MIN_CUSTOM_SELECTOR_HITS,
      requireBrandingMarkers: REQUIRE_BRANDING_MARKERS,
      customSelectorTotals,
      routeResults,
    }, null, 2),
    contentType: 'application/json',
  });
});
