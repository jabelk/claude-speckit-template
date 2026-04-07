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

# Install or upgrade specify CLI
echo "Installing/upgrading specify CLI..."
if uv tool list 2>/dev/null | grep -q specify-cli; then
  uv tool upgrade specify-cli 2>/dev/null || true
else
  uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git"
fi

echo ""

# Check for git
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Initializing git repository..."
  git init
fi

# Back up custom files that specify init might overwrite
BACKUP_DIR=$(mktemp -d)
echo "Backing up custom skills and scripts..."
cp -r "$REPO_ROOT/.claude/skills/feature" "$BACKUP_DIR/feature" 2>/dev/null || true
cp -r "$REPO_ROOT/.claude/skills/review-plan" "$BACKUP_DIR/review-plan" 2>/dev/null || true
cp -r "$REPO_ROOT/scripts" "$BACKUP_DIR/scripts" 2>/dev/null || true

# Run specify init to pull latest spec-kit
echo "Running specify init (pulling latest spec-kit)..."
specify init --here --ai claude --no-git --force

# Restore custom files
echo "Restoring custom skills and scripts..."
cp -r "$BACKUP_DIR/feature" "$REPO_ROOT/.claude/skills/feature" 2>/dev/null || echo "Warning: failed to restore /feature skill from backup" >&2
cp -r "$BACKUP_DIR/review-plan" "$REPO_ROOT/.claude/skills/review-plan" 2>/dev/null || echo "Warning: failed to restore /review-plan skill from backup" >&2
cp -r "$BACKUP_DIR/scripts" "$REPO_ROOT/scripts" 2>/dev/null || echo "Warning: failed to restore scripts/ from backup" >&2
rm -rf "$BACKUP_DIR"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — replace {{PLACEHOLDERS}} with your project details"
echo "  2. Run /speckit-constitution to establish project principles"
echo "  3. Run /feature to start your first feature"
echo ""
echo "For multi-model plan review, add API keys to .env:"
echo "  OPENAI_API_KEY=..."
echo "  GEMINI_API_KEY=..."
