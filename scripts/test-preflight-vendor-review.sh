#!/usr/bin/env bash
# Fixture suite for scripts/preflight-vendor-review.sh.
#
# The guard under test spent six review rounds as nine lines of shell inside a
# Markdown fenced block, where nothing could execute it and every fix looked
# correct while leaving the next hole. This file is the mechanism that block
# never had. Each case is one of the ways the guard failed, in the shape that
# failed: a dirty worktree, a directory that is not a repository, and 20,000
# untracked files.
#
# The bulk case carries its own anti-vacuity assertion, and that is the point of
# it rather than a flourish. A green "20,000 files are refused" proves nothing
# unless the fixture can distinguish the fixed guard from the broken one — and
# the broken form only falls open ABOVE some file count, so the same test with
# 5,000 files would pass against BOTH implementations and read as proof. So the
# case runs the retired pipeline form against its own fixture and FAILS if that
# form does not fall open, which means the test tells you when it has stopped
# testing anything instead of going quietly green.
#
# Seen red, 2026-08-31, twice. Against a staged copy carrying the retired
# two-outcome `if untracked=$(grep ...)` form, the fail-closed case failed with
# `exit 0, wanted 2` and printed the clean-tree pass from a run whose `grep` never
# searched. Then against a copy carrying the retired narrow `^??` decision, the
# two tracked-edit cases failed the same way — a staged credential in a tracked
# file, reported clean. Both reds are recorded because the second is the one a
# reader is likely to mistake for a regression: the tracked-file cases assert the
# OPPOSITE of what they asserted before that date.
#
# Seen red again 2026-09-01, twice more, and the second red is about THIS FILE.
#
#   - Round 12, the empty-value hole. Against the HEAD copy, whose refusal tested
#     `[ -n "${!v:-}" ]`, the four new set-but-EMPTY cases failed with `exit 0,
#     wanted 2` — 4 FAILED, and no other case. `GIT_DIR= <the gate>` walked
#     straight through a guard whose whole subject is git location variables.
#
#   - The nine git-variable assertions were VACUOUS, and this one was measured
#     rather than reasoned about. They greped the output for the bare variable NAME,
#     and the refusal prints `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
#     GIT_COMMON_DIR` as advice on every refusal — so the substring was present
#     whichever variable had actually been set, and the assertion could not fail.
#     Proof: strip `$poisoned` from the refusal's first line, so it names NOTHING,
#     and the bare-name form scores GREEN — zero failures. The same mutation against
#     the tightened form (`environment: $v`, matching after the colon) is 9 FAILED,
#     one per assertion. Nine that read as coverage and were decoration.
#
# NO ABSOLUTE SUITE TOTAL APPEARS ABOVE, and the two that did are why. A pass count
# beside a failure count, or a suite size after an `of`, is a true measurement that
# the next added case falsifies with no mechanism to say so — so what is recorded is
# the FAILURE count, which is the discrimination the mutation was actually claiming.
# `test-bounded-vendor-review.sh` enforces this across all four guard scripts; the
# totals here were invisible to it for one round because it scanned only its own two
# files, which is the same half-enumeration it had just been fixed for.
#
# Usage:  scripts/test-preflight-vendor-review.sh
#         BULK=1000 scripts/test-preflight-vendor-review.sh   # expected to FAIL
# Exit:   0 every case passed
#         1 at least one case failed
#         2 a fixture could not be built
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UNDER_TEST="$HERE/preflight-vendor-review.sh"
[ -f "$UNDER_TEST" ] || { echo "ERROR: $UNDER_TEST not found" >&2; exit 1; }

# The default is a file COUNT, but what the retired form actually trips on is
# BYTES — the 64 KiB pipe buffer — so no count is portable and this one is chosen
# for margin, not because 20,000 is significant. Bisected 2026-08-31 with the
# `untracked-N` names this suite creates: the retired form is correct at 61,893
# bytes of `git status --porcelain -uall` output (~3,500 files) and falls open
# with status 141 at 70,893 (~4,000). Shorter names need roughly four times as
# many files to reach the same bytes, which is the whole reason the assertion
# below measures the fixture instead of trusting the number.
#
# Verified in both directions on 2026-08-31: BULK=20000 and BULK=5000 both
# discriminate and the suite passes; BULK=1000 makes the anti-vacuity assertion
# FAIL and the suite exits 1. A test that has never been seen red is not evidence.
BULK="${BULK:-20000}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

