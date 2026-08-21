#!/usr/bin/env bash
# setup.sh — Bootstrap a new project from this template
#
# Usage:
#   1. Create a new repo from this template (GitHub "Use this template" or manual copy)
#   2. Run: ./setup.sh
#
# This script:
#   - Installs/upgrades the specify CLI (via uv)
#   - Re-initializes spec-kit to pull latest upstream scripts, templates, and commands
#   - Preserves your custom skills (/feature, /review-plan) and scripts

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

echo "=== Claude Code Template Setup ==="
echo ""

# Check for uv
if ! command -v uv &>/dev/null; then
  echo "ERROR: uv is required but not installed."
  echo "Install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
fi

# Install the specify CLI, pinned to a known release so every machine vendors
# the same payload. Unpinned installs track the default branch and ship
# x.y.z.dev0 builds — that's how a "0.5.0" template ended up alongside a
# 0.14.x CLI. Bump this ONE variable to upgrade, then review the diff.
SPECKIT_VERSION="v1.0.1"
echo "Installing specify CLI ${SPECKIT_VERSION}..."
uv tool install --force specify-cli --from "git+https://github.com/github/spec-kit.git@${SPECKIT_VERSION}"

echo ""

# Check for git
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Initializing git repository..."
  git init
fi

# Back up custom files that specify init might overwrite. cp -a preserves
# permissions (scripts must keep their exec bits through a restore).
BACKUP_DIR=$(mktemp -d)
echo "Backing up custom skills and scripts..."
cp -a "$REPO_ROOT/.claude/skills/feature" "$BACKUP_DIR/feature" 2>/dev/null || true
cp -a "$REPO_ROOT/.claude/skills/review-plan" "$BACKUP_DIR/review-plan" 2>/dev/null || true
cp -a "$REPO_ROOT/.claude/skills/review-plan-v2" "$BACKUP_DIR/review-plan-v2" 2>/dev/null || true
cp -a "$REPO_ROOT/.claude/skills/ship" "$BACKUP_DIR/ship" 2>/dev/null || true
cp -a "$REPO_ROOT/scripts" "$BACKUP_DIR/scripts" 2>/dev/null || true

# If specify init dies mid-run, set -e would otherwise skip the restore and
# leave the tree half-overwritten with the backups stranded in a tmpdir.
restore_all() {
  [ -d "$BACKUP_DIR" ] || return 0
  local any_failed=0
  for pair in "feature:.claude/skills/feature" \
              "review-plan:.claude/skills/review-plan" \
              "review-plan-v2:.claude/skills/review-plan-v2" \
              "ship:.claude/skills/ship" \
              "scripts:scripts"; do
    src="$BACKUP_DIR/${pair%%:*}"; dest="$REPO_ROOT/${pair#*:}"
    [ -d "$src" ] || continue
    # Stage-then-swap: never delete the destination until the copy succeeded,
    # and never delete the backup unless every restore succeeded.
    stage="${dest}.restore.$$"
    if cp -a "$src" "$stage" 2>/dev/null && rm -rf "$dest" && mv "$stage" "$dest"; then
      :
    else
      rm -rf "$stage"
      echo "Warning: failed to restore $dest from backup" >&2
      any_failed=1
    fi
  done
  if [ "$any_failed" -ne 0 ]; then
    echo "ERROR: backups preserved at $BACKUP_DIR — restore by hand" >&2
  else
    rm -rf "$BACKUP_DIR"
  fi
}
trap restore_all EXIT

# Run specify init to pull latest spec-kit
echo "Running specify init (pulling latest spec-kit)..."
specify init --here --integration claude --force

# Restore custom files.
# Remove the destination first so `cp -r` replaces it instead of nesting a copy
# inside an existing dir (e.g. .claude/skills/feature/feature). Current spec-kit
# leaves these custom files in place, so the dest dir exists at restore time.
echo "Restoring custom skills and scripts..."
# Stage-then-swap: the destination is only replaced after the staged copy
# succeeds, so a failed cp leaves both the destination and the backup intact.
restore_failed=0
restore_dir() {
  local src="$1" dest="$2" label="$3" stage
  [ -d "$src" ] || return 0
  stage="${dest}.restore.$$"
  if cp -a "$src" "$stage" 2>/dev/null && rm -rf "$dest" && mv "$stage" "$dest"; then
    return 0
  fi
  rm -rf "$stage"
  echo "Warning: failed to restore $label from backup" >&2
  restore_failed=1
}
restore_dir "$BACKUP_DIR/feature" "$REPO_ROOT/.claude/skills/feature" "/feature skill"
restore_dir "$BACKUP_DIR/review-plan" "$REPO_ROOT/.claude/skills/review-plan" "/review-plan skill"
restore_dir "$BACKUP_DIR/review-plan-v2" "$REPO_ROOT/.claude/skills/review-plan-v2" "/review-plan-v2 skill"
restore_dir "$BACKUP_DIR/ship" "$REPO_ROOT/.claude/skills/ship" "/ship skill"
restore_dir "$BACKUP_DIR/scripts" "$REPO_ROOT/scripts" "scripts/"
if [ "$restore_failed" -ne 0 ]; then
  echo "ERROR: restoration failed for one or more customs — backups preserved at $BACKUP_DIR" >&2
  trap - EXIT
  exit 1
