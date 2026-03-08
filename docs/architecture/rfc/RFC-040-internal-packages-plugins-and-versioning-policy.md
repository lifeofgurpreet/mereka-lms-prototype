# RFC-040 Internal Packages Plugins And Versioning Policy

Status: proposed
Source record: `docs/adr/040-internal-packages-plugins-and-versioning-policy.md`

## Intent

Define semver and compatibility policy for internal packages and plugins.

## Why This Is Still An RFC

The platform needs this rule set, but it should become accepted only once the compatibility contract is wired cleanly into release tooling.

## Candidate Invariants

- Breaking changes require major version increments.
- Compatibility ranges are declared.
- Internal plugin stability is explicit, not implied.