# A repo with one commit, so `git status` behaves like a normal working tree.
new_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  : > "$d/tracked.txt"
  git -C "$d" add tracked.txt
  git -C "$d" -c user.email=t@example.invalid -c user.name=t commit -q -m init
}

# case <label> <expected-exit> <must-contain-or-empty> <fixture-fn>
case_run() {
  local label="$1" want_exit="$2" want_text="$3" fixture="$4"
  local dir="$TMP/case-$((passed + failed + 1))"

  # `set -e` is disabled inside an `if` condition and inside the left operand of
  # `||`, and that suppression reaches into functions called from there — so a
  # fixture invoked either way runs WITHOUT errexit and carries on past a failed
  # mkdir, leaving a half-built tree the case then reports `ok` against. This
  # explicit form is the only one of the three that aborts the fixture at its
  # first failure; the sibling suite documents all three with measurements.
  local fixture_status=0
  set +e
  ( set -e; "$fixture" "$dir" )
  fixture_status=$?
  set -e
  if [ "$fixture_status" -ne 0 ]; then
    echo "  ERROR $label (fixture failed to build; not a pass or a fail)" >&2
    exit 2
  fi

  local out status
  if out="$(bash "$UNDER_TEST" "$dir" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  local why=""
  [ "$status" -eq "$want_exit" ] || why="exit $status, wanted $want_exit"
  # Substring match with no pipeline: `printf | grep -q` is the very SIGPIPE trap
  # the guard under test exists because of, and under the `pipefail` set above it
  # would fail this suite in the opposite direction (a false FAIL when the wanted
  # text appears early in a long output).
  if [ -n "$want_text" ] && [ "${out#*"$want_text"}" = "$out" ]; then
    why="${why:+$why; }output missing: $want_text"
  fi

  if [ -z "$why" ]; then
    passed=$((passed + 1))
    echo "  ok    $label"
  else
    failed=$((failed + 1))
    echo "  FAIL  $label ($why)"
    awk '{ print "          | " $0 }' <<<"$out"
  fi
}

# ---------------------------------------------------------------------------
# The clean case, and the boundary the guard deliberately does not police.
# ---------------------------------------------------------------------------

f_clean() { new_repo "$1"; }
case_run "a clean worktree passes" 0 "clean worktree" f_clean

# These two BLOCK as of 2026-08-31, and until then they asserted the opposite —
# `0 untracked files` at exit 0 — on the reasoning that gitleaks could already
# reach a tracked file's edits. It cannot: leg 1 diffs `$BASE...HEAD`, so an
# unstaged or staged edit is read by no scan in the gate. Flipping an assertion
# is worth more comment than adding one, because a reader who trusts the old
# label will read the new behaviour as a regression.
f_modified_tracked() {
  new_repo "$1"
  echo "edited" > "$1/tracked.txt"
}
case_run "an unstaged edit to a TRACKED file is refused" 2 "1 uncommitted change(s)" f_modified_tracked
case_run "and the refusal names it" 2 "tracked.txt" f_modified_tracked

f_staged_tracked() {
  new_repo "$1"
  echo "staged" > "$1/tracked.txt"
  git -C "$1" add tracked.txt
}
case_run "a STAGED edit to a tracked file is refused (plain git diff misses it too)" 2 "1 uncommitted change(s)" f_staged_tracked

# Anti-vacuity for the widening, same shape as the SIGPIPE case at the bottom:
# reproduce the retired narrow decision against a tracked-edit fixture and require
# it to PASS. If it refuses too, the two cases above would go green against the
# very implementation they exist to reject.
NARROW_DIR="$TMP/narrow"
new_repo "$NARROW_DIR"
echo "edited" > "$NARROW_DIR/tracked.txt"
retired_narrow_status=0
(
  cd "$NARROW_DIR" || exit 9
  worktree=$(git status --porcelain --untracked-files=all)
  # The retired `^??`-only decision, verbatim in shape.
  untracked=$(grep '^??' <<<"$worktree")
  [ -z "$untracked" ] || exit 2
  exit 0
) && retired_narrow_status=0 || retired_narrow_status=$?

