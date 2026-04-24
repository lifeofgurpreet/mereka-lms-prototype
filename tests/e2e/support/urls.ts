export function getMfeBaseUrl(lmsBaseUrl: string): string {
  const parsed = new URL(lmsBaseUrl);
  let host: string;

  // Primary staging uses staging.apps.*. Secondary staging tenants still use
  // apps.staging.* hostnames, so only rewrite LMS hosts that start with staging.
  if (parsed.hostname.startsWith('apps.') || parsed.hostname.startsWith('staging.apps.')) {
    host = parsed.hostname;
  } else if (parsed.hostname.startsWith('staging.')) {
    host = parsed.hostname.replace(/^staging\./, 'staging.apps.');
  } else {
    host = `apps.${parsed.hostname}`;
  }

  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${host}${port}`;
}
