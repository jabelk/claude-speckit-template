#!/usr/bin/env bash
# preflight-vendor-review.sh — refuse to run a provider-backed review while the
# worktree is dirty.
#
# `coderabbit review --include-untracked` sends EVERY non-ignored untracked file
# in the worktree to a vendor, not only the ones related to the change: scratch
# notes, a pasted credential, a downloaded export, a colleague's data sample. And
# no local scan has seen them — `gitleaks git --log-opts=...` reads commits, and
# no `review-plan-v2 --type` scope puts an untracked file in front of gitleaks.
# So the flag routes the least-reviewed files in the tree around the secret scan.
# The bar is therefore not "nothing belonging to the change" but nothing at all:
# commit what should be reviewed, `.gitignore` or move what should not.
#
# WHAT IT REJECTS: any dirty entry `git status --porcelain -uall` reports, not
# only `^??`. It checked `^??` alone until 2026-08-31, on the reasoning that
# `--include-untracked` is the thing routing an unscanned file to the vendor and
# that uncommitted edits to TRACKED files are already reachable by gitleaks. The
# second half of that was false, and it was false in this repo's own documented
# numbers: leg 1 of the gate is `review-plan-v2 --static-only`, whose default
# `--type all` diffs `$BASE...HEAD`, so gitleaks never reads the working tree at
# all. A tracked file with staged or unstaged edits was therefore scanned by
# nothing, and the guard passed it without comment.
#
# The narrow form also required a rationale the widened one does not: the gate's
# documented prerequisite is that the change is COMMITTED, so in the intended
# workflow the tree is clean by definition and this costs nothing. A dirty tree
# at gate time means either that prerequisite was skipped or the tree changed
# mid-gate, and both are reasons to stop rather than to send. The old header
# argued the reverse — that widening would make the guard "fire on the ordinary
# state of a working session and get switched off" — which described a workflow
# the gate never sanctioned.
#
# NOT VERIFIED here, and deliberately not relied on: whether the CodeRabbit CLI
# itself uploads working-tree content for tracked files. `.claude/skills/
# review-plan-v2/SKILL.md` in a sibling repo asserts it does. The reason above
# stands either way, so this script does not rest on that claim.
#
# WHY THIS IS A SCRIPT. It was nine lines of shell inside a fenced block in
# .claude/skills/ship/SKILL.md, and it took seven consecutive review rounds:
#
#   1. It was a bare pipeline, not an `if` — and its clean result is `grep`
#      exiting 1, so under `set -e` the clean case aborted before either leg ran
#      and without `set -e` it was output nobody was obliged to read.
#   2. `if git status --porcelain -uall | grep '^??'` reported the PIPELINE's
#      status, which is grep's. A failing `git status` left grep reading empty
#      input and exiting 1, so the proceed branch ran: the guard said "clean
#      worktree" exactly when it could not see the worktree.
#   3. The guard sat next to its own explanation rather than in the command
#      anyone would copy, so the copyable blocks had no guard.
#   4. Fixed by marking those blocks with a comment saying the guard "still
#      applies" — a comment is not a guard.
#   5. `printf '%s\n' "$w" | grep -q '^??'` fails OPEN under `set -o pipefail`:
#      grep -q exits at the first match, printf takes SIGPIPE and exits 141,
#      pipefail makes 141 the pipeline's status, and the `if` takes the proceed
#      branch. The guard ruled the worktree clean BECAUSE it found too many
#      untracked files to finish listing them. The trigger is BYTES, not files —
#      it is the 64 KiB pipe buffer — so there is no safe file count. Bisected
#      2026-08-31: correct at 61,893 bytes of `git status --porcelain -uall`
#      output, status 141 at 70,893. With 15-character filenames that is roughly
#      3,500 files versus 4,000; with short ones it takes four times as many, and
#      that is exactly why "we tested it with a few untracked files" was not
#      evidence of anything.
#   6. It ran once, and the gap between the check and the send is the whole
#      runtime of the static leg — where an editor autosave, a build artifact, or
#      a second agent session in the same worktree drops a new file.
#   7. `if untracked=$(grep '^??' <<<"$worktree")` collapsed grep's three
#      outcomes into an `if`'s two, so a `grep` that could not run read as a
#      clean tree. This was the round that created this file, and the first fix
#      here was to read grep's status explicitly. The line no longer exists:
#      see the decision block below for why the whole class went with it.
#
# Every one of those fixes was correct and every one left the next hole. The
# lesson stopped being about any individual fix: a shell guard living in a
# Markdown paragraph has no mechanism to be wrong out loud. This file has one —
# scripts/test-preflight-vendor-review.sh, which hands it a dirty worktree, an
# edited tracked file, a non-repository, a broken helper, an exported GIT_DIR,
# and 20,000 untracked files, and fails if any of them passes.
#
# Rounds 8 and 9 came after the move into this file, and neither was a repeat of
# the seven. Round 8 WIDENED the check (see WHAT IT REJECTS above) and deleted
# the last command from the decision. Round 9 is the `unset` below: git's own
# location variables outranked the `cd`, so the script could inspect a different
# repository than the one it named. Being a script is what let that one be
# reproduced in ten lines and pinned by a test, rather than argued about.
#
# What it does NOT check: files matched by `.gitignore`. The vendor never
# receives them, so they are not this script's business.
#
# Usage:  preflight-vendor-review [REPO_ROOT]        # on PATH, from any repo
#         scripts/preflight-vendor-review.sh [REPO_ROOT]   # a repo carrying a copy
#         preflight-vendor-review && coderabbit review --base "$BASE" --include-untracked
#
# This repo is the canonical copy and `~/.local/bin/preflight-vendor-review`
# symlinks to it, same arrangement as `review-plan-v2`. So the documented gate is
# the PATH form: one file, reachable from every repo, with one test suite behind
# it. internal-speckit-template carries its own copy at the same path because a
# bootstrapped repo has to work before anything is installed, and its skills call
# the relative form. Keep the two byte-identical — a divergence means one of them
# has an unfixed round of the history above.
# Exit:   0 the worktree held no dirty entry at the moment it ran
#         2 a dirty entry was present, or the worktree could not be inspected
#
# Exit 0 is NOT a verdict that the send is safe. It is one observation, of one
# worktree, at one instant, and it decays the moment anything writes to the
# tree — which is why the documented gate calls this twice.
#
# THE RACE THIS CANNOT CLOSE, stated plainly because the docs previously
# understated it. Between the second call's exit and the moment the vendor
# process enumerates the worktree, a concurrent writer can add a file that
# `--include-untracked` then ships and that no local scan has read. CodeRabbit
# raised this as CWE-367 on 2026-08-31 and it is correct that the race is real.
#
# What was wrong was the width. The fleet docs said the second call "closes the
# window to the width of a process spawn." NOT VERIFIED, and probably false:
# the CLI's `Connecting to CodeRabbit...` phase has been observed running past
# five minutes on this machine, and whether it enumerates the worktree before or
# after connecting is unknown. So the honest bound is "unknown, possibly the
# whole connect phase." Two calls NARROW the window. They do not close it, and
# nothing available here can, because the vendor is a separate process reading a
# live worktree.
#
# The remedy NOT taken, and why. Dropping `--include-untracked` closes the race
# and was the suggested fix. It also makes a file you forgot to `git add`
# invisible to the review, so its omission reads exactly like a clean pass —
# which is the failure class this whole file exists to remove, reintroduced one
# layer out. Reviewing an immutable snapshot (a throwaway worktree at HEAD) has
# the same cost: nothing untracked is ever seen. Trading a bounded race for a
# permanent blind spot is the wrong direction.
#
# So the mitigation is the caller's, and it is the one thing actually in the
# caller's control: do not write into the tree while the gate is running. Two
# agent sessions sharing a worktree is the ordinary case on this machine, which
# is what makes this worth a paragraph rather than a shrug.
#
# There is no exit 1. A refusal and a broken check are the same answer here — do
# not send — and giving them one code removes the chance of a caller treating one
# of them as a pass.
set -uo pipefail

