#!/usr/bin/env bash
# Fixture suite for scripts/fleet-speckit-upgrade.sh — specifically for whether a
# failure inside the per-repo vendoring block is REPORTED as one.
#
# It exists because that block spent its whole life as `if ( set -e ... ); then`,
# which does not do what it reads as: bash disables errexit for the entire
# condition of an `if`, and that suppression reaches into an explicit `set -e` in
# a subshell used as that condition. So every step ran regardless of the previous
# one's failure and the block's status was just its LAST command's — the push,
# the one step that can still succeed after the vendoring it was supposed to
# publish has failed. The result was `DONE: pushed` over a broken tree, and a
# branch on the remote to match.
#
# Reading the script does not reveal that. Only running it does, which is what
# this file is for. Case B runs the retired form against the same fixture and
# FAILS if it does not misreport, so the suite says when it has stopped testing
# anything instead of going quietly green.
#
# `specify` is stubbed on PATH: the subject is error propagation, not the
# vendoring, and the real CLI makes each case slow and network-dependent.
#
# Seen red, 2026-08-31, against a staged copy of this repo whose fleet script
# carried the retired form: case A's five assertions all failed and the run
# printed `DONE: pushed upgrade/spec-kit-v9.9.9` directly under the assert
# step's `No such file or directory`, at `summary: 1 ok, 0 failed`, exit 0.
# 5 passed, 5 failed.
#
# Usage:  scripts/test-fleet-speckit-upgrade.sh
# Exit:   0 every case passed
#         1 at least one case failed
#         2 a fixture could not be built
set -uo pipefail
unset CDPATH

HERE="$(cd "$(dirname "$0")" && pwd)"
REAL="$(cd "$HERE/.." && pwd)"
UNDER_TEST="$HERE/fleet-speckit-upgrade.sh"
[ -f "$UNDER_TEST" ] || { echo "ERROR: $UNDER_TEST not found" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The stub's version string is what the branch name is built from, so it is
# deliberately not a real spec-kit version — a fixture branch must not be
# confusable with one a real wave would create.
VER=9.9.9
FIXTURE_BRANCH="upgrade/spec-kit-v$VER"

passed=0
failed=0

# Assertions take the predicate as a COMMAND, not as a precomputed `$?`. The
# first draft passed `"$([ $? -ne 0 ] && echo 0 || echo 1)"`, where `$?` is read
# inside a command substitution and so is not reliably the status of the line
# above it — an assertion whose input is the wrong status is worse than none.
pass() { passed=$((passed + 1)); echo "  ok    $1"; }
fail() { failed=$((failed + 1)); echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; }

expect() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
refute() { local label="$1"; shift; if "$@"; then fail "$label"; else pass "$label"; fi; }

contains() { [ "${1#*"$2"}" != "$1" ]; }
status_is() { [ "$1" -eq "$2" ]; }
status_isnt() { [ "$1" -ne "$2" ]; }

# --- the stand-in $TEMPLATE the script resolves from its own location ---------
TPL="$TMP/tpl"
mkdir -p "$TPL/scripts" "$TPL/.specify" "$TMP/bin" "$TMP/fleet" "$TMP/bare"

cat > "$TMP/bin/specify" <<STUB
#!/bin/sh
case "\$1" in
  version) echo "  CLI Version $VER" ;;
  *)       exit 0 ;;
esac
STUB
chmod +x "$TMP/bin/specify"
export PATH="$TMP/bin:$PATH"

cp "$UNDER_TEST" "$TPL/scripts/fixed.sh"
cp "$REAL/.specify/extensions.yml" "$TPL/.specify/extensions.yml"

# Case B's subject: reconstruct the retired `if`-condition form from the current
# one. Built by transformation rather than checked in as a second copy, so it
# cannot drift away from the code it is supposed to be the "before" of.
# shellcheck disable=SC2016  # the $vend_status in these patterns is literal
sed -e 's|^  ( set -e$|  if ( set -e|' \
    -e 's|^  )$|  ); then|' \
    -e '/^  vend_status=\$?$/d' \
    -e 's|^  if \[ "\$vend_status" -eq 0 \]; then$||' \
    "$TPL/scripts/fixed.sh" > "$TPL/scripts/retired.sh"
chmod +x "$TPL/scripts/fixed.sh" "$TPL/scripts/retired.sh"
if ! bash -n "$TPL/scripts/retired.sh" 2>/dev/null || ! grep -q 'if ( set -e' "$TPL/scripts/retired.sh"; then
  echo "ERROR: could not rebuild the retired if-condition form from the current" >&2
  echo "       script. The sed above no longer matches it, so case B would test" >&2
  echo "       nothing. Exiting 2 rather than reporting a pass." >&2
  exit 2
fi

