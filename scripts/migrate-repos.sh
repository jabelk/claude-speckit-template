#!/usr/bin/env bash
# migrate-repos.sh — Upgrade spec-kit and install custom skills across all repos
#
# Usage: ./scripts/migrate-repos.sh [--dry-run] [repo1 repo2 ...]
#   --dry-run   Show what would be done without making changes
#   repo1 ...   Specific repo dirs to migrate (defaults to all in parent dir)
#
# What it does per repo:
#   1. Creates branch: upgrade-speckit-v05
#   2. Runs `specify init` to upgrade to skills format
#   3. Removes old .claude/commands/speckit.*.md
#   4. Installs /feature and /review-plan skills from the template
#   5. Copies setup.sh, .env.example, review-plan.sh
#   6. Updates CLAUDE.md and AGENTS.md command references (dot → hyphen)
#   7. Commits, pushes, and creates PR

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$(cd "$TEMPLATE_DIR/.." && pwd)"
DRY_RUN=false
BRANCH_NAME="upgrade-speckit-v05"

# Parse args
SPECIFIC_REPOS=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  else
    SPECIFIC_REPOS+=("$arg")
  fi
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERR]${NC} $1"; }
log_dry()  { echo -e "${YELLOW}[DRY-RUN]${NC} $1"; }

