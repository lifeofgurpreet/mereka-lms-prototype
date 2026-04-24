---
name: layer-triage
description: Identify the owner layer before touching anything. Use when investigating a bug, incident, or unexpected behavior in the Mereka LMS platform. Forces layer-first diagnosis instead of tool-first guessing.
---

# Layer Triage

You are triaging a problem in the Mereka LMS platform. Before writing any code or running any fix, you MUST identify the owner layer.

## The Six Layers

| Layer | Question | Typical owner files |
|---|---|---|
| Source | What should exist? | `deploy/k8s/tenancy/tenant-registry.yaml`, `specs/**`, `deploy/k8s/base/**` |
| Build/render | What actually gets built? | `infrastructure/tutor/**`, build workflows, `Dockerfile` patches |
| Promotion | What should move to envs? | release bundle, `scripts/release/**`, promote-image workflow |
| Realization | What is applied live? | Argo-managed overlays (bbi-infrastructure), live manifests |
| Runtime | What users see? | live HTTP/browser behavior, served assets |
| Proof | Are checks trustworthy? | `scripts/qa/**`, `verification/**`, browser canaries |

## Mandatory Steps

1. **Name the broken surface**: environment + tenant + host + route
2. **Collect runtime evidence**: HTTP status, response body, redirect chain, screenshot
3. **Decide owner layer** using the table above
4. **Fill the incident table** before patching:

```
Broken surface:
Owner layer:
Source authority file:
Rendered/build artifact:
Realized/live artifact:
Current proof artifact:
Regression guard to add:
```

5. **Patch only the owning layer first**
6. **Add a regression guard** at the layer where the bug escaped

## Decision Tree

- Live user-visible break → runtime or realization layer
- Build artifact mismatch → build/render layer
- Wrong thing promoted → promotion layer
- Source contract wrong → source layer
- Verifier green while runtime red → proof layer (verifier contract must be corrected)
- Source fixed but runtime still broken → inspect build/render path first

## Never Do

- Do NOT start by editing docs or CI when runtime is broken
- Do NOT patch generated artifacts without fixing the generator
- Do NOT rerun proof against a known-unpatched live bundle
- Do NOT treat branch/merge truth as proved truth
- Do NOT promote from a dirty worktree

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: none (this is the universal root skill)
- **Recommended**: none
- **Required by**: all other skills

## References

- [PLATFORM_AUTHORITY_MAP.md](docs/architecture/PLATFORM_AUTHORITY_MAP.md)
- [AGENT_EXECUTION_WORKFLOW.md](docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md)
