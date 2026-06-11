# commit-msg — AI-Powered Git Commit Messages

Generate [Conventional Commits](https://www.conventionalcommits.org/) messages from your staged diff using the Claude CLI. Two ways to use it: a standalone shell command, or a Claude Code slash command.

## Requirements

- `git`
- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI (`claude` in PATH):
  ```sh
  npm install -g @anthropic-ai/claude-code
  ```

---

## Option 1 — Shell command (`commit-msg`)

### Install

```sh
sh install-commit-msg.sh
```

This installs `~/.local/bin/commit-msg` (pure POSIX sh, works in bash/zsh/dash/ash). If `~/.local/bin` isn't in your PATH, the installer will tell you what to add.

### Usage

```sh
git add .
commit-msg
```

Output:

```
Suggested commit message:
-------------------------------------------
feat(pipeline): add PM2 restart step to deploy stage
-------------------------------------------
[Y]es / [e]dit / [r]egen / [n]o ?
```

- **Y** (or Enter) — commit with the suggested message
- **e** — open the message in your editor (`$GIT_EDITOR` → `$VISUAL` → `$EDITOR` → `vi`), `#` lines are stripped, then commit
- **r** — regenerate a new suggestion
- **n** — abort; staged changes are left intact

### Flags

| Flag | Description |
|------|-------------|
| `-d`, `--dry-run` | Print the suggested message without committing |
| `-h`, `--help` | Show help |

### How it works

The script collects repo name, branch, staged file list, diff stat, and the first 200 lines of `git diff --staged`, then asks `claude -p --model claude-haiku-4-5` for a Conventional Commit message. Haiku keeps it fast and cheap.

---

## Option 2 — Claude Code slash command (`/commit`)

### Install

Copy the command file into your project (or `~/.claude/commands/` for global use):

```sh
mkdir -p .claude/commands
cp commit.md .claude/commands/commit.md
```

### Usage

Inside a Claude Code session:

```
git add .   # in your terminal, or ask Claude to review what to stage
/commit
```

Claude reads the staged diff, proposes a Conventional Commit message, and asks **[Y]es / [e]dit / [n]o** before committing. It will never commit, stage, amend, or push without your confirmation.

---

## Commit message rules (both paths)

- Format: `<type>(<scope>): <subject>`
- Types: `feat` `fix` `docs` `style` `refactor` `perf` `test` `chore` `ci` `build` `revert`
- Subject ≤ 72 chars, imperative mood
- Short body only when the subject alone isn't enough

## Troubleshooting

- **"claude CLI not found"** — install Claude Code and make sure `claude` is in PATH.
- **"no staged changes"** — run `git add` first; both tools refuse to commit an empty index.
- **Garbage in the message** — the script strips ``` fences automatically; use **r** to regenerate if the model misbehaves.