# An exported CDPATH corrupts a relative `cd`, and this one takes its target
# from an argument.
unset CDPATH

# And git's own location variables outrank the `cd` entirely, which is round 9.
# With `GIT_DIR`/`GIT_WORK_TREE` exported, `git status` below inspects THAT
# repository no matter which directory this script entered — so the script
# answered about a worktree the send does not use, which is the one failure this
# file exists to prevent. Reproduced 2026-08-31 with two scratch repos, one
# dirty and holding an unscanned untracked file, one clean:
#
#   GIT_DIR=$clean/.git GIT_WORK_TREE=$clean preflight-vendor-review "$dirty"
#     → "preflight: clean worktree in .../dirty ... " and exit 0
#
# Note what that line says: it names the DIRTY path, because `pwd` is honest and
# `git` was reading somewhere else. A wrong answer that identifies the wrong
# subject with full confidence is worse than an error, and it is not exotic —
# git exports these to every hook it runs, so wiring this into a pre-push hook
# would have armed it. `GIT_INDEX_FILE` is here for the same reason one step in:
# it redefines what "staged" means, so a stale or empty index file hides a
# staged change from `--porcelain`. `GIT_COMMON_DIR` likewise redirects the
# shared metadata a linked worktree resolves through.
#
# Unsetting them is not a loss of function: the documented way to point this
# script at a repository is the REPO_ROOT argument, which still works.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

