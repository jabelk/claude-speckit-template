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
# Usage:  scripts/assert-skill-invocation.sh [REPO_ROOT]
# Exit:   0 every skill asserted false (or intentionally exempt)
#         1 a file lacks the key after the rewrite, or no skills were found
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

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: no $SKILLS_DIR — nothing to assert. Wrong repo root?" >&2
  exit 1
fi

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
  if [ "$exempt" -eq 1 ]; then
    # An exemption is a CLAIM about the file, so verify it rather than trusting
    # the name. This branch used to `continue` immediately, which meant the one
    # skill the exemption exists to protect was the only skill nothing checked:
    # if ship's flag drifted to `false`, or the key were dropped, the script
    # printed "exempt" and exited 0 while merge, push, and deploy became
    # model-invocable. CodeRabbit caught it on the first run of this script.
    if ! grep -q '^disable-model-invocation: true$' "$f"; then
      echo "ERROR: $skill is listed in KEEP_DISABLED but does not set" >&2
      echo "       'disable-model-invocation: true'. Line reads: $(grep '^disable-model-invocation:' "$f" || echo '<key absent>')" >&2
      echo "       An exempt skill takes externally visible, hard-to-reverse actions." >&2
      echo "       Either restore the flag, or remove $skill from KEEP_DISABLED and" >&2
      echo "       delete the reason recorded there." >&2
      failed=1
      continue
    fi
    echo "  exempt: $skill (declared slash-command-only, flag verified)"
    checked=$((checked + 1))
    exempted=$((exempted + 1))
    continue
  fi

  # A skill with no such key is already model-invocable — that is the default.
  # Leave it alone rather than adding a key that says the default out loud.
  grep -q '^disable-model-invocation:' "$f" || continue

  checked=$((checked + 1))
  before="$(grep '^disable-model-invocation:' "$f")"
  perl -pi -e 's/^disable-model-invocation: true$/disable-model-invocation: false/' "$f"

  if ! grep -q '^disable-model-invocation: false$' "$f"; then
    echo "ERROR: $f still lacks 'disable-model-invocation: false' after rewrite." >&2
    echo "       Line reads: $(grep '^disable-model-invocation:' "$f")" >&2
    echo "       Upstream format changed, or the value is something other than true/false." >&2
    failed=1
    continue
  fi

  if [ "$before" != "disable-model-invocation: false" ]; then
    echo "  flipped: $skill"
    changed=$((changed + 1))
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "ERROR: found no SKILL.md carrying a disable-model-invocation key under $SKILLS_DIR." >&2
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
