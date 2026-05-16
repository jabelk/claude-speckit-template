#!/usr/bin/env bash
# install_office_skills.sh — install Anthropic's official Office skills locally.
#
# What this does:
#   - Clones https://github.com/anthropics/skills (or pulls latest if already cloned)
#   - Copies the docx, pptx, and xlsx skills into ./.claude/skills/
#   - Verifies required runtime tools are present (node, npm, python3.13, pandoc, soffice, pdftoppm)
#   - Installs the necessary npm globals: docx, pptxgenjs
#
# Why not commit the skills into this repo?
#   The Anthropic Skills license (LICENSE.txt in each skill dir) prohibits
#   redistribution and retaining copies outside Anthropic Services. The clean
#   compliant pattern is: clone from upstream at install time, every time.
#
# Usage:
#   ./scripts/install_office_skills.sh           # install all three (docx + pptx + xlsx)
#   ./scripts/install_office_skills.sh docx pptx # subset
#
# Re-runnable. Safe to run repeatedly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/anthropic-skills}"
TARGET_DIR="$REPO_ROOT/.claude/skills"
SKILLS=("${@:-docx pptx xlsx}")
# Shell-array gymnastics: if no args, expand to all three; otherwise use $@.
if [ $# -eq 0 ]; then
  SKILLS=(docx pptx xlsx)
else
  SKILLS=("$@")
fi

echo "→ install_office_skills.sh"
echo "  target:   $TARGET_DIR"
echo "  cache:    $CACHE_DIR"
echo "  skills:   ${SKILLS[*]}"
echo

# --- 1. Clone or refresh the upstream skills repo into the cache ----------
if [ -d "$CACHE_DIR/.git" ]; then
  echo "  refreshing existing upstream clone…"
  git -C "$CACHE_DIR" fetch --quiet origin
  git -C "$CACHE_DIR" reset --quiet --hard origin/HEAD
else
  echo "  cloning anthropics/skills → $CACHE_DIR"
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --quiet --depth=1 https://github.com/anthropics/skills.git "$CACHE_DIR"
fi

# --- 2. Copy each requested skill into .claude/skills/ ---------------------
mkdir -p "$TARGET_DIR"
for skill in "${SKILLS[@]}"; do
  src="$CACHE_DIR/skills/$skill"
  dst="$TARGET_DIR/$skill"
  if [ ! -d "$src" ]; then
    echo "  ✗ skill not found upstream: $skill (skipping)" >&2
    continue
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  echo "  ✓ installed: $skill → $dst"
done

# --- 3. Verify runtime deps -----------------------------------------------
echo
echo "→ runtime dependency check"
missing=0
for cmd in node npm python3.13 pandoc; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✓ %-12s %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "  ✗ %-12s MISSING\n" "$cmd"
    missing=$((missing + 1))
  fi
done

# Optional but recommended for visual QA loop
for cmd in soffice pdftoppm; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✓ %-12s %s (visual QA enabled)\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "  ⚠ %-12s MISSING — visual QA loop disabled\n" "$cmd"
    case "$cmd" in
      soffice)  echo "    install: brew install --cask libreoffice" ;;
      pdftoppm) echo "    install: brew install poppler" ;;
    esac
  fi
done

if [ "$missing" -gt 0 ]; then
  echo
  echo "  ✗ $missing required tools missing. Install them and re-run." >&2
  exit 1
fi

# --- 4. Install npm globals used by the skills ----------------------------
echo
echo "→ npm packages used by docx / pptx skills"
need_install=()
for pkg in docx pptxgenjs; do
  if npm list -g "$pkg" >/dev/null 2>&1; then
    printf "  ✓ %s (global, installed)\n" "$pkg"
  else
    printf "  ✗ %s (will install globally)\n" "$pkg"
    need_install+=("$pkg")
  fi
done
if [ "${#need_install[@]}" -gt 0 ]; then
  npm install -g "${need_install[@]}"
fi

# --- 5. Friendly final note -----------------------------------------------
echo
echo "✓ done. Restart Claude Code (or start a new session) so it picks up the new skills."
echo "  When invoking from inside Claude Code: the skills appear as 'docx', 'pptx', 'xlsx'."
echo "  When invoking from your own Node scripts: set NODE_PATH=\$(npm root -g) so the global"
echo "  docx/pptxgenjs packages resolve. Example:"
echo
echo "    NODE_PATH=\$(npm root -g) node scripts/build_slides.js"
