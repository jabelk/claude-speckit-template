#!/usr/bin/env bash
# new-project.sh — Create a new project from the claude-speckit-template
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/jabelk/claude-speckit-template/main/scripts/new-project.sh | bash -s my-project
#   # or locally:
#   ./scripts/new-project.sh my-project
#   ./scripts/new-project.sh .          # current directory

set -eo pipefail

PROJECT="${1:-.}"

if [[ "$PROJECT" == "." ]]; then
  TARGET_DIR="$(pwd)"
elif [[ "$PROJECT" == /* ]]; then
  TARGET_DIR="$PROJECT"
else
  TARGET_DIR="$(pwd)/$PROJECT"
fi

if [[ -d "$TARGET_DIR" && "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
  echo "ERROR: $TARGET_DIR is not empty"
  exit 1
fi

echo "=== Creating project: $(basename "$TARGET_DIR") ==="
echo ""

mkdir -p "$TARGET_DIR"

# Clone template, strip its git history
echo "Cloning template..."
TMPDIR=$(mktemp -d)
git clone --depth 1 https://github.com/jabelk/claude-speckit-template.git "$TMPDIR/tpl" 2>/dev/null
rm -rf "$TMPDIR/tpl/.git"
rm -f "$TMPDIR/tpl/scripts/migrate-repos.sh"  # not needed in new projects

# Copy everything into target
cp -a "$TMPDIR/tpl/." "$TARGET_DIR/"
rm -rf "$TMPDIR"

# Init git first so setup.sh has a repo to work in
cd "$TARGET_DIR"
git init -q

# Run setup.sh to pull latest spec-kit (adds/updates skills)
# </dev/null prevents it from consuming the curl pipe's stdin
echo ""
./setup.sh </dev/null || echo "Warning: setup.sh exited with errors, continuing..." >&2

# Commit everything — template files + spec-kit output — in one shot
echo "Creating initial commit..."
git add -A
git commit -q -m "Initial project from claude-speckit-template"

echo ""
echo "Project ready at: $TARGET_DIR"
echo ""
echo "Next:"
echo "  cd $(basename "$TARGET_DIR")"
echo "  # Edit CLAUDE.md — replace {{PLACEHOLDERS}}"
echo "  # Then: claude"
