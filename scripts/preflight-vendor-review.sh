#!/usr/bin/env bash
# preflight-vendor-review.sh — refuse to run a provider-backed review while the
# worktree holds untracked files.
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
# WHY THIS IS A SCRIPT. It was nine lines of shell inside a fenced block in
# .claude/skills/ship/SKILL.md, and it took six consecutive review rounds:
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
#
# Every one of those fixes was correct and every one left the next hole. The
# lesson stopped being about any individual fix: a shell guard living in a
# Markdown paragraph has no mechanism to be wrong out loud. This file has one —
# scripts/test-preflight-vendor-review.sh, which hands it a dirty worktree, a
# non-repository, and 20,000 untracked files, and fails if any of them passes.
#
# What it does NOT check, deliberately: uncommitted changes to TRACKED files.
# Those are already in git's index or history, so gitleaks has a range that can
# reach them and they are not the class of file this exists to stop. Widening the
# check to them would make the guard fire on the ordinary state of a working
# session and get switched off.
#
# Usage:  scripts/preflight-vendor-review.sh [REPO_ROOT]
#         preflight-vendor-review.sh && coderabbit review --base "$BASE" --include-untracked
# Exit:   0 no untracked files — safe to send the diff to a vendor
#         2 untracked files present, or the worktree could not be inspected
#
# There is no exit 1. A refusal and a broken check are the same answer here — do
# not send — and giving them one code removes the chance of a caller treating one
# of them as a pass.
set -uo pipefail

# An exported CDPATH corrupts a relative `cd`, and this one takes its target
# from an argument.
unset CDPATH

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

# NOT a pipeline — see round 5. One `grep` over a here-string, whose exit status
# is its own and whose captured output is what gets printed.
if untracked=$(grep '^??' <<<"$worktree"); then
  count=$(grep -c '^??' <<<"$worktree" || true)
  # The listing is capped and says so. A cap that stays quiet reads as "these are
  # all of them", which is the same class of lie as the rest of this file.
  awk -v cap="$LIST_CAP" -v total="$count" '
    NR <= cap { print "  " $0 }
    END { if (total > cap) printf "  ... and %d more\n", total - cap }
  ' <<<"$untracked" >&2
  echo "STOP: $count untracked file(s) above would be sent to the vendor by" >&2
  echo "      --include-untracked, and no local scan has read them. Commit what" >&2
  echo "      should be reviewed; .gitignore or move what should not." >&2
  exit 2
fi

echo "preflight: 0 untracked files in $(pwd) — safe to send the diff."