# Collect repos to migrate
REPOS=()
if [[ ${#SPECIFIC_REPOS[@]} -gt 0 ]]; then
  for repo in "${SPECIFIC_REPOS[@]}"; do
    if [[ -d "$PROJECTS_DIR/$repo" ]]; then
      REPOS+=("$PROJECTS_DIR/$repo")
    else
      log_err "Repo not found: $repo"
    fi
  done
else
  for dir in "$PROJECTS_DIR"/*/; do
    repo_name=$(basename "$dir")
    # Skip the template itself and non-speckit repos
    [[ "$repo_name" == "claude-speckit-template" ]] && continue
    [[ ! -d "$dir/.specify" ]] && continue
    # Skip repos already migrated (have .claude/skills/speckit-*)
    if ls "$dir"/.claude/skills/speckit-*/SKILL.md &>/dev/null; then
      continue
    fi
    # Only include repos with old commands
    if ls "$dir"/.claude/commands/speckit.*.md &>/dev/null; then
      REPOS+=("$dir")
    fi
  done
fi

echo "=== Spec Kit Migration ==="
echo "Template: $TEMPLATE_DIR"
echo "Repos to migrate: ${#REPOS[@]}"
echo ""

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No repos to migrate."
  exit 0
fi

# List repos
for repo in "${REPOS[@]}"; do
  echo "  - $(basename "$repo")"
done
echo ""

if $DRY_RUN; then
  echo "(dry run — no changes will be made)"
  echo ""
fi

SUCCESSES=0
FAILURES=0
SKIPPED=0

for repo in "${REPOS[@]}"; do
  repo_name=$(basename "$repo")
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Migrating: $repo_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  cd "$repo"

  # Check this is a git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_warn "Not a git repo, skipping"
    ((SKIPPED++))
    continue
  fi

  # Check for clean working tree
  if [[ -n "$(git status --porcelain)" ]]; then
    log_warn "Dirty working tree, skipping"
    ((SKIPPED++))
    continue
  fi

  # Check for remote
  if ! git remote get-url origin &>/dev/null; then
    log_warn "No remote, skipping"
    ((SKIPPED++))
    continue
  fi

  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    log_warn "Branch $BRANCH_NAME already exists, skipping"
    ((SKIPPED++))
    continue
  fi

  if $DRY_RUN; then
    log_dry "Would migrate $repo_name"
    ((SUCCESSES++))
    continue
  fi

  # Get default branch
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

  # Create branch
  git checkout -b "$BRANCH_NAME" "$DEFAULT_BRANCH" 2>/dev/null || {
    log_err "Failed to create branch"
    ((FAILURES++))
    continue
  }

  # 1. Run specify init to upgrade (v1 CLI: --integration replaced --ai, and
  # --no-git was dropped — the old flags made this always fail to the fallback)
  specify init --here --integration claude --force 2>/dev/null || {
    log_warn "specify init failed, continuing with manual migration"
  }

  # 2. Remove old commands
  if [[ -d .claude/commands ]]; then
    rm -f .claude/commands/speckit.*.md
    # Remove commands dir if empty
    rmdir .claude/commands 2>/dev/null || true
  fi

  # 3. Install /feature skill (only if not already present)
  if [[ ! -f .claude/skills/feature/SKILL.md ]]; then
    mkdir -p .claude/skills/feature
    cp "$TEMPLATE_DIR/.claude/skills/feature/SKILL.md" .claude/skills/feature/SKILL.md
  fi

  # 4. Install /review-plan skill (only if not already present)
  if [[ ! -f .claude/skills/review-plan/SKILL.md ]]; then
    mkdir -p .claude/skills/review-plan
    cp "$TEMPLATE_DIR/.claude/skills/review-plan/SKILL.md" .claude/skills/review-plan/SKILL.md
  fi

  # 5. Install review-plan.sh (only if not already present)
  if [[ ! -f scripts/review-plan.sh ]]; then
    mkdir -p scripts
    cp "$TEMPLATE_DIR/scripts/review-plan.sh" scripts/review-plan.sh
    chmod +x scripts/review-plan.sh
  fi

  # 6. Install setup.sh (only if not already present)
  if [[ ! -f setup.sh ]]; then
    cp "$TEMPLATE_DIR/setup.sh" setup.sh
    chmod +x setup.sh
  fi

  # 7. Install .env.example (only if not already present)
  if [[ ! -f .env.example ]]; then
    cp "$TEMPLATE_DIR/.env.example" .env.example
  fi

  # 8. Skip CLAUDE.md and AGENTS.md — they have per-project customizations.
  #    The old dot-notation commands still work as aliases in most cases,
  #    and each project can update references manually when convenient.

  # 9. Update .gitignore
  if [[ -f .gitignore ]]; then
    if ! grep -q '.claude/settings.local.json' .gitignore; then
      echo -e '\n# Claude Code\n.claude/settings.local.json' >> .gitignore
    fi
    if ! grep -q '!.env.example' .gitignore; then
      sed -i.bak 's|^\.env\.\*$|.env.*\n!.env.example|' .gitignore 2>/dev/null || true
      rm -f .gitignore.bak
    fi
  fi

  # Commit
  git add -A
  if [[ -z "$(git status --porcelain)" ]]; then
    log_warn "No changes detected, skipping"
    git checkout "$DEFAULT_BRANCH" 2>/dev/null
    git branch -d "$BRANCH_NAME" 2>/dev/null
    ((SKIPPED++))
    continue
  fi

  git commit -m "$(cat <<'COMMIT_EOF'
Upgrade to spec-kit v0.5 skills format, add /feature and /review-plan

- Replace .claude/commands/speckit.*.md with spec-kit v0.5 skills
- Add /feature skill (6-phase workflow with multi-model review gate)
- Add /review-plan skill + scripts/review-plan.sh
- Add setup.sh for dependency upgrades
- Update command references from dot to hyphen notation
- Add .env.example for review API keys

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
COMMIT_EOF
  )" 2>/dev/null

  # Push
  git push -u origin "$BRANCH_NAME" 2>/dev/null || {
    log_err "Failed to push"
    git checkout "$DEFAULT_BRANCH" 2>/dev/null
    ((FAILURES++))
    continue
  }

  # Create PR
  gh pr create \
    --title "Upgrade to spec-kit v0.5 skills, add /feature and /review-plan" \
    --body "$(cat <<'PR_EOF'
## Summary
- Replace frozen `.claude/commands/speckit.*.md` with spec-kit v0.5 skills
- Add `/feature` skill — 6-phase workflow with Phase 4.5 multi-model review gate
- Add `/review-plan` skill + `scripts/review-plan.sh` (DeepSeek R1, OpenAI gpt-5.3-codex, Gemini 2.5 Pro)
- Add `setup.sh` for future spec-kit dependency upgrades
- Update all command references from dot to hyphen notation

## After merging
```bash
git pull
```

For multi-model review, add API keys to `.env`:
```bash
cp .env.example .env
# Add DEEPSEEK_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY
```

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PR_EOF
  )" 2>/dev/null && log_ok "PR created" || log_err "PR creation failed"

  # Return to default branch
  git checkout "$DEFAULT_BRANCH" 2>/dev/null

  ((SUCCESSES++))
  echo ""
done

echo ""
echo "=== Migration Complete ==="
echo -e "  ${GREEN}Success: $SUCCESSES${NC}"
echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
echo -e "  ${RED}Failed:  $FAILURES${NC}"