LIST_CAP=20

root="${1:-.}"
if ! cd "$root"; then
  echo "STOP: cannot enter '$root', so the worktree was never inspected." >&2
  exit 2
fi

# Fails CLOSED. A worktree that cannot be inspected is not a clean one, and the
# capture is separate from the test for the reason recorded as round 2 above.
if ! worktree=$(git status --porcelain --untracked-files=all); then
  echo "STOP: cannot inspect the worktree (git status failed above), so a" >&2
  echo "      provider-backed review is not safe to run here." >&2
  exit 2
fi

# ANY dirty entry, not only `^??`. See "WHAT IT REJECTS" above.
#
# The decision is one `[ -n ]` over a variable already in hand. There is no
# `grep`, no pipeline, and no second call to anything, which is what retires the
# whole failure class rounds 2, 5, and 7 each found one instance of: every one of
# those was a helper whose operational error was indistinguishable from its
# "found nothing" answer. `grep` has THREE outcomes and an `if` has two, `grep -q`
# takes SIGPIPE under `pipefail`, `grep -c ... || true` swallows both — and none
# of that can arise in a test with no command in it.
#
# Everything that can still fail is BELOW the refusal, not above it, and that
# ordering is the design rather than an accident of layout: from here on a broken
# helper can garble the wording of a refusal and cannot manufacture a pass.
if [ -n "$worktree" ]; then
  # `awk`, not `grep -c`, and its exit status is deliberately not consulted:
  # these two numbers only shape the message. If awk fails they read 0 and the
  # refusal still stands, because the decision was made on the line above.
  total=$(awk 'END { print NR }' <<<"$worktree")
  untracked=$(awk '/^\?\?/ { n++ } END { print n+0 }' <<<"$worktree")

  # The listing is capped and says so. A cap that stays quiet reads as "these are
  # all of them", which is the same class of lie as the rest of this file.
  awk -v cap="$LIST_CAP" -v total="$total" '
    NR <= cap { print "  " $0 }
    END { if (total > cap) printf "  ... and %d more\n", total - cap }
  ' <<<"$worktree" >&2
  echo "STOP: $total uncommitted change(s) above, $untracked of them untracked." >&2
  echo "      A provider-backed review would send them, and leg 1 diffs" >&2
  echo "      \$BASE...HEAD, so no local scan has read any of them. Commit what" >&2
  echo "      should be reviewed; .gitignore or move what should not." >&2
  exit 2
fi

# The success line says what was OBSERVED, not that the send is safe. It said
# "safe to send the diff" until 2026-08-31, which is a stronger claim than one
# `git status` supports: it covers one worktree at one instant — which is
# precisely why the documented gate calls this script twice rather than once. A
# caller quoting "safe to send" as evidence would be quoting a guarantee this
# script never made. CodeRabbit caught the wording.
echo "preflight: clean worktree in $(pwd) at this moment — the only thing checked."
