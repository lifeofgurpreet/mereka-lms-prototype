# Docs Templates
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains reusable templates and snippets used by the documentation operating system. Start here when you need a standard shape for a docs artifact rather than freeform prose.

## Start here

| If you need to... | Read this first |
|---|---|
| Add a standard warning or review section | `README_WARNING_SNIPPET.md` or `AUTH_PR_SECTION.md` |
| Write a new evidence pack | `EVIDENCE_SCHEMA.md` |
| Write a postmortem | `POST_MORTEM_TEMPLATE.md` |
| Write a deployment/release note | `RELEASE_DEPLOYMENT_TEMPLATE.md` |

## Common contributor paths

| Task | Use this | Do this next |
|---|---|---|
| Start a new evidence pack | `EVIDENCE_SCHEMA.md` | Validate the final pack against `docs/guides/standards/EVIDENCE_PACK_STANDARD.md` |
| Write a release note or deployment note | `RELEASE_DEPLOYMENT_TEMPLATE.md` | Publish the final active note under `docs/status/**` or attach it to `docs/evidence/**` if it is proof |
| Write a postmortem | `POST_MORTEM_TEMPLATE.md` | File the finished postmortem under the active status surface, not in `docs/meta/**` |
| Add a reusable PR or warning snippet | `AUTH_PR_SECTION.md` or `README_WARNING_SNIPPET.md` | Keep the snippet generic and reusable instead of embedding one-off incident context |

## Use this directory for

- PR sections and warning snippets
- evidence and postmortem templates
- release/deployment template material

## Do not use this directory for

- active reports or status notes
- accepted decisions
- runtime operator procedures

## What this root is not

- Not the authority for writing standards. Use `docs/guides/standards/**`.
- Not the place for active program tracking. Use `docs/meta/docs-program/**`.
- Not the place for reusable runtime checklists. Use `docs/ops/**`.

## Review standard

- A template here should make a canonical destination easier to write, not create a second live document.
- A template should stay generic enough for repeated use across teams and waves.
- If a file starts to accumulate process decisions rather than reusable structure, move that guidance into `docs/guides/standards/**` or `docs/meta/docs-program/**`.
