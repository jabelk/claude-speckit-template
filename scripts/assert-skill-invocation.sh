#!/usr/bin/env bash
# Assert `disable-model-invocation: false` across a repo's project-scoped skills.
#
# Why this exists as a script rather than a hand edit: it is a stream edit over
# many files, and the only sanctioned form of that is a committed script that
# verifies its own end state and fails loudly. A silent no-op here leaves skills
# unreachable by the model, which is the exact condition this exists to end, so
# "did nothing" and "worked" must not print the same thing.
#
# History. setup.sh did the opposite until 2026-08-28: it flipped upstream's
# `false` to `true` on every re-vendor so that every workflow-shaped skill was a
# slash command only. Across the fleet the operator then reverted it by hand in
# each new project (one downstream project had all 11 reverted; another had 10
# of 11, and the one missed file is how drift starts). A default reverted in
# every instance is a chore, not a safety property.
#
# If a specific skill genuinely must be slash-command-only, set the flag in THAT
# skill's frontmatter and record why there, then add it to KEEP_DISABLED below so
# this script stops fighting it.
#
# Only the YAML frontmatter counts. The first version of this script grepped the
# whole file, which made it satisfiable by prose: a SKILL.md documenting the key
# in a fenced code block (this fleet's own docs do exactly that) could read
# `disable-model-invocation: false` in its body while the frontmatter said
# `true`, and the check passed. The rewrite had the mirror bug, editing the
# documentation instead of the setting. A guard that a doc example can satisfy is
# not a guard. Duplicate keys are rejected for the same reason: YAML takes the
# last one, so a leading `false` with a trailing `true` is a file that lies to
# anything reading it line-first. CodeRabbit caught this on round 2.
#
# This script FIXES rather than merely validating, and that is deliberate. Review
# has proposed twice that it drop the rewrite and just fail on a `true`. Declined:
# failing would hand the operator back exactly the chore this replaced — 11 files
# reverted by hand per project, once per re-vendor — and a gate whose remedy is
# "go edit 11 files" is one that gets skipped. It still fails loudly on anything
# it cannot repair: any spelling of the key other than the two it accepts, a
# duplicate key, absent frontmatter, or a rewrite that did not take. What it
# repairs it names, one `flipped:` line per file, so a run is never silent about
# having changed the tree.
#
# Usage:  scripts/assert-skill-invocation.sh [REPO_ROOT]
# Exit:   0 every skill asserts false in frontmatter (or is verified exempt)
#         1 a file's frontmatter is wrong/ambiguous/absent, or no skills found
#         2 a required tool is missing
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

# Skill directory names that are DELIBERATELY slash-command-only. An entry here
# needs a stated reason, right here, and the same reason in the skill's own
# frontmatter comment so it survives being read out of context.
#
#   ship — merges PRs, pushes branches, and runs a project's promote/deploy
#     steps. Every one of those is externally visible and hard to reverse, which
#     is the one category that should never fire on a model's judgement that the
#     moment looked right. This reason was already recorded in
#     a downstream project's setup.sh before this script existed; it is honoured
#     rather than overridden, and it is the only exception.
KEEP_DISABLED=(ship)

command -v perl >/dev/null || { echo "ERROR: perl required" >&2; exit 2; }
command -v awk >/dev/null || { echo "ERROR: awk required" >&2; exit 2; }

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: no $SKILLS_DIR — nothing to assert. Wrong repo root?" >&2
  exit 1
fi

# Line number of the frontmatter's closing `---`, or empty if the file does not
# open a frontmatter block on line 1.
frontmatter_end() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { print NR; exit }' "$1"
}

