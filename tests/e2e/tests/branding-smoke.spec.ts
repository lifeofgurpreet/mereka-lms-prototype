import { test, expect } from '@playwright/test';

const MFE_ROUTES = [
  { label: 'authn-login', path: '/authn/login' },
  { label: 'learner-dashboard', path: '/learner-dashboard/' },
  { label: 'account-settings', path: '/account/settings' },
];

function getMfeBaseUrl(lmsBaseUrl: string): string {
  const baseHost = new URL(lmsBaseUrl).hostname;
  return `https://apps.${baseHost}`;
}

test.describe('Branding smoke', () => {
  for (const route of MFE_ROUTES) {
    test(`theme assets + token bridge present on ${route.label}`, async ({ page, baseURL }, testInfo) => {
      const mfeBaseUrl = getMfeBaseUrl(baseURL!);
      const targetUrl = `${mfeBaseUrl}${route.path}`;

      const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
      expect(response?.status() ?? 0).toBeGreaterThan(0);
      expect(response?.status() ?? 500).toBeLessThan(500);

      await page.waitForLoadState('networkidle').catch(() => {});
      const html = response ? await response.text() : '';
      expect(html).toContain('PARAGON_THEME');
      expect(html).toMatch(/paragon-theme-core\.[a-z0-9]+\.css/i);
      expect(html).toMatch(/brand-theme-core\.[a-z0-9]+\.css/i);

      await page.screenshot({
        path: testInfo.outputPath(`${route.label}.png`),
        fullPage: true,
      });
    });
  }
});
