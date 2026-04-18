---
description: Conventions for GitHub Actions workflow files
paths: ['.github/workflows/*.yaml']
---

# GitHub Actions Conventions

## File Extension

- Use `.yaml` (never `.yml`)

## File Naming

- Use action-based names (verb + noun)
  - Good: `run-ci.yaml`, `deploy-production.yaml`, `check-lint.yaml`
  - Bad: `ci.yaml`, `production.yaml`, `lint.yaml`

## Action Version Pinning

- Pin actions by full commit SHA (never use tags directly)

```yaml
# Good
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683

# Bad
- uses: actions/checkout@v4
```
