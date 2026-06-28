---
name: gh-cli
description: >
  GitHub CLI (gh) communication guide. Use when user asks to manage issues, pull requests,
  repos, releases, workflows, or search GitHub. Covers gh auth, issue/PR CRUD, repo ops,
  workflow runs, and common patterns. Triggers: "create issue", "list PRs", "gh pr",
  "gh issue", "GitHub CLI", "gh workflow".
---

# GitHub CLI (gh) Communication

## When to Use
- Create, list, view, edit issues/PRs
- Query repo info, search code/issues/PRs
- Manage workflow runs, view CI status
- Create releases, manage labels
- Any GitHub operation from the terminal

## Auth Check
```bash
gh auth status
```
If not authenticated: `gh auth login`

## Issues

```bash
# List
gh issue list --repo owner/repo --state open --limit 50
gh issue list --repo owner/repo --label "bug" --assignee @me

# View
gh issue view <number> --repo owner/repo

# Create
gh issue create --repo owner/repo --title "Title" --body "Description"

# Close/reopen
gh issue close <number> --repo owner/repo
gh issue reopen <number> --repo owner/repo

# Comment
gh issue comment <number> --repo owner/repo --body "Comment text"
```

## Pull Requests

```bash
# List
gh pr list --repo owner/repo --state open
gh pr list --repo owner/repo --label "needs-review"

# View
gh pr view <number> --repo owner/repo
gh pr view --repo owner/repo --json title,state,reviews,statusCheckRollup

# Create
gh pr create --repo owner/repo --title "Title" --body "Description" --base main

# Review
gh pr review <number> --repo owner/repo --approve
gh pr review <number> --repo owner/repo --request-changes --body "Reason"

# Check CI
gh pr checks <number> --repo owner/repo

# Merge
gh pr merge <number> --repo owner/repo --squash

# Diff
gh pr diff <number> --repo owner/repo
```

## Repo Operations

```bash
# Clone
gh repo clone owner/repo

# Fork
gh repo fork owner/repo --clone

# View
gh repo view owner/repo --json name,description,defaultBranch,stargazerCount
```

## Search

```bash
gh search issues "query" --repo owner/repo
gh search prs "query" --repo owner/repo
gh search repos "topic:python stars:>100"
```

## Workflows & CI

```bash
# List workflows
gh workflow list --repo owner/repo

# Run workflow
gh workflow run <name> --repo owner/repo

# View runs
gh run list --repo owner/repo --limit 10
gh run view <run-id> --repo owner/repo --log
```

## Release

```bash
gh release create v1.0.0 --repo owner/repo --title "v1.0.0" --notes "Release notes"
gh release list --repo owner/repo
```

## Common Patterns

**Batch close issues:** `gh issue list --repo owner/repo --label stale --json number -q '.[].number' | xargs -I{} gh issue close {} --repo owner/repo`

**Create issue from template:** `gh issue create --repo owner/repo --template bug_report.md`

**Check PR CI before merge:** `gh pr checks <number> --repo owner/repo --watch`

**List PRs merged since tag:** `gh pr list --repo owner/repo --state merged --search "merged:>YYYY-MM-DD"`

## Exit Codes
- `0`: success
- `1`: command failed (bad args, not found)
- `4`: authentication required

## Tips
- Use `--repo owner/repo` to avoid ambiguity when not in repo dir
- Use `--json` + `--jq` or `-q` for scripting: `gh pr list --json title,number -q '.[].title'`
- `gh api` for any REST/GraphQL endpoint not covered by subcommands