if [ "$retired_narrow_status" -eq 0 ]; then
  passed=$((passed + 1))
  echo "  ok    fixture discriminates: the retired ^??-only decision passed the tracked edit"
else
  failed=$((failed + 1))
  echo "  FAIL  fixture is VACUOUS — the retired ^??-only decision ALSO refused"
  echo "        (status $retired_narrow_status), so the two cases above would pass against the"
  echo "        narrow implementation they exist to reject. Check the fixture edits a"
  echo "        TRACKED file rather than creating a new one."
fi

f_gitignored() {
  new_repo "$1"
  echo "secrets.env" > "$1/.gitignore"
  echo "TOKEN=xyz" > "$1/secrets.env"
  git -C "$1" add .gitignore
  git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -q -m ignore
}
case_run "a gitignored file does not block (the vendor never receives it)" 0 "clean worktree" f_gitignored

# ---------------------------------------------------------------------------
# The refusals.
# ---------------------------------------------------------------------------

f_one_untracked() {
  new_repo "$1"
  echo "pasted credential" > "$1/scratch-notes.txt"
}
case_run "one untracked file is refused" 2 "1 uncommitted change(s) above, 1 of them untracked" f_one_untracked
case_run "the refusal NAMES the file rather than only counting it" 2 "scratch-notes.txt" f_one_untracked

f_untracked_in_subdir() {
  new_repo "$1"
  mkdir -p "$1/deep/nested"
  echo "export" > "$1/deep/nested/data.csv"
}
case_run "an untracked file in a subdirectory is refused (-uall, not -unormal)" 2 "deep/nested/data.csv" f_untracked_in_subdir

f_not_a_repo() { mkdir -p "$1"; }
case_run "a directory that is not a git repository fails CLOSED" 2 "cannot inspect the worktree" f_not_a_repo

f_missing_dir() {
  # The script is handed a path that does not exist. Building nothing IS the
  # fixture, so this function is deliberately empty of side effects.
  :
}
case_run "a path that does not exist fails CLOSED" 2 "cannot enter" f_missing_dir

# ---------------------------------------------------------------------------
# Rounds 9 to 11: git's own location variables, and the advice for clearing them.
#
# `case_run` cannot express these, because the defect is in the ENVIRONMENT rather
# than in the tree — so they get their own runner. The setup is two repos, one
# dirty and holding an unscanned untracked file, one clean, and the script is
# pointed at the DIRTY one while `GIT_DIR`/`GIT_WORK_TREE` point at the clean one.
#
# Round 9: that combination exited 0 and printed `clean worktree in .../dirty` —
# naming the dirty path, because `pwd` was honest and `git` was reading somewhere
# else. A confident answer about the wrong subject, and not exotic either, since
# git exports these to every hook it runs. Round 9 unset them.
#
# Round 10: unsetting them is not enough, and these cases assert the STRONGER
# behaviour that replaced it. The gate is an `&&` chain, so `review-plan-v2` and
# `coderabbit review` run in the caller's shell and inherit the variables anyway
# — the send can enumerate a repository this script never looked at. A child
# cannot unset a variable in its parent, so the script now REFUSES while any of
# the four is set, whatever the tree looks like.
#
# Which means the assertion below flipped: a CLEAN tree with `GIT_DIR` exported
# used to be required to exit 0 (proof the unset was a narrowing of trust rather
# than a blanket refusal) and is now required to exit 2. A reader who trusts the
# old label will read the new behaviour as a regression, so it is spelled out.
# The proof that this is not a blanket refusal now rests where it belongs: the
# clean-worktree case at the top of this file runs with no such variable set and
# must still pass.
# ---------------------------------------------------------------------------

