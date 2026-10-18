# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI.
Run it inside this clone so it resolves the repository from `origin`.

## Issue operations

- Create: `gh issue create --title "..." --body-file <file>`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body-file <file>`
- Label: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

When a skill says "publish to the issue tracker," create a GitHub issue.
When it says "fetch the relevant ticket," read the issue and its comments.

## Pull requests as a triage surface

**PRs as a request surface: no.** Set this to `yes` if external PRs
should enter the triage queue. When enabled, use `gh pr view`, `gh pr diff`,
`gh pr list`, `gh pr comment`, `gh pr edit`, and `gh pr close` for PRs.
GitHub shares issue and PR numbers; resolve an ambiguous number by
checking `gh pr view` and then `gh issue view`.

## Wayfinding

For `/wayfinder`, create one map issue labelled `wayfinder:map` and child
issues labelled `wayfinder:<type>` (`research`, `prototype`, `grilling`,
or `task`). Link children as GitHub sub-issues where available; otherwise
use a task list in the map and `Part of #<map>` in each child.

Represent blockers with GitHub issue dependencies where available;
otherwise add `Blocked by: #<n>` to the child's body. The frontier is the
first open, unassigned child in map order with no open blockers. Claim it
with `gh issue edit <n> --add-assignee @me`. To resolve it, comment with
the answer, close it, and add a brief linked decision to the map.
