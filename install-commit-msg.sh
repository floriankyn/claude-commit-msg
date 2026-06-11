#!/usr/bin/env bash
# =============================================================================
# install-commit-msg.sh
# Installs the `commit-msg` command globally on your machine.
# It analyzes your staged git diff with Claude Code and proposes a commit.
#
# Usage: bash install-commit-msg.sh
# =============================================================================

set -e

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="commit-msg"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# Sanity checks
echo "Checking dependencies..."

if ! command -v claude &>/dev/null; then
  echo "ERROR: Claude Code is not installed or not in PATH."
  echo "  Install it with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "ERROR: git is not installed."
  exit 1
fi

echo "All dependencies found."
mkdir -p "$INSTALL_DIR"

# Write the commit-msg script
cat > "$SCRIPT_PATH" << 'COMMIT_MSG_SCRIPT'
#!/usr/bin/env bash
# commit-msg -- AI-powered commit message generator via Claude Code
# Usage: commit-msg [--dry-run] [--help]

set -e

DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run|-d) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: commit-msg [--dry-run] [--help]"
      echo ""
      echo "  Analyzes your staged git diff with Claude Code and proposes"
      echo "  a Conventional Commit message. Accept, edit, regenerate, or abort."
      echo ""
      echo "Options:"
      echo "  --dry-run, -d   Print the suggestion only, do not commit"
      echo "  --help,    -h   Show this help"
      exit 0
      ;;
  esac
done

# Must be inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

# Must have staged changes
if git diff --staged --quiet; then
  echo "WARNING: No staged changes found. Run 'git add' first."
  exit 1
fi

# Gather context
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
STAGED_FILES=$(git diff --staged --name-only)
FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')

# Write diff to a temp file to avoid "Prompt is too long" on large changesets
DIFF_FILE=$(mktemp /tmp/commit-diff-XXXXXX.txt)
git diff --staged > "$DIFF_FILE"
trap 'rm -f "$DIFF_FILE"' EXIT

echo ""
echo "Analyzing staged diff with Claude Code..."
echo ""

DIFF_CONTENT=$(head -800 "$DIFF_FILE")

PROMPT="You are an expert developer writing git commit messages.

Repository: ${REPO_NAME}
Branch: ${BRANCH}
Files changed (${FILE_COUNT}):
$(echo "$STAGED_FILES" | head -30)

Here is the full staged diff:

${DIFF_CONTENT}

Rules:
1. Follow Conventional Commits spec: <type>(<scope>): <subject>
   Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
2. Subject line: max 72 chars, imperative mood, no trailing period
3. If non-trivial, add a blank line then a short body (2-4 lines max)
4. Be specific -- avoid vague messages like 'update files' or 'fix bug'
5. Infer scope from the changed files/module when obvious

Output ONLY the raw commit message -- no markdown fences, no commentary."

# -p = non-interactive mode, uses your existing claude login session
# --allowedTools Read = let Claude read the temp diff file
SUGGESTED_MSG=$(claude -p "$PROMPT" --model claude-haiku-4-5 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Claude Code exited with code $EXIT_CODE:"
  echo "$SUGGESTED_MSG"
  exit 1
fi

if [[ -z "$SUGGESTED_MSG" ]]; then
  echo "ERROR: Claude Code returned an empty response."
  echo "  Make sure you are logged in: run 'claude' once interactively first."
  exit 1
fi

# Display suggestion
echo "------------------------------------------------------------------------"
echo "Suggested commit message:"
echo ""
echo "$SUGGESTED_MSG"
echo ""
echo "------------------------------------------------------------------------"

if $DRY_RUN; then
  echo "(dry-run -- nothing committed)"
  exit 0
fi

echo ""
echo "What do you want to do?"
echo "  [Y] Accept and commit"
echo "  [e] Edit before committing"
echo "  [r] Regenerate (ask Claude again)"
echo "  [n] Abort"
echo ""
read -r -p "Choice [Y/e/r/n]: " CHOICE

CHOICE_LOWER=$(echo "$CHOICE" | tr "[:upper:]" "[:lower:]")
case "$CHOICE_LOWER" in
  ""|y|yes)
    git commit -m "$SUGGESTED_MSG"
    echo ""
    echo "Committed!"
    ;;

  e|edit)
    TMP_FILE=$(mktemp /tmp/commit-msg-XXXXXX.txt)
    echo "$SUGGESTED_MSG" > "$TMP_FILE"
    {
      echo ""
      echo "# Edit your commit message above."
      echo "# Lines starting with # are ignored."
      echo "# Branch: $BRANCH | Repo: $REPO_NAME"
    } >> "$TMP_FILE"

    EDITOR="${GIT_EDITOR:-${VISUAL:-${EDITOR:-vi}}}"
    "$EDITOR" "$TMP_FILE"

    EDITED_MSG=$(grep -v '^#' "$TMP_FILE" \
      | sed 's/[[:space:]]*$//' \
      | sed '/./,$!d' \
      | sed -e :a -e '/^\n*$/{$d;N;ba}')
    rm -f "$TMP_FILE"

    if [[ -z "$EDITED_MSG" ]]; then
      echo "WARNING: Empty message -- aborting."
      exit 1
    fi

    git commit -m "$EDITED_MSG"
    echo ""
    echo "Committed with your edited message!"
    ;;

  r|regen|regenerate)
    echo ""
    echo "Regenerating..."
    exec commit-msg "$@"
    ;;

  n|no|abort)
    echo "Aborted. Staged changes are still intact."
    exit 0
    ;;

  *)
    echo "Unknown choice -- aborting."
    exit 1
    ;;
esac
COMMIT_MSG_SCRIPT

chmod +x "$SCRIPT_PATH"

echo ""
echo "Installed -> $SCRIPT_PATH"
echo ""

if echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo "$INSTALL_DIR is already in your PATH."
else
  echo "WARNING: $INSTALL_DIR is NOT yet in your PATH."
  echo ""
  echo "Add this to your ~/.zshrc (or ~/.bashrc) and restart your terminal:"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

echo "------------------------------------------------------------------------"
echo "Usage:"
echo "  git add <files>"
echo "  commit-msg              # analyze -> suggest -> confirm"
echo "  commit-msg --dry-run    # print suggestion only"
echo "  commit-msg --help       # show help"
echo "------------------------------------------------------------------------"