GITENV_DIRTY="$TMP/gitenv-dirty"
GITENV_CLEAN="$TMP/gitenv-clean"
new_repo "$GITENV_DIRTY"
new_repo "$GITENV_CLEAN"
echo "SECRET=live" > "$GITENV_DIRTY/leaked.txt"   # untracked, so no scan read it

run_with_env() {  # run_with_env <dir> <VAR=VAL>... -> sets env_out / env_status
  local dir="$1"; shift
  env_out=""
  if env_out="$(env "$@" bash "$UNDER_TEST" "$dir" 2>&1)"; then
    env_status=0
  else
    env_status=$?
  fi
}

check() {  # check <label> <got-exit> <want-exit> <output> <must-contain-or-empty>
  local label="$1" got="$2" want="$3" out="$4" text="$5" why=""
  [ "$got" -eq "$want" ] || why="exit $got, wanted $want"
  if [ -n "$text" ] && [ "${out#*"$text"}" = "$out" ]; then
    why="${why:+$why; }output missing: $text"
  fi
  if [ -z "$why" ]; then
    passed=$((passed + 1)); echo "  ok    $label"
  else
    failed=$((failed + 1)); echo "  FAIL  $label ($why)" >&2
    printf '%s\n' "$out" | sed 's/^/          /' >&2
  fi
}

run_with_env "$GITENV_DIRTY" \
  "GIT_DIR=$GITENV_CLEAN/.git" "GIT_WORK_TREE=$GITENV_CLEAN"
check "an exported GIT_DIR/GIT_WORK_TREE cannot redirect the inspection" \
  "$env_status" 2 "$env_out" "git location variable(s) set"
# Asserted against the FIRST LINE, after the colon, and not against the bare names.
# This read `"GIT_DIR GIT_WORK_TREE"` until 2026-09-01 and was VACUOUS: the refusal's
# own `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR` advice contains that
# substring on every refusal, whichever variables were actually set, so the case could
# not tell a refusal that names them from one that does not. Same shape as every other
# entry in this file's history — the assertion could not fail.
check "and the refusal names the variables rather than only refusing" \
  "$env_status" 2 "$env_out" "environment: GIT_DIR GIT_WORK_TREE"

# Round 11: the refusal's ADVICE is part of the guard, so it is asserted like one.
# `env -u ...` applies to the command it prefixes and nothing else, so a caller
# told only to "use env -u" writes it on this script and leaves the vendor leg
# inheriting the variables — the guard defeated by following its own instructions.
# Measured 2026-08-31 with GIT_DIR exported: the prefix on the first command of an
# `&&` chain gave `leg1 sees: unset` then `leg2 sees: /tmp/other-probe-repo/.git`,
# while `env -u ... bash -c '<chain>'` gave `unset` for both. So the message has to
# say WHOLE chain and show the wrapping form; this case fails if it stops doing so.
check "the refusal shows the wrapping form, not a bare env -u prefix" \
  "$env_status" 2 "$env_out" "bash -c '<the entire gate>'"

# One case per variable, each set ALONE, because the refusal is a loop and a loop
# is where an off-by-one lives. `GIT_COMMON_DIR` had no case at all until round 10
# while the docs implied all four were covered — CodeRabbit caught the claim, not
# a bug, and the answer to an overclaimed test is a test rather than softer wording.
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; do
  run_with_env "$GITENV_CLEAN" "$v=$GITENV_DIRTY/.git"
  check "$v alone is refused, on a CLEAN tree, naming itself" \
    "$env_status" 2 "$env_out" "environment: $v"
done

# ROUND 12: the same four, set but EMPTY. Until 2026-09-01 the refusal tested
# `[ -n "${!v:-}" ]`, which cannot see an empty value, and this file said the case was
# "deliberately ignored" because the `unset` below the refusal covered it. That is
# round 10's mistake restated: the unset fixes THIS process while the rest of the gate
# runs in the caller's shell, so `GIT_DIR= <the gate>` passed here and the vendor leg
# inherited it. Empty is not equivalent to unset — measured 2026-09-01, `GIT_DIR=''`
# gives `fatal: not a git repository: ''` at 128 and `GIT_WORK_TREE=''` gives `The
# empty string is not a valid path` at 128, so git BREAKS rather than reading
# elsewhere. `GIT_INDEX_FILE=''` is the quiet one: it does not error at all, and git
# reports every tracked file as `D` deleted. That contradicts the /tmp/empty
# measurement recorded above (exit 128, `index file smaller than expected`), which is
# why the empty STRING needs its own case rather than being assumed covered by it.
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; do
  run_with_env "$GITENV_CLEAN" "$v="
  check "$v set but EMPTY is refused too, naming itself" \
    "$env_status" 2 "$env_out" "environment: $v"
