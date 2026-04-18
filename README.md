# my-claude-code

Personal Claude Code configuration — skills, agents, rules, and hooks used across projects and at the user scope.

## Structure

```
.claude/
├── skills/          # Slash command skills
├── agents/          # Subagent definitions
├── rules/           # Always-on coding conventions and style rules
├── hooks/           # Shell scripts triggered by Claude Code events
└── settings.json    # Permissions and hook wiring
.github/
└── workflows/       # CI: Markdown lint, Actions lint
.markdownlint.jsonc  # Markdownlint config (v23+)
CLAUDE.md            # Global instructions loaded in every session
```

## Skills

| Skill                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `/commit`                | Conventional Commits message in Japanese               |
| `/create-pr-description` | Japanese PR title and description from branch commits  |
| `/create-adr`            | Architecture Decision Record                           |
| `/github-workflow`       | Interactive GitHub Actions workflow generator          |
| `/investigating-code`    | Code behavior investigation with reviewer verification |
| `/clean-claude-code`     | Interactive cleanup of unused files under `~/.claude/` |
| `/adopt-technology`      | Evaluate and adopt a new library or tool               |
| `/capture-feedback`      | Capture user corrections and save to memory            |
| `/analyze-rejections`    | Analyze rejection patterns from recorded feedback      |

## Agents

| Agent                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `investigation-reviewer` | Verifies investigation results against primary sources |

## Rules

| Rule file             | Scope                                            |
| --------------------- | ------------------------------------------------ |
| `claude-config.md`    | Language policy for `.claude/` config files      |
| `coding-standards.md` | Code quality, naming, error handling conventions |
| `github-actions.md`   | Workflow file extension, naming, SHA pinning     |
