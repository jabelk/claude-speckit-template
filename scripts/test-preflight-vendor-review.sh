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
# Seen red, 2026-08-31: against a staged copy of the guard carrying the retired
# two-outcome `if untracked=$(grep ...)` form, the grep-fail-closed case failed
# with `exit 0, wanted 2` and the output line `preflight: 0 untracked files in
# .../grepfail at this moment — the only thing checked` — the clean-tree pass,
# printed by a run whose `grep` never searched. 13 passed, 1 failed, exit 1.
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
case_run "a clean worktree passes" 0 "0 untracked files" f_clean

f_modified_tracked() {
  new_repo "$1"
  echo "edited" > "$1/tracked.txt"
}
case_run "an uncommitted change to a TRACKED file does not block" 0 "0 untracked files" f_modified_tracked

f_staged_tracked() {
  new_repo "$1"
  echo "staged" > "$1/tracked.txt"
  git -C "$1" add tracked.txt
}
case_run "a staged change to a tracked file does not block" 0 "0 untracked files" f_staged_tracked

f_gitignored() {
  new_repo "$1"
  echo "secrets.env" > "$1/.gitignore"
  echo "TOKEN=xyz" > "$1/secrets.env"
  git -C "$1" add .gitignore
  git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -q -m ignore
}
case_run "a gitignored file does not block (the vendor never receives it)" 0 "0 untracked files" f_gitignored

# ---------------------------------------------------------------------------
# The refusals.
# ---------------------------------------------------------------------------

f_one_untracked() {
  new_repo "$1"
  echo "pasted credential" > "$1/scratch-notes.txt"
}
case_run "one untracked file is refused" 2 "1 untracked file(s)" f_one_untracked
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
# A `grep` that cannot run, with the assertion that makes it non-vacuous.
#
# The fixture worktree is CLEAN, so exit 2 here can only come from the check on
# grep's status — which is what makes the case unambiguous. `grep` has three
# outcomes and `if` has two, so the retired `if untracked=$(grep ...)` form reads
# an operational error as "matched nothing" and reports the clean-tree pass.
# ---------------------------------------------------------------------------

STUB_DIR="$TMP/grepfail"
new_repo "$STUB_DIR"
mkdir -p "$TMP/stubbin"
printf '#!/bin/sh\nexit 2\n' > "$TMP/stubbin/grep"
chmod +x "$TMP/stubbin/grep"

stub_out=""
stub_status=0
if stub_out="$(PATH="$TMP/stubbin:$PATH" bash "$UNDER_TEST" "$STUB_DIR" 2>&1)"; then
  stub_status=0
else
  stub_status=$?
fi

if [ "$stub_status" -eq 2 ] && [ "${stub_out#*"grep exited 2"}" != "$stub_out" ]; then
  passed=$((passed + 1)); echo "  ok    a grep that cannot run fails CLOSED (exit 2)"
else
  failed=$((failed + 1))
  echo "  FAIL  a broken grep did not fail closed: exit $stub_status, wanted 2 with 'grep exited 2'"
  awk '{ print "          | " $0 }' <<<"$stub_out"
fi

# Anti-vacuity, same shape as the bulk case below: reproduce the retired form
# against this same stub and require it to fall open.
retired_grep_status=0
(
  export PATH="$TMP/stubbin:$PATH"
  cd "$STUB_DIR" || exit 9
  worktree=$(git status --porcelain --untracked-files=all)
  # The retired two-outcome form, verbatim in shape.
  if untracked=$(grep '^??' <<<"$worktree"); then
    : "$untracked"
    exit 2
  fi
  exit 0
) && retired_grep_status=0 || retired_grep_status=$?

if [ "$retired_grep_status" -eq 0 ]; then
  passed=$((passed + 1))
  echo "  ok    fixture discriminates: the retired if-condition form read the broken grep as clean"
else
  failed=$((failed + 1))
  echo "  FAIL  fixture is VACUOUS — the retired if-condition form also refused"
  echo "        (status $retired_grep_status), so the case above would pass against the very"
  echo "        implementation it exists to reject. Check the grep stub is on PATH."
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
