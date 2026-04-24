import { test, expect } from '@playwright/test';
import { getMfeBaseUrl } from '../support/urls';

type TenantPalette = {
  primary: string;
  secondary: string;
  accent: string;
  textOnPrimary: string;
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

const TENANT_PALETTE_ALIAS_SOURCE: Record<keyof typeof TENANT_PALETTE_CSS_VARIABLES, keyof TenantPalette> = {
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

function normalizePaletteValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

test('tenant palette bridge applies runtime config values on non-default tenant shell', async ({ page, baseURL }) => {
  const expectedSiteName = (process.env.EXPECTED_SITE_NAME ?? '').trim();
  const mfeBaseUrl = getMfeBaseUrl(baseURL!);
  const configResponse = await page.request.get(`${mfeBaseUrl}/api/mfe_config/v1`, { timeout: 15000 });

  expect(configResponse.status()).toBeGreaterThanOrEqual(200);
  expect(configResponse.status()).toBeLessThan(500);

  const configPayload = await configResponse.json().catch(() => ({} as Record<string, unknown>));
  const siteName = normalizePaletteValue(configPayload.SITE_NAME);

  expect(siteName, `Expected SITE_NAME in ${mfeBaseUrl}/api/mfe_config/v1`).toBeTruthy();
  if (expectedSiteName) {
    expect(siteName).toBe(expectedSiteName);
  }

  const expectedPalette: TenantPalette = {
    primary: normalizePaletteValue(configPayload.PRIMARY_COLOR),
    secondary: normalizePaletteValue(configPayload.SECONDARY_COLOR),
    accent: normalizePaletteValue(configPayload.ACCENT_COLOR),
    textOnPrimary: normalizePaletteValue(configPayload.TEXT_ON_PRIMARY),
  };

  for (const [key, value] of Object.entries(expectedPalette)) {
    expect(value, `Expected ${key} palette value in ${mfeBaseUrl}/api/mfe_config/v1`).toBeTruthy();
  }

  const response = await page.goto(`${mfeBaseUrl}/authn/login`, { waitUntil: 'domcontentloaded' });
  expect(response?.status() ?? 0).toBeGreaterThan(0);
  expect(response?.status() ?? 500).toBeLessThan(500);
  await page.waitForLoadState('networkidle').catch(() => {});

  const expectedCssPalette = Object.fromEntries(
    Object.keys(TENANT_PALETTE_CSS_VARIABLES).map((key) => {
      const typedKey = key as keyof typeof TENANT_PALETTE_CSS_VARIABLES;
      return [typedKey, expectedPalette[TENANT_PALETTE_ALIAS_SOURCE[typedKey]]];
    }),
  );

  await expect
    .poll(
      async () => page.evaluate((cssVariables) => {
        const rootStyle = getComputedStyle(document.documentElement);
        return Object.fromEntries(
          Object.entries(cssVariables).map(([key, cssVariable]) => [
            key,
            rootStyle.getPropertyValue(cssVariable).trim(),
          ]),
        );
      }, TENANT_PALETTE_CSS_VARIABLES),
      {
        timeout: 15_000,
        message: `Expected tenant palette CSS variables to converge on ${mfeBaseUrl}`,
      },
    )
    .toEqual(expectedCssPalette);
});