# Recognising this key stopped being a pattern-matching problem and became a
# YAML-decoding problem, and three review rounds found three different ways the
# decoding was wrong — each one a SILENT skip that let the script exit 0 with a
# skill still model-disabled, because a verified `ship` exemption is enough to
# keep the examined-nothing guard quiet:
#
#   1. Matching only bare `disable-model-invocation:` missed
#      `"disable-model-invocation": true`.
#   2. Allowing optional quotes still missed
#      `"disable-model-invocation": true` — a double-quoted YAML scalar
#      decodes \uXXXX.
#   3. Decoding \uXXXX and \xXX still missed \UXXXXXXXX, the eight-digit form.
#      And `disable-model-invocation: false#text` is the *string* `false#text`
#      in YAML, because `#` only opens a comment after whitespace — yet it
#      normalised to `false` and read as correctly set. And an indented
#      `disable-model-invocation: true` nested under `metadata:` satisfied the
#      /ship exemption while the ROOT key was absent, which means merge, push
#      and deploy were model-invocable and this script said they were not.
#
# Round three is where the approach was wrong rather than incomplete: each fix
# decoded one more escape form, and YAML has more. So the matcher no longer
# decodes anything. It accepts exactly two byte sequences at column zero and
# REFUSES everything else that could conceivably be this key, which is immune to
# every escape form because it never interprets one.
#
# The three rules, in the order they are applied:
#
#   A. A quoted KEY in any key position is refused outright, whatever it spells —
#      the start of a line, inside a flow mapping, or after an explicit-key `?` —
#      as is any escape sequence anywhere in the frontmatter. Verified against
#      every SKILL.md in this fleet: no legitimate frontmatter quotes a key,
#      writes a flow mapping, or contains an escape, so this costs nothing. It is
#      what makes escape handling unnecessary. This rule said "anywhere" and meant
#      "at the start of a line" until 2026-08-29, and the gap was exploitable —
#      see the function.
#   B. Any line mentioning the key that is not one of the two accepted byte
#      sequences is refused: indentation, trailing comments, quoted values,
#      `false#text`, anything. Refusing is safe where guessing is not.
#   C. Only `disable-model-invocation: true` and
#      `disable-model-invocation: false`, at column zero, are accepted.
#
# awk only, and no `sub` on the matched text: the comparison is string equality
# against a literal, which is the one form of matching that cannot be talked
# into accepting something else.

