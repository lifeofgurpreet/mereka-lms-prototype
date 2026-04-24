import { expect, test } from '@playwright/test';
import { getMfeBaseUrl } from '../support/urls';

test.describe('MFE URL derivation', () => {
  test('derives production and dev apps hosts by prefixing apps', () => {
    expect(getMfeBaseUrl('https://academyv2.mereka.io')).toBe('https://apps.academyv2.mereka.io');
    expect(getMfeBaseUrl('https://academyv2.mereka.dev')).toBe('https://apps.academyv2.mereka.dev');
  });

  test('derives primary staging MFE host as staging.apps, not apps.staging', () => {
    expect(getMfeBaseUrl('https://staging.academyv2.mereka.io')).toBe(
      'https://staging.apps.academyv2.mereka.io',
    );
  });

  test('preserves explicit apps hosts and ports', () => {
    expect(getMfeBaseUrl('http://apps.localhost:8002')).toBe('http://apps.localhost:8002');
    expect(getMfeBaseUrl('https://staging.apps.academyv2.mereka.io')).toBe(
      'https://staging.apps.academyv2.mereka.io',
    );
  });
});