done

# `GIT_INDEX_FILE` gets one more case, because the round-9 version of it was
# VACUOUS in a way worth recording. It passed an EMPTY index file, and an empty
# index is not a redefinition of "staged" — it is a broken file: measured
# 2026-08-31, `GIT_INDEX_FILE=/tmp/empty git status --porcelain` exits **128**
# with `index file smaller than expected`. So the old case was satisfied by the
# fail-closed path for unreadable repositories and proved nothing about the
# variable. With a VALID alternate index built from `HEAD`, `git status` exits 0
# and reports ` M tracked.txt` instead of `M  tracked.txt` — the staged-ness is
# hidden, the change is not, because `--porcelain -uall` compares the worktree to
# HEAD as well. CodeRabbit caught it; the round-10 refusal makes the distinction
# moot, and this case pins the valid-index form so it stays moot.
GITENV_STAGED="$TMP/gitenv-staged"
new_repo "$GITENV_STAGED"
echo "SECRET=live" > "$GITENV_STAGED/tracked.txt"
git -C "$GITENV_STAGED" add tracked.txt
GIT_INDEX_FILE="$TMP/alt-index" git -C "$GITENV_STAGED" read-tree HEAD
run_with_env "$GITENV_STAGED" "GIT_INDEX_FILE=$TMP/alt-index"
check "a VALID alternate GIT_INDEX_FILE is refused too (not via the 128 path)" \
  "$env_status" 2 "$env_out" "GIT_INDEX_FILE"

# Anti-vacuity for the four cases above: the refusal has to come from the
# ENVIRONMENT, not from the tree. Same fixture, same clean tree, nothing exported
# — it must pass. Without this, a script that refused everything would score four
# green cases and read as proof.
run_with_env "$GITENV_CLEAN"
check "fixture discriminates: the same clean tree passes with nothing exported" \
  "$env_status" 0 "$env_out" "clean worktree"

# ---------------------------------------------------------------------------
# A broken helper cannot manufacture a pass.
#
# Rounds 2, 5 and 7 were each one instance of a single class: a helper whose
# operational error was indistinguishable from its "found nothing" answer, sitting
# ABOVE the decision. The current script has no command above the decision at all
# — the test is `[ -n "$worktree" ]` on a variable already in hand, and `awk` runs
# only to word a refusal that has already been made.
#
# So this case pins the ORDERING rather than any one helper's status handling. A
# stub `awk` that always fails must leave a dirty tree refused (the number in the
# message may be wrong; the verdict may not be), and must leave a clean tree
# passing, because on a clean tree awk is never reached.
# ---------------------------------------------------------------------------

mkdir -p "$TMP/stubbin"
printf '#!/bin/sh\nexit 2\n' > "$TMP/stubbin/awk"
chmod +x "$TMP/stubbin/awk"

run_with_stub() {  # run_with_stub <dir> -> sets stub_out / stub_status
  stub_out=""
  if stub_out="$(PATH="$TMP/stubbin:$PATH" bash "$UNDER_TEST" "$1" 2>&1)"; then
    stub_status=0
  else
    stub_status=$?
  fi
}

DIRTY_STUB="$TMP/awkfail-dirty"
new_repo "$DIRTY_STUB"
echo "pasted credential" > "$DIRTY_STUB/scratch.txt"
run_with_stub "$DIRTY_STUB"
if [ "$stub_status" -eq 2 ]; then
  passed=$((passed + 1)); echo "  ok    a broken awk still refuses a dirty tree (exit 2)"