seed_repo() {  # seed_repo <name> — a repo with a bare origin, clean, one skill
  local name="$1"
  local bare="$TMP/bare/$name.git"
  local dir="$TMP/fleet/$name"
  mkdir -p "$bare"
  git init -q --bare -b main "$bare"
  git init -q -b main "$dir"
  git -C "$dir" config user.email t@example.invalid
  git -C "$dir" config user.name t
  mkdir -p "$dir/.specify" "$dir/.claude/skills/speckit-plan"
  echo seed > "$dir/README.md"
  # The stubbed init vendors nothing, so the skill the assert step reads is
  # seeded here and committed — an untracked one would trip the dirty-tree guard
  # and the case would report a skip as a failure to push.
  printf -- '---\nname: speckit-plan\ndescription: d\ndisable-model-invocation: false\n---\n\nbody\n' \
    > "$dir/.claude/skills/speckit-plan/SKILL.md"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m init
  git -C "$dir" remote add origin "$bare"
  git -C "$dir" push -q -u origin main
}

# Output goes to a FILE and the status into a global, because a function whose
# output is captured with `$( )` runs in a subshell — the first draft set
# `run_status` in there and the caller read an unbound variable.
run_status=0
run_fleet() {  # run_fleet <script> <repo> <outfile>
  FLEET_ROOT="$TMP/fleet" FLEET_REPOS="$2" "$1" --apply > "$3" 2>&1
  run_status=$?
}

remote_has_branch() { git -C "$TMP/bare/$1.git" show-ref --verify --quiet "refs/heads/$FIXTURE_BRANCH"; }
has_new_commit()    { [ -n "$(git -C "$TMP/fleet/$1" log --oneline "origin/main..HEAD" 2>/dev/null)" ]; }

# ---------------------------------------------------------------------------
# A. A failure partway through the block is reported, and stops the push.
# ---------------------------------------------------------------------------
echo "A. mid-block failure (the assert step's path does not exist)"
rm -f "$TPL/scripts/assert-skill-invocation.sh"
seed_repo alpha || { echo "ERROR: could not build fixture alpha" >&2; exit 2; }
run_fleet "$TPL/scripts/fixed.sh" alpha "$TMP/a.out"
a_status=$run_status; a_out="$(cat "$TMP/a.out")"

expect "the repo is reported FAILED"                          contains "$a_out" "FAILED at exit"
refute "and NOT reported DONE"                                contains "$a_out" "DONE: pushed"
expect "the overall exit is nonzero (was $a_status)"          status_isnt "$a_status" 0
refute "the push never ran (origin has no $FIXTURE_BRANCH)"   remote_has_branch alpha
refute "no commit was made on top of main"                    has_new_commit alpha
contains "$a_out" "FAILED at exit" || awk '{ print "          | " $0 }' <<<"$a_out"

# ---------------------------------------------------------------------------
# B. Anti-vacuity: the retired form must misreport the SAME fixture.
# ---------------------------------------------------------------------------
echo "B. the retired \`if ( set -e ... ); then\` form, same fixture"
seed_repo beta || { echo "ERROR: could not build fixture beta" >&2; exit 2; }
run_fleet "$TPL/scripts/retired.sh" beta "$TMP/b.out"
b_status=$run_status; b_out="$(cat "$TMP/b.out")"

if contains "$b_out" "DONE: pushed" && [ "$b_status" -eq 0 ]; then
  passed=$((passed + 1))
  echo "  ok    fixture discriminates: the retired form said DONE at exit 0"
else
  failed=$((failed + 1))
  echo "  FAIL  fixture is VACUOUS — the retired form did NOT misreport here, so"
  echo "        case A would pass against the very implementation it exists to"
  echo "        reject. The fixture no longer fails mid-block; fix the fixture."
  awk '{ print "          | " $0 }' <<<"$b_out"
fi
expect "and the retired form pushed the branch anyway (that is the defect)" remote_has_branch beta

# ---------------------------------------------------------------------------
# C. The happy path still reports success, so A is not passing by refusing all.
# ---------------------------------------------------------------------------
echo "C. happy path"
cp "$REAL/scripts/assert-skill-invocation.sh" "$TPL/scripts/assert-skill-invocation.sh"
seed_repo gamma || { echo "ERROR: could not build fixture gamma" >&2; exit 2; }
run_fleet "$TPL/scripts/fixed.sh" gamma "$TMP/c.out"
c_status=$run_status; c_out="$(cat "$TMP/c.out")"

expect "the repo is reported DONE"                   contains "$c_out" "DONE: pushed"
expect "the overall exit is 0 (was $c_status)"       status_is "$c_status" 0
expect "origin has $FIXTURE_BRANCH"                  remote_has_branch gamma
contains "$c_out" "DONE: pushed" || awk '{ print "          | " $0 }' <<<"$c_out"

echo ""
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
