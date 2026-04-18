---
name: github-workflow
description: Interactively create GitHub Actions workflow files. Use when `/github-workflow` is invoked. Gathers requirements for triggers, branches, checks, Node.js version, and generates the workflow.
---

# GitHub Actions Workflow Creation

## Steps

### Step 1: Gather Requirements

Ask the following questions one at a time. Present as multiple choice and wait for the user's answer before proceeding.

1. **Trigger**: push / pull_request / schedule / workflow_dispatch / other
2. **Target branches**: all branches / main only / specific branches
3. **Steps to run**: read `package.json` `scripts` and suggest candidates
   - Static checks (lint, format, typecheck, knip, depcruise, etc.)
   - Tests (test, test:coverage, etc.)
   - Build (build, etc.)
   - Other custom steps
4. **Node.js version**: read `.mise.toml` or `package.json` `engines` and suggest
5. **Job structure**: single job / parallel jobs

### Step 2: Generate Workflow

Generate the workflow file based on the gathered requirements.

#### Conventions

If `.claude/rules/github-actions.md` exists in the project, follow those conventions. Otherwise, apply these defaults:

- File extension: `.yaml` (never `.yml`)
- File name: action-based (verb + noun: `run-ci.yaml`, `deploy-production.yaml`)
- Action versions: pin by full commit SHA with version tag as inline comment

#### File Location

`.github/workflows/<action-based-name>.yaml`

### Step 3: Review and Commit

1. Present the generated workflow to the user
2. Create the file once the user approves
3. Use the `/commit` skill to commit