else
  failed=$((failed + 1))
  echo "  FAIL  a broken awk turned a dirty tree into exit $stub_status, wanted 2 —"
  echo "        which means something above the decision can fail open again."
  awk_out_dump=$(printf '%s\n' "$stub_out")
  printf '%s\n' "$awk_out_dump" | sed 's/^/          | /'
fi

CLEAN_STUB="$TMP/awkfail-clean"
new_repo "$CLEAN_STUB"
run_with_stub "$CLEAN_STUB"
if [ "$stub_status" -eq 0 ]; then
  passed=$((passed + 1)); echo "  ok    and a broken awk does not affect a clean tree (never reached)"
else
  failed=$((failed + 1))
  echo "  FAIL  a broken awk changed the clean-tree verdict: exit $stub_status, wanted 0."
  echo "        awk is supposed to run only inside the refusal branch."
fi

# ---------------------------------------------------------------------------
# The SIGPIPE round, with the assertion that makes it non-vacuous.
# ---------------------------------------------------------------------------

BULK_DIR="$TMP/bulk"
new_repo "$BULK_DIR"
for i in $(seq 1 "$BULK"); do : > "$BULK_DIR/untracked-$i"; done

bulk_out=""
bulk_status=0
if bulk_out="$(bash "$UNDER_TEST" "$BULK_DIR" 2>&1)"; then
  bulk_status=0
else
  bulk_status=$?
fi

if [ "$bulk_status" -eq 2 ]; then
  passed=$((passed + 1)); echo "  ok    $BULK untracked files are refused (exit 2)"
else
  failed=$((failed + 1)); echo "  FAIL  $BULK untracked files: exit $bulk_status, wanted 2"
fi

# The cap is announced rather than silent, and the number it announces is right.
#
# This assertion used to be `[ "${bulk_out#*and }" != "$bulk_out" ]`, which was
# VACUOUS: the refusal message itself contains "...and no local scan has read
# them", so the substring matched whether or not the listing announced anything.
# Verified 2026-08-31 by deleting the `... and %d more` line from a copy of the
# script under test — the suite still reported `ok    the capped listing says how
# many it did not print`, 12 passed, exit 0. A vacuous assertion inside the file
# whose stated thesis is anti-vacuity, caught by CodeRabbit rather than by this
# suite, which is the lesson worth keeping more than the fix is.
#
# The form below derives the cap from the listing actually printed and requires
# the announced remainder to equal BULK minus it. So it checks the arithmetic,
# not the presence of a word, and it stays correct if LIST_CAP changes.
listed=$(grep -c '^  ?? ' <<<"$bulk_out" || true)
want_more=$((BULK - listed))
if [ "$listed" -gt 0 ] && [ "${bulk_out#*"... and $want_more more"}" != "$bulk_out" ]; then
  passed=$((passed + 1)); echo "  ok    the listing printed $listed and announced the other $want_more"
else
  failed=$((failed + 1))
  echo "  FAIL  the cap was not announced correctly: printed $listed of $BULK, so the"
  echo "        output should contain '... and $want_more more' and does not."
  awk '{ print "          | " $0 }' <<<"$bulk_out"
fi

# Anti-vacuity. Reproduce the retired form against this same fixture and require
# it to fall open. If it does not, BULK is too low for this machine and the case
# above proves nothing — which is a failure of the test, reported as one.
retired_form_status=0
(
  set -o pipefail
  cd "$BULK_DIR" || exit 9
  worktree=$(git status --porcelain --untracked-files=all)
  printf '%s\n' "$worktree" | grep -q '^??'
) && retired_form_status=0 || retired_form_status=$?

if [ "$retired_form_status" -ne 0 ]; then
  passed=$((passed + 1))
  echo "  ok    fixture discriminates: the retired pipeline form fell open here (status $retired_form_status)"
else
  failed=$((failed + 1))
  echo "  FAIL  fixture is VACUOUS at BULK=$BULK — the retired pipeline form also"
  echo "        refused (status 0), so the case above would pass against the very"
  echo "        implementation it exists to reject. Raise BULK until this fails."
fi

echo ""
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
