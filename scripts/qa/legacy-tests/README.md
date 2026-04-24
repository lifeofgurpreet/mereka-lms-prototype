# Legacy Test Scripts

**WARNING**: These scripts contain hardcoded secrets and are deprecated.

These are legacy API test scripts for MCT and SOF integrations. They were moved from the repository root during cleanup.

## Files

- `test-mct-api.mjs` - MCT API test harness
- `test-mct-direct.mjs` - MCT direct authentication test
- `test-no-client-type.mjs` - Client type test
- `test-sof-api.mjs` - SOF API test harness
- `test-sof-self.mjs` - SOF self-service test
- `test-v3.mjs` - V3 API test

## Security Note

These files contain hardcoded credentials and should NOT be used. They are preserved for historical reference only. Use proper secrets management via Infisical/ExternalSecrets for any new testing.

## Action Items

- [ ] Rewrite tests using environment variables
- [ ] Move to proper test framework (pytest/vitest)
- [ ] Delete after migration complete
