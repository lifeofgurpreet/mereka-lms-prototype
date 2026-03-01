import { test, expect, type Page } from '@playwright/test';

const REQUIRE_BRANDING_MARKERS = process.env.REQUIRE_BRANDING_MARKERS !== '0';
const MIN_TRACKED_SELECTOR_HITS = Number.parseInt(process.env.MIN_TRACKED_SELECTOR_HITS ?? '3', 10);
const SELECTOR_AUDIT_PATH = (process.env.SELECTOR_AUDIT_PATH ?? '/authn/login').trim() || '/authn/login';

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const parsed = new URL(lmsBaseUrl);
  const host = parsed.hostname.startsWith('apps.') ? parsed.hostname : `apps.${parsed.hostname}`;
  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${host}${port}`;
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

test('runtime selector DOM audit on authn surface', async ({ page, baseURL }, testInfo) => {
  const mfeBaseUrl = getMfeBaseUrl(baseURL!);
  const normalizedPath = SELECTOR_AUDIT_PATH.startsWith('/') ? SELECTOR_AUDIT_PATH : `/${SELECTOR_AUDIT_PATH}`;
  const targetUrl = `${mfeBaseUrl}${normalizedPath}`;

  const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
  expect(response?.status() ?? 0).toBeGreaterThan(0);
  expect(response?.status() ?? 500).toBeLessThan(500);

  await page.waitForLoadState('networkidle').catch(() => {});

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

  if (REQUIRE_BRANDING_MARKERS) {
    for (const [key, count] of Object.entries(requiredCounts)) {
      expect(count, `Expected required marker selector "${key}" on ${targetUrl}; currentUrl=${page.url()}`).toBeGreaterThan(0);
    }
  }

  const trackedSelectorHits = Object.values(trackedCounts).filter((count) => count > 0).length;
  expect(
    trackedSelectorHits,
    `Expected at least ${MIN_TRACKED_SELECTOR_HITS} tracked selectors on ${targetUrl}; counts=${JSON.stringify(trackedCounts)}`,
  ).toBeGreaterThanOrEqual(MIN_TRACKED_SELECTOR_HITS);

  await testInfo.attach('selector-dom-audit.json', {
    body: JSON.stringify({
      targetUrl,
      currentUrl: page.url(),
      requiredCounts,
      trackedCounts,
      trackedSelectorHits,
      minTrackedSelectorHits: MIN_TRACKED_SELECTOR_HITS,
      requireBrandingMarkers: REQUIRE_BRANDING_MARKERS,
    }, null, 2),
    contentType: 'application/json',
  });

  await page.screenshot({
    path: testInfo.outputPath('selector-dom-audit.png'),
    fullPage: true,
  });
});
