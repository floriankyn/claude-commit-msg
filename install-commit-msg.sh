#!/usr/bin/env sh
# install-commit-msg.sh — installs the AI-powered commit message generator
# Pure POSIX sh. No bashisms.

set -eu

# --- Check dependencies -----------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
    echo "Error: 'claude' CLI not found. Install Claude Code first:" >&2
    echo "  npm install -g @anthropic-ai/claude-code" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Error: 'git' not found in PATH." >&2
    exit 1
fi

# --- Install location -------------------------------------------------------
BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/commit-msg"

mkdir -p "$BIN_DIR"

# --- Write the script (single-quoted heredoc: no interpolation here) --------
cat > "$TARGET" << 'COMMIT_MSG'
#!/usr/bin/env sh
# commit-msg — generate a Conventional Commit message from the staged diff
# using the Claude CLI. Pure POSIX sh.

set -eu

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: commit-msg [OPTIONS]

Generate an AI commit message from staged changes (Conventional Commits).

Options:
  -d, --dry-run   Print the suggested message without committing
  -h, --help      Show this help

Flow:
  Stage your changes (git add ...), run commit-msg, then choose:
  [Y]es / [e]dit / [r]egen / [n]o
EOF
}

# --- Parse args ---------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        -d|--dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

# --- Guards -------------------------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi

if git diff --staged --quiet; then
    echo "Error: no staged changes. Stage files with 'git add' first." >&2
    exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "Error: 'claude' CLI not found in PATH." >&2
    exit 1
fi

# --- Collect context ----------------------------------------------------
REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git rev-parse --abbrev-ref HEAD)
FILES=$(git diff --staged --name-only)
COUNT=$(printf '%s\n' "$FILES" | wc -l | tr -d ' ')
STAT=$(git diff --staged --stat)
DIFF=$(git diff --staged | head -n 200)

# --- Build prompt -------------------------------------------------------
PROMPT="Write a git commit message for this diff.
Repo: $REPO | Branch: $BRANCH | $COUNT files:
$FILES
---
$STAT
$DIFF
---
Use Conventional Commits: <type>(<scope>): <subject>
Types: feat fix docs style refactor perf test chore ci build revert
Max 72 chars, imperative mood. Short body only if needed.
Reply with the commit message only. No markdown, no fences."

# --- Call Claude --------------------------------------------------------
echo "Generating commit message..." >&2
MSG=$(printf '%s' "$PROMPT" | claude -p --model claude-haiku-4-5 2>&1) || {
    echo "Error: claude CLI failed:" >&2
    printf '%s\n' "$MSG" >&2
    exit 1
}

# Strip backtick fences if the model added them anyway
MSG=$(printf '%s\n' "$MSG" | grep -v '^```' || true)

if [ -z "$MSG" ]; then
    echo "Error: empty response from claude." >&2
    exit 1
fi

# --- Show + confirm -----------------------------------------------------
echo ""
echo "Suggested commit message:"
echo "-------------------------------------------"
printf '%s\n' "$MSG"
echo "-------------------------------------------"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry run — nothing committed)"
    exit 0
fi

printf '[Y]es / [e]dit / [r]egen / [n]o ? '
read -r ANSWER
ANSWER=$(printf '%s' "$ANSWER" | tr '[:upper:]' '[:lower:]')

case "$ANSWER" in
    y|yes|"")
        git commit -m "$MSG"
        ;;
    e|edit)
        TMP=$(mktemp /tmp/commit-msg.XXXXXX)
        printf '%s\n' "$MSG" > "$TMP"
        printf '\n# Edit the commit message above. Lines starting with # are ignored.\n' >> "$TMP"
        ED="${GIT_EDITOR:-${VISUAL:-${EDITOR:-vi}}}"
        $ED "$TMP"
        FINAL=$(grep -v '^#' "$TMP")
        rm -f "$TMP"
        if [ -z "$FINAL" ]; then
            echo "Empty message, aborting." >&2
            exit 1
        fi
        git commit -m "$FINAL"
        ;;
    r|regen)
        exec commit-msg "$@"
        ;;
    n|no|*)
        echo "Aborted. Staged changes left intact."
        exit 0
        ;;
esac
COMMIT_MSG

chmod +x "$TARGET"
echo "Installed: $TARGET"

# --- PATH warning -------------------------------------------------------------
case ":$PATH:" in
    *":$BIN_DIR:"*)
        echo "Ready. Stage changes and run: commit-msg"
        ;;
    *)
        echo "Warning: $BIN_DIR is not in your PATH." >&2
        echo "Add this to your shell profile (~/.profile, ~/.bashrc, ~/.zshrc):" >&2
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
        ;;
esac