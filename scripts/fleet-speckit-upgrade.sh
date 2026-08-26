#!/usr/bin/env bash
# fleet-speckit-upgrade.sh — re-vendor spec-kit across the active fleet, one
# branch per repo: specify init + disable-model-invocation drift re-apply +
# extensions.yml, commit, push. PRs are opened afterwards, per repo, so each
# repo's review conventions apply.
#
# DRY RUN by default; --apply to execute.
#
# The specify CLI on PATH decides the version — setup.sh pins the install
# (SPECKIT_VERSION), so run setup.sh's install step (or `uv tool install`)
# to move the pin BEFORE running this. The branch name records the version
# actually vendored.
#
# History: first used (as a session scratchpad script) for the 0.5.0 → v1.0.1
# wave, 2026-08-21/26. Promoted here so the next upgrade doesn't start from a
# transcript recovery.
set -uo pipefail

# An exported CDPATH corrupts $(cd ... && pwd) on relative paths — the user's
# shell exports one. All cds below are absolute, but the guard costs nothing
# and the next edit may not keep that property.
unset CDPATH

TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$HOME/dev/projects"

VER="$(specify version 2>/dev/null | sed -n 's/.*CLI Version[^0-9]*\([0-9][0-9.]*\).*/\1/p' | head -1)"
if [ -z "$VER" ]; then
  echo "ERROR: could not read a version from 'specify version' — is the CLI installed?" >&2
  exit 2
fi
BRANCH="upgrade/spec-kit-v$VER"

# Active fleet as of 2026-08-26. Not here on purpose: nvidia-application
# (inactive), justin-40th (archived to _archive), personal-finance +
# story-memory-business (dormant per STATE.md), companion-ai-wt-milestones
# (worktree of companion-ai), claude-workflows + this template (their vendored
# copies are upgraded by hand, with review).
FLEET=(choose-adventure church-bible-study companion-ai family-app finance-agent
       grace-church-reno-teaching mtg-cube-ai)

APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1
ok=0; skipped=0; failed=0

for repo in "${FLEET[@]}"; do
  dir="$ROOT/$repo"
  printf '\n=== %s ===\n' "$repo"
  if [ ! -d "$dir/.git" ] || [ ! -d "$dir/.specify" ]; then
    echo "  skip: no git repo or no .specify"; skipped=$((skipped+1)); continue
  fi
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "  skip: working tree dirty"; skipped=$((skipped+1)); continue
  fi
  if git -C "$dir" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "  skip: branch $BRANCH already exists"; skipped=$((skipped+1)); continue
  fi
  # The remote too: origin/$BRANCH without a local copy (pushed from another
  # machine) would otherwise be silently updated by the `push -u` below —
  # changing a PR branch someone else owns.
  if git -C "$dir" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    echo "  skip: origin/$BRANCH already exists"; skipped=$((skipped+1)); continue
  fi
  default=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
  default="${default:-main}"
  echo "  default branch: $default"
  if [ $APPLY -eq 0 ]; then
    echo "  would: checkout $default, pull, branch $BRANCH, specify init, drift flag, extensions.yml, commit, push"
    ok=$((ok+1)); continue
  fi

  if ( set -e
    cd "$dir"
    git checkout -q "$default"
    git pull -q --ff-only
    git checkout -q -b "$BRANCH"
    specify init --here --integration claude --force >/dev/null 2>&1
    # Fleet drift: upstream ships disable-model-invocation: false; every
    # workflow-shaped skill in this fleet is an explicit slash command only.
    # perl -pi is sanctioned HERE because the end state is verified per file
    # and the script fails loudly (the committed-script exception to the
    # no-stream-edits rule).
    drift_failed=0
    for f in .claude/skills/speckit-*/SKILL.md; do
      [ -f "$f" ] || continue
      perl -pi -e 's/^disable-model-invocation: false$/disable-model-invocation: true/' "$f"
      grep -q '^disable-model-invocation: true$' "$f" || { echo "  DRIFT FLAG MISSING: $f" >&2; drift_failed=1; }
    done
    [ "$drift_failed" -eq 0 ]
    cp "$TEMPLATE/.specify/extensions.yml" .specify/extensions.yml
    git add -A
    git commit -q -m "feat: upgrade vendored spec-kit to v$VER

specify init re-vendor (pinned CLI v$VER) + disable-model-invocation
drift re-applied to all speckit skills + /review-plan gate wired as an
optional before_implement hook via .specify/extensions.yml."
    git push -q -u origin "$BRANCH"
  ); then
    echo "  DONE: pushed $BRANCH"
    ok=$((ok+1))
  else
    echo "  FAILED (repo left on $BRANCH or partial — inspect by hand)"
    failed=$((failed+1))
  fi
done

printf '\nsummary: %d ok, %d skipped, %d failed\n' "$ok" "$skipped" "$failed"
[ "$failed" -eq 0 ]
