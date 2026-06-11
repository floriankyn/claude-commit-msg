# commit-msg

AI-powered commit message generator for the terminal, built on [Claude Code](https://claude.ai/code).

Run `commit-msg` after `git add` and get a ready-to-use [Conventional Commit](https://www.conventionalcommits.org/) message — analyzed from your actual staged diff. Accept it, edit it, regenerate it, or abort.

```
git add .
commit-msg
```

```
Analyzing staged diff with Claude Code...

------------------------------------------------------------------------
Suggested commit message:

feat(auth): add NextAuth v5 with DrizzleAdapter and ABAC permission guards

Integrates credentials, Google, Apple, and Microsoft OAuth providers.
Adds DB-driven page:* and feature:* permission checks with Drizzle ORM schema.
------------------------------------------------------------------------

What do you want to do?
  [Y] Accept and commit
  [e] Edit before committing
  [r] Regenerate (ask Claude again)
  [n] Abort

Choice [Y/e/r/n]:
```

## Requirements

- [Claude Code](https://claude.ai/code) installed and logged in
- `git`
- macOS or Linux

## Installation

```bash
bash install-commit-msg.sh
```

This installs the `commit-msg` command to `~/.local/bin/`.

If that directory is not in your PATH yet, add this to your `~/.zshrc` or `~/.bashrc` and restart your terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
git add <files>
commit-msg              # analyze → suggest → confirm
commit-msg --dry-run    # print suggestion only, do not commit
commit-msg --help       # show help
```

## How it works

1. Reads your staged diff with `git diff --staged`
2. Sends the diff (up to 800 lines) along with repo name, branch, and changed file list to Claude
3. Claude generates a Conventional Commit message following these rules:
   - `<type>(<scope>): <subject>` format, subject max 72 chars
   - Optional body for non-trivial changes
   - Scope inferred from the changed files
4. You confirm, edit, regenerate, or abort — nothing is committed without your approval

Uses **Claude Haiku** (fast and cheap) since commit message generation doesn't need a frontier model.

## Conventional Commit types

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Refactor without feature/fix |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system or dependencies |
| `ci` | CI/CD configuration |
| `chore` | Maintenance tasks |
| `revert` | Revert a previous commit |

## License

MIT
# claude-commit-msg
