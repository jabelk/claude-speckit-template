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
# it cannot repair: a value that is neither `true` nor `false`, a duplicate key,
# absent frontmatter, or a rewrite that did not take. What it repairs it names, one
# `flipped:` line per file, so a run is never silent about having changed the tree.
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

# Every `disable-model-invocation:` line strictly inside the frontmatter block,
# and (second function) that key's value.
#
# Both go through one perl matcher, because deciding whether a line declares
# this key is a decoding problem rather than a pattern-matching one, and it has
# already been got wrong twice in the same direction:
#
#   1. Matching only the bare `disable-model-invocation:` read
#      `"disable-model-invocation": true` as "key absent" and skipped the file —
#      leaving a skill model-disabled while the script exited 0, because a
#      verified `ship` exemption is enough to keep the examined-nothing guard
#      quiet. A guard defeated by a pair of quotes is not a guard.
#   2. Adding optional quotes still missed
#      `"disable-model-invocation": true`, which is valid YAML for the same
#      key: a double-quoted scalar decodes \uXXXX and \xXX escapes. Same silent
#      skip, same exit 0. CodeRabbit caught this one.
#
# So the key is decoded before it is compared: quotes stripped, and inside
# double quotes the escapes YAML actually defines are resolved. A line whose
# decoded key matches is REPORTED, not accepted — an exotic spelling then hits
# the non-canonical-form guard further down and fails loudly, because being
# willing to recognise a form is not the same as being willing to rewrite it.
# That keeps this function's job "see everything" and leaves "edit only what is
# unambiguous" where it belongs.
_frontmatter_match() {
  # $1 file, $2 frontmatter end line, $3 mode: "lines" | "value"
  perl -e '
    my ($file, $end, $mode) = @ARGV;
    open my $fh, "<", $file or exit 0;
    my $target = "disable-model-invocation";
    while (my $raw = <$fh>) {
      last if $. >= $end;
      next if $. <= 1;
      chomp(my $line = $raw);
      my $rest = $line;
      $rest =~ s/^[ \t]+//;

      my ($key, $val);
      if ($rest =~ /^"((?:[^"\\]|\\.)*)"[ \t]*:[ \t]*(.*)$/) {
        ($key, $val) = ($1, $2);
        # YAML double-quoted scalars decode these; anything else stays literal.
        $key =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
        $key =~ s/\\x([0-9a-fA-F]{2})/chr(hex($1))/ge;
        $key =~ s/\\(.)/$1/g;
      } elsif ($rest =~ /^'"'"'([^'"'"']*)'"'"'[ \t]*:[ \t]*(.*)$/) {
        ($key, $val) = ($1, $2);   # single quotes: no escape processing in YAML
      } elsif ($rest =~ /^([^:\s]+)[ \t]*:[ \t]*(.*)$/) {
        ($key, $val) = ($1, $2);
      } else {
        next;
      }
      next unless $key eq $target;

      if ($mode eq "lines") { print "$line\n"; next; }

      $val =~ s/[ \t]*#.*$//;
      $val =~ s/[ \t]+$//;
      $val =~ s/^"(.*)"$/$1/ or $val =~ s/^'"'"'(.*)'"'"'$/$1/;
      print "$val\n";
      exit 0;
    }
  ' "$1" "$2" "$3"
}

frontmatter_key_lines() { _frontmatter_match "$1" "$2" lines; }

# The key's value, normalised: indentation, quotes around the key, quotes around
# the value, trailing whitespace and a trailing `# comment` all removed. Compare
# against this rather than against the whole raw line, so the several spellings
# of the same setting are treated as the same setting.
frontmatter_key_value() { _frontmatter_match "$1" "$2" value; }

changed=0
checked=0
exempted=0
failed=0

for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  skill="$(basename "$(dirname "$f")")"

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

  key_lines="$(frontmatter_key_lines "$f" "$end")"
  key_count=0
  [ -n "$key_lines" ] && key_count="$(printf '%s\n' "$key_lines" | wc -l | tr -d ' ')"

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
    checked=$((checked + 1))
    exempted=$((exempted + 1))
    continue
  fi

  # A skill with no such key is already model-invocable — that is the default.
  # Leave it alone rather than adding a key that says the default out loud.
  [ "$key_count" -eq 1 ] || continue

  checked=$((checked + 1))
  value="$(frontmatter_key_value "$f" "$end")"

  # Already correct in any accepted spelling. Nothing to do, and nothing to say.
  [ "$value" = "false" ] && continue

  if [ "$value" != "true" ]; then
    echo "ERROR: $f frontmatter sets disable-model-invocation to a value that is" >&2
    echo "       neither true nor false. Line reads: $key_lines" >&2
    echo "       Refusing to guess what was meant." >&2
    failed=1
    continue
  fi

  # The rewrite handles the ONE canonical spelling and refuses the rest. The
  # matcher above deliberately accepts quoted keys and values so that no file is
  # silently skipped, but accepting a spelling for reading is not the same as
  # being willing to rewrite it blind — a regex broad enough to edit every
  # variant is a regex broad enough to mangle one. So an exotic form is reported
  # for a human to normalise, which fails loudly instead of quietly.
  if [ "$key_lines" != "disable-model-invocation: true" ]; then
    echo "ERROR: $f sets disable-model-invocation: true in a non-canonical form:" >&2
    echo "         $key_lines" >&2
    echo "       This script only rewrites the exact form 'disable-model-invocation: true'" >&2
    echo "       (no indentation, no quotes, no trailing comment). Normalise the line to" >&2
    echo "       'disable-model-invocation: false' by hand." >&2
    failed=1
    continue
  fi

  # Bounded to the frontmatter line range. Unbounded, this rewrote any code
  # block or prose line in the body that happened to match.
  perl -pi -e "s/^disable-model-invocation: true\$/disable-model-invocation: false/ if \$. > 1 && \$. < $end" "$f"

  if [ "$(frontmatter_key_value "$f" "$end")" != "false" ]; then
    echo "ERROR: $f frontmatter still does not read 'disable-model-invocation: false'" >&2
    echo "       after the rewrite. Line reads: $(frontmatter_key_lines "$f" "$end")" >&2
    failed=1
    continue
  fi

  echo "  flipped: $skill"
  changed=$((changed + 1))
done

if [ "$checked" -eq 0 ] && [ "$failed" -eq 0 ]; then
  echo "ERROR: found no SKILL.md carrying a disable-model-invocation key in frontmatter" >&2
  echo "       under $SKILLS_DIR." >&2
  echo "       Reporting this rather than exiting 0: a run that examined nothing must" >&2
  echo "       not read the same as a run that asserted the whole fleet." >&2
  exit 1
fi

[ "$failed" -eq 0 ] || exit 1
# Report the exempt count separately. Folding it into the total would say all N
# skills assert `false` when one of them asserts the opposite, which is the same
# "clean verdict covering something it did not cover" the rest of this fleet's
# tooling exists to avoid.
echo "OK: $((checked - exempted)) skill(s) assert disable-model-invocation: false ($changed changed), $exempted exempt and verified true, in $REPO_ROOT"
