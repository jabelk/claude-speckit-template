#!/usr/bin/env bash
# Fixture suite for scripts/assert-skill-invocation.sh.
#
# Why this is a committed script and not an ad-hoc loop in a terminal: the thing
# under test has now been wrong three review rounds running, every time in the
# same way — a spelling of `disable-model-invocation` that the matcher failed to
# recognise and therefore SILENTLY SKIPPED, leaving a skill model-disabled while
# the script exited 0. Each of those spellings is a fixture below. An ad-hoc loop
# that proved the fix once does not stop the fourth one.
#
# Each case names the exit code it expects and, where it matters, a substring the
# output must contain — because "exit 1" is not the assertion. A fixture whose
# key is unrecognised and one whose key is refused both exit non-zero for
# different reasons, and only one of them is the behaviour being proven.
#
# Usage:  scripts/test-assert-skill-invocation.sh
# Exit:   0 every case passed
#         1 at least one case failed
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UNDER_TEST="$HERE/assert-skill-invocation.sh"
[ -x "$UNDER_TEST" ] || [ -f "$UNDER_TEST" ] || {
  echo "ERROR: $UNDER_TEST not found" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

# make_skill <repo> <skill-name> <frontmatter-body-with-literal-newlines>
# Writes .claude/skills/<name>/SKILL.md. Uses printf %b so a fixture can embed a
# literal backslash-u escape without this harness decoding it — that distinction
# is the entire subject of cases 6 through 8, and the first attempt at proving
# them wrote a plain quoted key instead of an escape, so both the old and the new
# version failed and the test proved nothing.
make_skill() {
  local repo="$1" name="$2" front="$3"
  mkdir -p "$repo/.claude/skills/$name"
  {
    echo "---"
    printf '%b\n' "$front"
    echo "---"
    echo ""
    echo "# $name"
  } > "$repo/.claude/skills/$name/SKILL.md"
}

# case <label> <expected-exit> <must-contain-or-empty> <fixture-fn>
# The fixture function receives a fresh repo root and populates it.
case_run() {
  local label="$1" want_exit="$2" want_text="$3" fixture="$4"
  local repo="$TMP/case-$((passed + failed + 1))"
  mkdir -p "$repo"
  "$fixture" "$repo"

  local out status
  out="$(bash "$UNDER_TEST" "$repo" 2>&1)"
  status=$?

  local why=""
  [ "$status" -eq "$want_exit" ] || why="exit $status, wanted $want_exit"
  if [ -n "$want_text" ] && ! printf '%s' "$out" | grep -qF -- "$want_text"; then
    why="${why:+$why; }output missing: $want_text"
  fi

  if [ -z "$why" ]; then
    passed=$((passed + 1))
    echo "  ok    $label"
  else
    failed=$((failed + 1))
    echo "  FAIL  $label ($why)"
    printf '%s\n' "$out" | awk '{ print "          | " $0 }'
  fi
}

# A skills dir always needs at least one well-formed skill, otherwise the
# examined-nothing guard fires and masks whatever the case is actually about.
baseline() { make_skill "$1" "good" "name: good\ndisable-model-invocation: false"; }

# ---------------------------------------------------------------------------
# The accepted forms, and the default.
# ---------------------------------------------------------------------------

f_bare_false() { baseline "$1"; }
case_run "bare false is accepted unchanged" 0 "0 changed" f_bare_false

f_bare_true() {
  baseline "$1"
  make_skill "$1" "flipme" "name: flipme\ndisable-model-invocation: true"
}
case_run "bare true is flipped" 0 "flipped: flipme" f_bare_true

f_no_key() {
  baseline "$1"
  make_skill "$1" "nokey" "name: nokey\ndescription: no flag at all"
}
case_run "absent key relies on the default" 0 "1 rely on the default" f_no_key

f_only_keyless() {
  make_skill "$1" "nokey" "name: nokey\ndescription: no flag at all"
}
case_run "a fleet that all omits the key is NOT examined-nothing" 0 "1 rely on the default" f_only_keyless

# ---------------------------------------------------------------------------
# Structural refusals.
# ---------------------------------------------------------------------------

f_no_frontmatter() {
  baseline "$1"
  mkdir -p "$1/.claude/skills/bare"
  printf '# bare\n\nNo frontmatter here.\n' > "$1/.claude/skills/bare/SKILL.md"
}
case_run "no frontmatter fails loudly" 1 "has no YAML frontmatter block" f_no_frontmatter

f_duplicate() {
  baseline "$1"
  make_skill "$1" "dupe" \
    "name: dupe\ndisable-model-invocation: false\ndescription: x\ndisable-model-invocation: true"
}
case_run "duplicate key fails (YAML takes the last)" 1 "declares disable-model-invocation 2 times" f_duplicate

f_empty_dir() { mkdir -p "$1/.claude/skills"; }
case_run "no SKILL.md at all fails" 1 "found no SKILL.md" f_empty_dir

# ---------------------------------------------------------------------------
# Rule A — a quoted KEY is refused without being interpreted. Each of these
# passed a previous version of the matcher as "no key present", which meant the
# skill stayed model-disabled and the script exited 0.
# ---------------------------------------------------------------------------

f_quoted_key() {
  baseline "$1"
  make_skill "$1" "quoted" '"disable-model-invocation": true\nname: quoted'
}
case_run "rule A: plainly quoted key refused" 1 "quotes a key in its frontmatter" f_quoted_key

f_u4_escape() {
  baseline "$1"
  # i is `i`, so this spells disable-model-invocation to a YAML parser.
  make_skill "$1" "u4" '"d\\u0069sable-model-invocation": true\nname: u4'
}
case_run "rule A: \\uXXXX-escaped key refused" 1 "quotes a key in its frontmatter" f_u4_escape

f_u8_escape() {
  baseline "$1"
  # The eight-digit form. Round three of review found the matcher decoded the
  # four-digit and \\xXX forms but not this one.
  make_skill "$1" "u8" '"d\\U00000069sable-model-invocation": true\nname: u8'
}
case_run "rule A: \\UXXXXXXXX-escaped key refused" 1 "quotes a key in its frontmatter" f_u8_escape

f_hex_escape() {
  baseline "$1"
  make_skill "$1" "hex" '"d\\x69sable-model-invocation": true\nname: hex'
}
case_run "rule A: \\xXX-escaped key refused" 1 "quotes a key in its frontmatter" f_hex_escape

f_quoted_value_only() {
  baseline "$1"
  # A quoted VALUE is not a quoted key. This must NOT trip rule A — the fleet's
  # own frontmatter has `author: "jabelk"`, and refusing that would be a guard
  # that fails every real repo.
  make_skill "$1" "authored" \
    "name: authored\nmetadata:\n  author: \"jabelk\"\ndisable-model-invocation: false"
}
case_run "rule A does not fire on a quoted value" 0 "0 changed" f_quoted_value_only

# ---------------------------------------------------------------------------
# Rule B — any mention that is not one of the two accepted byte sequences is
# refused rather than normalised.
# ---------------------------------------------------------------------------

f_comment_no_space() {
  baseline "$1"
  # `#` opens a YAML comment only after whitespace, so this value is the STRING
  # "false#text". A previous version stripped it and read `false`.
  make_skill "$1" "hash" "name: hash\ndisable-model-invocation: false#text"
}
case_run "rule B: false#text refused, not read as false" 1 "in a form this" f_comment_no_space

f_trailing_comment() {
  baseline "$1"
  make_skill "$1" "cmt" "name: cmt\ndisable-model-invocation: true # keep it"
}
case_run "rule B: trailing comment refused" 1 "in a form this" f_trailing_comment

f_mismatched_quotes() {
  baseline "$1"
  make_skill "$1" "mixq" "name: mixq\ndisable-model-invocation: \"true'"
}
case_run "rule B: mismatched-quote value refused" 1 "in a form this" f_mismatched_quotes

f_indented_key() {
  baseline "$1"
  make_skill "$1" "nested" \
    "name: nested\nmetadata:\n  disable-model-invocation: true"
}
case_run "rule B: key indented under another mapping refused" 1 "Indentation is not cosmetic" f_indented_key

f_trailing_space() {
  baseline "$1"
  make_skill "$1" "tspace" "name: tspace\ndisable-model-invocation: true "
}
case_run "rule B: trailing whitespace refused" 1 "in a form this" f_trailing_space

# ---------------------------------------------------------------------------
# Frontmatter only — a documented example in the BODY is prose, not config.
# ---------------------------------------------------------------------------

f_body_only_false() {
  baseline "$1"
  mkdir -p "$1/.claude/skills/documented"
  {
    echo "---"
    echo "name: documented"
    echo "disable-model-invocation: true"
    echo "---"
    echo ""
    echo "Set it like this:"
    echo ""
    echo '```yaml'
    echo "disable-model-invocation: false"
    echo '```'
  } > "$1/.claude/skills/documented/SKILL.md"
}
case_run "body example does not satisfy the check" 0 "flipped: documented" f_body_only_false

f_body_only_survives() {
  baseline "$1"
  mkdir -p "$1/.claude/skills/documented"
  {
    echo "---"
    echo "name: documented"
    echo "disable-model-invocation: false"
    echo "---"
    echo ""
    echo '```yaml'
    echo "disable-model-invocation: true"
    echo '```'
  } > "$1/.claude/skills/documented/SKILL.md"
  echo "$1/.claude/skills/documented/SKILL.md" > "$TMP/body-check-path"
}
case_run "body example is not rewritten" 0 "0 changed" f_body_only_survives
if [ -f "$TMP/body-check-path" ] && grep -qF "disable-model-invocation: true" "$(cat "$TMP/body-check-path")"; then
  passed=$((passed + 1)); echo "  ok    body example survived the rewrite verbatim"
else
  failed=$((failed + 1)); echo "  FAIL  body example was rewritten (the mirror bug)"
fi

# ---------------------------------------------------------------------------
# The /ship exemption is a CLAIM about the file, so it gets verified.
# ---------------------------------------------------------------------------

f_ship_true() {
  baseline "$1"
  make_skill "$1" "ship" "name: ship\ndisable-model-invocation: true"
}
case_run "ship with true is exempt and verified" 0 "exempt: ship" f_ship_true

f_ship_false() {
  baseline "$1"
  make_skill "$1" "ship" "name: ship\ndisable-model-invocation: false"
}
case_run "ship with false fails (exemption not satisfied)" 1 "listed in KEEP_DISABLED" f_ship_false

f_ship_missing_key() {
  baseline "$1"
  make_skill "$1" "ship" "name: ship\ndescription: no flag"
}
case_run "ship with no key fails" 1 "listed in KEEP_DISABLED" f_ship_missing_key

f_ship_indented_only() {
  baseline "$1"
  # The round-two finding, stated as a fixture: the exemption was satisfied by an
  # indented key nested under `metadata:` while the ROOT key was absent, so merge,
  # push and deploy were model-invocable and the script said they were not.
  make_skill "$1" "ship" \
    "name: ship\nmetadata:\n  disable-model-invocation: true"
}
case_run "ship exemption is NOT satisfied by an indented key" 1 "Indentation is not cosmetic" f_ship_indented_only

echo ""
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