fi
rm -rf "$BACKUP_DIR"

# Re-apply fleet drift: upstream ships `disable-model-invocation: false`, but
# every workflow-shaped skill in this fleet is an explicit slash command only —
# auto-firing /speckit-specify mid-conversation is a real failure mode. specify
# init resets the flag on every re-vendor, so it is re-applied here rather than
# trusted to memory.
echo "Re-applying disable-model-invocation: true to speckit skills..."
command -v perl >/dev/null || { echo "ERROR: perl required for drift re-apply" >&2; exit 1; }
drift_failed=0
for f in "$REPO_ROOT"/.claude/skills/speckit-*/SKILL.md; do
  [ -f "$f" ] || continue
  perl -pi -e 's/^disable-model-invocation: false$/disable-model-invocation: true/' "$f"
  # Fail LOUDLY if the end state is wrong (key renamed upstream, format drift):
  # a re-apply that silently does nothing re-enables auto-firing skills, which
  # is the exact failure this step exists to prevent.
  if ! grep -q '^disable-model-invocation: true$' "$f"; then
    echo "ERROR: $f lacks 'disable-model-invocation: true' after re-apply — upstream format changed; fix before shipping" >&2
    drift_failed=1
  fi
done
[ "$drift_failed" -eq 0 ] || exit 1

# Install Anthropic's official Office skills (docx, pptx, xlsx) for generating
# Word / PowerPoint / Excel artifacts (status reports, decks for mgmt, etc.)
# directly from Claude Code. The skills are non-redistributable per their LICENSE.txt,
# so we never vendor them — install_office_skills.sh re-fetches from upstream and
# adds .claude/skills/{docx,pptx,xlsx} to .gitignore on first run.
# Non-fatal: if install fails (no network, missing deps), the rest of setup still completes.
echo ""
echo "Installing Anthropic Office skills (docx / pptx / xlsx)..."
if [ -x "$REPO_ROOT/scripts/install_office_skills.sh" ]; then
  if ! "$REPO_ROOT/scripts/install_office_skills.sh"; then
    echo "Warning: Office skills install failed. Re-run scripts/install_office_skills.sh manually when ready." >&2
  fi
else
  echo "Warning: scripts/install_office_skills.sh missing or not executable; skipping Office skills install." >&2
fi

# Ensure .gitignore excludes the non-redistributable skill content + generated Office artifacts.
GI="$REPO_ROOT/.gitignore"
touch "$GI"
add_gitignore_line() {
  local line="$1"
  grep -Fxq "$line" "$GI" || echo "$line" >> "$GI"
}
if ! grep -q "Anthropic Office skills" "$GI" 2>/dev/null; then
  printf '\n# Anthropic Office skills — non-redistributable per their LICENSE.txt.\n# Re-installed at setup time via scripts/install_office_skills.sh.\n' >> "$GI"
  add_gitignore_line ".claude/skills/docx/"
  add_gitignore_line ".claude/skills/pptx/"
  add_gitignore_line ".claude/skills/xlsx/"
  printf '\n# Generated Office artifacts — hand-off only, never commit.\n' >> "$GI"
  add_gitignore_line "*.docx"
  add_gitignore_line "*.pptx"
  add_gitignore_line "*.xlsx"
  add_gitignore_line "*.pdf"
  add_gitignore_line "~\$*"
  echo "Added Office skills + artifacts entries to .gitignore."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — replace {{PLACEHOLDERS}} with your project details"
echo "  2. Run /speckit-constitution to establish project principles"
echo "  3. Run /feature to start your first feature"
echo "  4. (Optional) Restart Claude Code so the new docx/pptx/xlsx skills appear in the skill list"
echo ""
echo "For multi-model plan review, add API keys to .env:"
echo "  OPENAI_API_KEY=..."
echo "  GEMINI_API_KEY=..."
echo ""
echo "For Office artifacts (Word / PowerPoint / Excel):"
echo "  - Ask Claude to 'create a Word doc' or 'build a slide deck' — the skills auto-invoke."
echo "  - For visual QA loop: brew install --cask libreoffice (optional; without it,"
echo "    QA falls back to content-only checks)."