# Frontmatter lines whose KEY is quoted — rule A. A quoted VALUE
# (`author: "jabelk"`) is untouched, because the quote there is not in a key
# position.
#
# YAML has more key positions than the start of a line, and until 2026-08-29 this
# function only knew that one. Measured on that date: a frontmatter of
# `{"disable-model-invocation": true, "name": "flow"}` passed the whole
# script — rule A never saw a leading quote because the line starts with `{`, and
# rule B never saw the key because the `i` escape hides the bytes it
# normalises. The script exited **0** reporting `1 rely on the default` while that
# skill was in fact model-DISABLED, which is verbatim the silent skip these three
# rules exist to prevent, reached through the one position they did not cover.
# CodeRabbit caught it.
#
# So every key position is refused, and the whole line is refused rather than
# parsed — a flow mapping is a place a key can hide, not a construct this script
# should learn to read. Verified across all 299 SKILL.md files on this machine:
# not one writes a flow mapping or an escape anywhere in its frontmatter, so
# refusing both costs nothing real.
frontmatter_quoted_keys() {
  awk -v end="$2" '
    NR > 1 && NR < end {
      line = $0
      sub(/^[ \t]+/, "", line)
      # Position 1: start of the line — an ordinary block-mapping key.
      if (line ~ /^["'\''"]/) { print $0; next }
      # Position 2: after the explicit-key indicator, `? "key"` on its own line.
      if (line ~ /^[?]([ \t]|$)/) { print $0; next }
      # Position 3: inside a flow mapping, after `{` or after a `,` within it.
      if (line ~ /[{]/ && line ~ /["'\''"]/) { print $0; next }
      # And an escape sequence anywhere, quoted or not: it can only be a form
      # this script will not decode, and decoding one wrongly is what rounds
      # one through three of this file each did.
      if (line ~ /\\[uUx]/) { print $0; next }
    }' "$1"
}

# Every frontmatter line that mentions the key in any form — rule B's input.
#
# Matched on a NORMALISED copy of the line: lowercased, with everything that is
# not a letter or digit removed. So `disable_model_invocation`,
# `Disable-Model-Invocation`, and `disable model invocation` all reach rule B and
# are refused, rather than reading as an absent key.
#
# That last part is the point. Claude Code reads the hyphenated key and nothing
# else, so an underscored one is inert — a skill whose author wrote
# `disable_model_invocation: true` is model-invocable, believes it is not, and got
# no warning from this script because the matcher saw no key at all. The failure
# is the same silent skip as the escape forms, arrived at by typo instead of by
# encoding, and it is why this normalises rather than adding underscores to a
# pattern: the next near-spelling should be caught by the rule, not by a fifth
# review round. CodeRabbit caught it.
#
# Widening what gets REFUSED cannot widen what gets accepted — rule C still
# compares against two literals. Verified across every SKILL.md in the fleet:
# the normalised match finds only lines that are already canonical, so no
# legitimate frontmatter is caught by it.
frontmatter_key_mentions() {
  awk -v end="$2" '
    NR > 1 && NR < end {
      norm = tolower($0)
      gsub(/[^a-z0-9]/, "", norm)
      if (norm ~ /disablemodelinvocation/) print $0
    }' "$1"
}

# The accepted forms, exactly — rule C. String equality against a literal.
frontmatter_canonical_lines() {
  awk -v end="$2" '
    NR > 1 && NR < end &&
    ($0 == "disable-model-invocation: true" || $0 == "disable-model-invocation: false") \
      { print $0 }' "$1"
}

# The value of the single canonical line: `true` or `false`, nothing else can
# reach here.
frontmatter_key_value() {
  frontmatter_canonical_lines "$1" "$2" | awk 'NR == 1 { print $2 }'
}

changed=0
discovered=0
explicit=0
exempted=0
failed=0

for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  skill="$(basename "$(dirname "$f")")"
  discovered=$((discovered + 1))

  exempt=0
  for keep in ${KEEP_DISABLED+"${KEEP_DISABLED[@]}"}; do
    [ "$skill" = "$keep" ] && exempt=1
  done

  end="$(frontmatter_end "$f")"
  if [ -z "$end" ]; then
    echo "ERROR: $f has no YAML frontmatter block starting on line 1." >&2
    echo "       Refusing to guess: without frontmatter there is no setting to assert," >&2
    echo "       and a body-only match would be prose, not configuration." >&2
    failed=1
    continue
  fi

  # Rule A. A quoted key is refused before anything tries to read what it
  # spells, which is what makes this script immune to YAML escape forms rather
  # than merely current with the ones found so far.
  quoted="$(frontmatter_quoted_keys "$f" "$end")"
  if [ -n "$quoted" ]; then
    echo "ERROR: $f quotes a key in its frontmatter, or writes one somewhere this" >&2
    echo "       script refuses to read:" >&2
    printf '%s\n' "$quoted" | awk '{ print "         " $0 }' >&2
    echo "       Refused without interpreting it. A double-quoted YAML key may contain" >&2
    echo "       \\uXXXX, \\UXXXXXXXX or \\xXX escapes, so a quoted key can spell" >&2
    echo "       disable-model-invocation without looking like it — three review rounds" >&2
    echo "       found three escape forms this script decoded wrongly, each one a silent" >&2
    echo "       skip. It no longer decodes any. Write frontmatter keys bare." >&2
    echo "       The same goes for a key in a flow mapping ({\"key\": true}) or after an" >&2
    echo "       explicit-key indicator (? \"key\"): those are key positions that are not" >&2
    echo "       the start of a line, and an escaped key sitting in one passed this whole" >&2
    echo "       script until 2026-08-29. Write frontmatter as plain block mappings." >&2
    failed=1
    continue
  fi

  # Rule B. Every mention that is not one of the two accepted byte sequences is
  # refused. Catches indentation (a key nested under `metadata:` is a DIFFERENT
  # key, and one such line previously satisfied the /ship exemption while the
  # root key was absent), trailing comments, `false#text` — which is the string
  # "false#text" in YAML, since `#` only opens a comment after whitespace — and
  # quoted or mismatched-quote values like "true'.
  mentions="$(frontmatter_key_mentions "$f" "$end")"
  canonical="$(frontmatter_canonical_lines "$f" "$end")"
  mention_count=0; canonical_count=0
  [ -n "$mentions" ] && mention_count="$(printf '%s\n' "$mentions" | wc -l | tr -d ' ')"
  [ -n "$canonical" ] && canonical_count="$(printf '%s\n' "$canonical" | wc -l | tr -d ' ')"

  if [ "$mention_count" -ne "$canonical_count" ]; then
    echo "ERROR: $f frontmatter mentions disable-model-invocation in a form this" >&2
    echo "       script will not interpret:" >&2
    printf '%s\n' "$mentions" | awk '{ print "         " $0 }' >&2
    echo "       Accepted, exactly and at column zero, with no trailing text:" >&2
    echo "         disable-model-invocation: true" >&2
    echo "         disable-model-invocation: false" >&2
    echo "       Indentation is not cosmetic here: a key nested under another mapping" >&2
    echo "       is a different key, and Claude Code reads the ROOT one. Nor is the" >&2
    echo "       spelling: Claude Code reads the hyphenated key only, so an underscored" >&2
    echo "       or differently-cased one is inert and does nothing at all." >&2
    echo "       Normalise the line by hand." >&2
    failed=1
    continue
  fi

  key_lines="$canonical"
  key_count="$canonical_count"

  if [ "$key_count" -gt 1 ]; then
    echo "ERROR: $f declares disable-model-invocation $key_count times in frontmatter:" >&2
    printf '%s\n' "$key_lines" | awk '{ print "         " $0 }' >&2
    echo "       YAML takes the LAST one, so a leading value here lies to anything that" >&2
    echo "       reads the file line-first — including this script. Keep exactly one." >&2
    failed=1
    continue
  fi

  if [ "$exempt" -eq 1 ]; then
    # An exemption is a CLAIM about the file, so verify it rather than trusting
    # the name. This branch used to `continue` immediately, which meant the one
    # skill the exemption exists to protect was the only skill nothing checked:
    # if ship's flag drifted to `false`, or the key were dropped, the script
    # printed "exempt" and exited 0 while merge, push, and deploy became
    # model-invocable. CodeRabbit caught it on the first run of this script.
    if [ "$(frontmatter_key_value "$f" "$end")" != "true" ]; then
      echo "ERROR: $skill is listed in KEEP_DISABLED but its frontmatter does not set" >&2
      echo "       'disable-model-invocation: true'. Line reads: ${key_lines:-<key absent from frontmatter>}" >&2
      echo "       An exempt skill takes externally visible, hard-to-reverse actions." >&2
      echo "       Either restore the flag, or remove $skill from KEEP_DISABLED and" >&2
      echo "       delete the reason recorded there." >&2
      failed=1
      continue
    fi
    echo "  exempt: $skill (declared slash-command-only, flag verified in frontmatter)"
    explicit=$((explicit + 1))
    exempted=$((exempted + 1))
    continue
  fi

  # A skill with no such key is already model-invocable — that is the default.
  # Leave it alone rather than adding a key that says the default out loud. It
  # still counted toward `discovered`, which is what the examined-nothing guard
  # below reads: the earlier version counted only files carrying the key, so a
  # fleet where every skill correctly omits it — the end state this script is
  # driving toward — failed as though nothing had been looked at.
  [ "$key_count" -eq 1 ] || continue

  explicit=$((explicit + 1))
  value="$(frontmatter_key_value "$f" "$end")"

  # Already correct. Nothing to do, and nothing to say.
  [ "$value" = "false" ] && continue

  # `value` can only be `true` here: rule C accepted the line by equality
  # against two literals and rule B refused everything else, so there is no
  # third value and no exotic spelling left to guard against. That is the point
  # of the whitelist — the previous version needed two extra branches here (a
  # not-true-not-false check and a non-canonical-form check) precisely because
  # its matcher accepted forms it was unwilling to rewrite.

  # Bounded to the frontmatter line range. Unbounded, this rewrote any code
  # block or prose line in the body that happened to match.
  perl -pi -e "s/^disable-model-invocation: true\$/disable-model-invocation: false/ if \$. > 1 && \$. < $end" "$f"

  if [ "$(frontmatter_key_value "$f" "$end")" != "false" ]; then
    echo "ERROR: $f frontmatter still does not read 'disable-model-invocation: false'" >&2
    echo "       after the rewrite. Frontmatter now reads:" >&2
    frontmatter_key_mentions "$f" "$end" | awk '{ print "         " $0 }' >&2
    failed=1
    continue
  fi

  echo "  flipped: $skill"
  changed=$((changed + 1))
done

if [ "$discovered" -eq 0 ]; then
  echo "ERROR: found no SKILL.md under $SKILLS_DIR." >&2
  echo "       Reporting this rather than exiting 0: a run that examined nothing must" >&2
  echo "       not read the same as a run that asserted the whole fleet." >&2
  exit 1
fi

[ "$failed" -eq 0 ] || exit 1
# Report the exempt count separately. Folding it into the total would say all N
# skills assert `false` when one of them asserts the opposite, which is the same
# "clean verdict covering something it did not cover" the rest of this fleet's
# tooling exists to avoid. Skills with no key at all are reported separately
# again, because "asserts false" and "relies on the default being false" are
# different claims and only the first is something this script verified.
echo "OK: $((explicit - exempted)) skill(s) assert disable-model-invocation: false ($changed changed), $exempted exempt and verified true, $((discovered - explicit)) rely on the default, of $discovered skill(s) in $REPO_ROOT"
