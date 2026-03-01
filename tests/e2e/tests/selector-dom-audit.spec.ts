import { test, expect, type Page } from '@playwright/test';

const REQUIRE_BRANDING_MARKERS = process.env.REQUIRE_BRANDING_MARKERS !== '0';
const MIN_TRACKED_SELECTOR_HITS = Number.parseInt(process.env.MIN_TRACKED_SELECTOR_HITS ?? '3', 10);
const MIN_CUSTOM_SELECTOR_HITS = Number.parseInt(process.env.MIN_CUSTOM_SELECTOR_HITS ?? '0', 10);
const SELECTOR_AUDIT_PATH = (process.env.SELECTOR_AUDIT_PATH ?? '/authn/login').trim() || '/authn/login';
const SELECTOR_AUDIT_ROUTES = parseCsv(process.env.SELECTOR_AUDIT_ROUTES ?? SELECTOR_AUDIT_PATH)
  .map(normalizeRoutePath);
const SELECTOR_AUDIT_SELECTORS = parseCsv(process.env.SELECTOR_AUDIT_SELECTORS ?? '');

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const parsed = new URL(lmsBaseUrl);
  const host = parsed.hostname.startsWith('apps.') ? parsed.hostname : `apps.${parsed.hostname}`;
  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${host}${port}`;
}

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

test('runtime selector DOM audit on configured MFE surfaces', async ({ page, baseURL }, testInfo) => {
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
    const pageHtml = await page.content();
    const pageText = (await page.locator('body').innerText().catch(() => '')).trim();

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

    if (REQUIRE_BRANDING_MARKERS) {
      const isAuthnRoute = routePath.includes('/authn');
      if (isAuthnRoute) {
        expect(
          requiredCounts.authnBranding,
          `Expected authn branding marker on ${targetUrl}; currentUrl=${page.url()}`,
        ).toBeGreaterThan(0);
      } else {
        const markerHitCount = Object.values(requiredCounts).filter((count) => count > 0).length;
        expect(
          markerHitCount,
          `Expected at least one branded marker selector on ${targetUrl}; currentUrl=${page.url()}`,
        ).toBeGreaterThan(0);
      }
    }

    const trackedSelectorHits = Object.values(trackedCounts).filter((count) => count > 0).length;
    const hasRootContainer = /id=["'](root|main)["']/i.test(pageHtml) || /data-testid=["'][^"']+["']/i.test(pageHtml);
    const hasScriptTags = /<script[\s>]/i.test(pageHtml);
    const hydrationSignal = hasRootContainer || hasScriptTags;
    const pageTextLength = pageText.length;
    const failureHint = [
      `hydrationSignal=${hydrationSignal}`,
      `hasRootContainer=${hasRootContainer}`,
      `hasScriptTags=${hasScriptTags}`,
      `pageTextLength=${pageTextLength}`,
    ].join(' ');

    expect(
      trackedSelectorHits,
      `Expected at least ${MIN_TRACKED_SELECTOR_HITS} tracked selectors on ${targetUrl}; counts=${JSON.stringify(trackedCounts)} ${failureHint}`,
    ).toBeGreaterThanOrEqual(MIN_TRACKED_SELECTOR_HITS);

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
