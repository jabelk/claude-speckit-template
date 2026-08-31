#!/usr/bin/env bash
# fleet-speckit-upgrade.sh — re-vendor spec-kit across the active fleet, one
# branch per repo: specify init + skill-invocation assert + extensions.yml,
# commit, push. PRs are opened afterwards, per repo, so each repo's review
# conventions apply.
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
# transcript recovery. Its drift step inverted on 2026-08-28: it used to flip
# upstream's `disable-model-invocation: false` to `true` on every speckit skill,
# which is the chore that scripts/assert-skill-invocation.sh exists to end. It
# now calls that script instead, so the desired state is asserted in one place
# and this one has no opinion about it.
set -uo pipefail

# An exported CDPATH corrupts $(cd ... && pwd) on relative paths — the user's
# shell exports one. All cds below are absolute, but the guard costs nothing
# and the next edit may not keep that property.
unset CDPATH

TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Both overridable, because the list below is per-machine and a hardcoded one
# that does not match the machine is how this script reports success for doing
# nothing. See the absent-count guard at the bottom.
ROOT="${FLEET_ROOT:-$HOME/dev/projects}"

VER="$(specify version 2>/dev/null | sed -n 's/.*CLI Version[^0-9]*\([0-9][0-9.]*\).*/\1/p' | head -1)"
if [ -z "$VER" ]; then
  echo "ERROR: could not read a version from 'specify version' — is the CLI installed?" >&2
  exit 2
fi
BRANCH="upgrade/spec-kit-v$VER"

# Active fleet as of 2026-08-26, on the machine that ran that wave. Not here on
# purpose: nvidia-application (inactive), justin-40th (archived to _archive),
# personal-finance + story-memory-business (dormant per STATE.md),
# companion-ai-wt-milestones (worktree of companion-ai), claude-workflows + this
# template (their vendored copies are upgraded by hand, with review).
#
# THIS LIST IS PER-MACHINE. Override it with a space-separated FLEET_REPOS
# rather than editing it, so a second machine's checkout does not carry the
# first machine's roster: `FLEET_REPOS="a b c" scripts/fleet-speckit-upgrade.sh`.
FLEET=(choose-adventure church-bible-study companion-ai family-app finance-agent
       grace-church-reno-teaching mtg-cube-ai)
# shellcheck disable=SC2206  # word splitting is the interface here
[ -n "${FLEET_REPOS:-}" ] && FLEET=(${FLEET_REPOS})

APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1
ok=0; skipped=0; absent=0; failed=0

for repo in "${FLEET[@]}"; do
  dir="$ROOT/$repo"
  printf '\n=== %s ===\n' "$repo"
  # Absent is counted apart from skipped, and the two are not the same finding:
  # "dirty tree" means this machine has the repo and the run declined it, while
  # "not here" means the roster is wrong for this machine and the run had nothing
  # to decline. Folded together they read identically in the summary, which is how
  # a stale FLEET produces `0 ok, 7 skipped, 0 failed` at exit 0 — a clean-looking
  # wave over zero repos. Measured on 2026-08-31: all seven entries above are
  # absent on this checkout's machine, and the pre-fix script said exit 0.
  if [ ! -d "$dir" ]; then
    echo "  ABSENT: $dir does not exist on this machine"; absent=$((absent+1)); continue
  fi
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
  #
  # The status is read explicitly rather than as an `if`, because `ls-remote` has
  # THREE outcomes and only one of them permits the push. Measured 2026-08-31
  # against this repo's own origin: an existing branch is 0, an absent branch is
  # 2, and an unreachable remote (no network, expired credential, wrong URL) is
  # 128. An `if` collapses 2 and 128 into the same proceed branch, so a machine
  # that cannot reach origin concludes the branch is absent and pushes over it.
  # That is the fail-open shape recorded at length in
  # scripts/preflight-vendor-review.sh: an unanswered question is not a "no", and
  # a check whose failure is indistinguishable from its success is not a check.
  # CodeRabbit caught it here.
  remote_status=0
  git -C "$dir" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1 || remote_status=$?
  case "$remote_status" in
    0)
      echo "  skip: origin/$BRANCH already exists"; skipped=$((skipped+1)); continue ;;
    2)
      : ;;  # absent on the remote — the only status that permits the push below
    *)
      echo "  FAILED: could not ask origin whether $BRANCH exists (ls-remote exit $remote_status)"
      echo "          Not proceeding. The push below would fast-forward a branch that"
      echo "          may already exist and belong to another machine or person."
      failed=$((failed+1)); continue ;;
  esac
  default=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
  default="${default:-main}"
  echo "  default branch: $default"
  if [ $APPLY -eq 0 ]; then
    echo "  would: checkout $default, pull, branch $BRANCH, specify init, assert-skill-invocation, extensions.yml, commit, push"
    ok=$((ok+1)); continue
  fi

  if ( set -e
    cd "$dir"
    git checkout -q "$default"
    git pull -q --ff-only
    git checkout -q -b "$BRANCH"
    specify init --here --integration claude --force >/dev/null 2>&1
    # Assert the fleet's skill-invocation state over the whole re-vendored
    # skills dir. A `specify init --force` rewrites every speckit skill from
    # upstream, so whatever the repo had here is gone and this is the step that
    # puts it back. The desired state and the /ship exemption live in that
    # script and nowhere else; this one only calls it and propagates its exit.
    #
    # It is the TEMPLATE's copy, deliberately: a fleet repo may be carrying an
    # older vendored copy of the script, and an upgrade wave that asserted each
    # repo's state with each repo's own stale assertion is how the fleet drifted
    # in the first place.
    "$TEMPLATE/scripts/assert-skill-invocation.sh" "$dir"
    cp "$TEMPLATE/.specify/extensions.yml" .specify/extensions.yml
    git add -A
    git commit -q -m "feat: upgrade vendored spec-kit to v$VER

specify init re-vendor (pinned CLI v$VER) + skill invocation asserted by
scripts/assert-skill-invocation.sh + /review-plan gate wired as an
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

printf '\nsummary: %d ok, %d skipped, %d absent, %d failed\n' "$ok" "$skipped" "$absent" "$failed"

# The examined-nothing guard, the same one scripts/assert-skill-invocation.sh
# carries: a run that found not one of its repos must not exit like a run that
# upgraded all of them. Exit 2 rather than 1 — the roster is a configuration
# error, not a finding about any repo.
if [ "$absent" -eq "${#FLEET[@]}" ]; then
  echo "ERROR: none of the ${#FLEET[@]} repo(s) in FLEET exist under $ROOT." >&2
  echo "       Nothing was examined. Set FLEET_ROOT and/or FLEET_REPOS for this" >&2
  echo "       machine, or run this from the machine that holds the fleet." >&2
  exit 2
fi

# A wave in which every repo was declined is exit 0 on purpose — a second run
# over an already-upgraded fleet is the ordinary idempotent case, and failing it
# would make the script unusable as a re-run. But exit 0 is also what a wave that
# upgraded everything looks like, so say which one this was rather than leaving
# the reader to subtract the counts. Same reason review-plan-v2 prints
# [NOTHING REVIEWED] over an empty diff instead of trusting its own exit code.
if [ "$ok" -eq 0 ]; then
  echo "[NOTHING UPGRADED] every repo was declined above — no branch was created." >&2
fi

[ "$failed" -eq 0 ]
