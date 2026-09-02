#!/usr/bin/env bash
# bounded-vendor-review.sh — run the CodeRabbit CLI with a bound on how long it
# may sit doing nothing, so a hung vendor leg is a loud refusal rather than a
# silent wait.
#
# Usage:  bounded-vendor-review [ARGS...]        # ARGS go to `coderabbit review`
#         bounded-vendor-review --base "$BASE" --include-untracked
# Exit:   0 the reviewer CONNECTED and produced a verdict — read the output for
#           what it found; this script does not judge findings
#         2 this script could not do its job (no CLI on PATH, cannot write a
#           temp file, a required variable is unset)
#         3 NO REVIEW HAPPENED — the branch has had no vendor review. Three ways
#           to get here: the reviewer was killed at one of the two caps below; it
#           was killed by a signal from outside this script (status 128+); or it
#           returned non-zero without ever reaching a review phase, i.e. it failed
#           before reviewing rather than reviewing and finding something
#         4 REFUSED BEFORE REVIEWING, because this branch has already had
#           ROUND_CAP reviews. Also no review, and deliberately not 3: 3 is a
#           vendor or session problem you can retry, 4 is a decision that another
#           round is the wrong move and a human should look
#
# There is no exit 1, deliberately. `coderabbit` uses 1 for every outcome it has
# — unknown flag, not-a-repository, and "found actionable issues" all exit 1
# (verified on 0.7.5, 2026-08-29) — so a caller gating on 1 cannot tell a review
# that flagged something from a reviewer that never ran. This script refuses to
# add a fourth meaning to that number. Its own failures get codes the CLI does
# not use, and the CLI's own status is reported separately in the summary line.
#
# WHY THIS EXISTS. On 2026-08-31 the CLI stopped connecting, mid-session, with no
# change on this machine. `~/.coderabbit/stats.json` recorded 17 successful
# reviews that day, the last at 12:47:13 PDT. Every run from 15:41:43 PDT onward
# died at the same point, and here is the entire log of one of them:
#
#   22:42:19.171  review.trpc  Establishing WebSocket connection to URL
#                              wss://ide.coderabbit.ai/ws
#   22:42:19.209  update       skipping auto update. cli is managed by homebrew
#   23:02:17.339  init         initiating graceful exit   signal: SIGTERM
#
# Twenty minutes of total silence, then an external kill. The CLI has no connect
# timeout of its own: it does not retry, does not warn, and does not give up. Ten
# runs behaved identically. What was ruled out, each by measurement rather than
# reasoning:
#
#   - Concurrency. Every competing process killed, one run alone in an empty
#     repo: same hang, same line.
#   - Version drift. 0.7.5 was current; `brew outdated --cask` listed nothing.
#   - Auth. `coderabbit auth status` reported the account throughout.
#   - The network path to that host. DNS resolved, TCP connected in 135ms, TLS
#     handshook in 431ms, and an HTTPS request returned a normal 403. No proxy
#     variables were set.
#   - A corporate VPN, which was the leading hypothesis and was wrong. With the
#     tunnel down and the route to that host going straight out the physical
#     interface, the hang was identical. Worth recording because the obvious
#     suspect cost a real detour, and because "drop the VPN" is advice that
#     costs a working day on other tasks.
#
# So the cause was outside this machine, and the point of this script is that
# THAT IS THE NORMAL CASE for a vendor leg. A hosted reviewer will be down, or
# slow, or throttling, on some day you did not choose. The defect worth fixing is
# not the outage; it is that an unbounded wait turns someone else's outage into a
# gate that neither passes nor fails, and the operator finds out only by noticing
# that nothing has happened for twenty minutes.
#
# The gate's OTHER guard, preflight-vendor-review, took twelve review rounds on
# one lesson: a check whose failure is indistinguishable from its success is not
# a check. This is the adjacent failure — a check that never returns a verdict at
# all — and it is worse in one specific way. A fail-open guard at least leaves an
# operator with a wrong answer they might question. An unbounded hang leaves them
# with no answer, and "still running" is indistinguishable from "working".
#
# WHY A HAND-ROLLED WATCHDOG. `timeout(1)` is GNU coreutils and is NOT present on
# a stock macOS — `timeout 180 coderabbit review ...` fails with
# `command not found: timeout` (measured 2026-08-31). This said the review is then
# "silently skipped while the chain carries on", which is FALSE inside an `&&`
# chain and was corrected on 2026-09-01: `command not found` is 127, so the chain
# stops there and the skip is loud. The real hazard is the *unchained* form — the
# two-line habit this file's own docs warn about elsewhere — where the failed
# `timeout` line is followed by everything after it regardless. Depending on
# `brew install coreutils` for a safety guard puts the guard behind an optional
# dependency, so the wait loop below is written in POSIX shell and Bash builtins.
#
# TWO BOUNDS, AND WHICH ONE IS THE DECISION. The design constraint is that a
# broken bound must be able to stop the gate late, never let it through.
#
#   TOTAL_CAP (default 900s) is the DECISION. It is arithmetic on the wall clock
#   and calls no external command, for the same reason preflight-vendor-review's
#   decision is one `[ -n ]` over a variable already in hand: a test with no
#   command in it cannot have a helper whose operational error reads as "found
#   nothing". If everything else in this file breaks, this still fires.
#
#   CONNECT_CAP (default 120s) is an EARLY kill, and it reads THE REVIEWER'S OWN
#   OUTPUT to decide — see `connect_verdict`. It asks whether the last progress
#   line still names the connect phase or a later one, in either of the two shapes
#   the CLI emits (prose `elapsed` lines, or `"phase":"..."` NDJSON under
#   `--agent`). That read can fail in every way a parse can — no progress line
#   yet, an unreadable capture, a renamed phase — and every one of those failures
#   makes it decline to kill early, which defers to TOTAL_CAP. So the worst a
#   broken CONNECT_CAP can do is make the refusal arrive 900s late instead of
#   120s. It cannot manufacture a pass. That asymmetry is the only reason a parse
#   is allowed in this file at all.
#
#   It reads `$out` first and falls back to `$err` only when `$out` carries no
#   progress line at all, because `cat` of both orders by FILE rather than by
#   time, and one stale connect-phase line in stderr then outranks every later
#   line in stdout. Which stream carries the progress lines is now measured
#   rather than assumed — stdout, with stderr empty in agent mode — but the
#   ordered read is correct either way, which is the point: it needed no
#   measurement to be right. THIS PARAGRAPH SAID "reads the CLI's log" until
#   2026-09-01, and then "stdout", and then that the streams had only been
#   measured merged. All three were stale claims about the design left sitting in
#   the design comment; see defects 4, 10, 14 and 15 of the log for what each one
#   cost. A design comment that outlives the design it describes is how the next
#   reader reproduces the bug.
#
# A THIRD BOUND, AND IT BOUNDS THE LOOP RATHER THAN THE RUN. The two caps above
# bound one review. Nothing bounded how many reviews a branch gets, and on
# 2026-09-01 this file had taken TWENTY-PLUS rounds on one 229-line script, with a
# defect found in most of them and each found in the round that fixed its predecessor,
# a third of them changing no guard behaviour at all and several purely about
# prose. A floor rather than a figure, for the reason the next paragraph gives. The rule
# meant to stop that existed the whole time, as a sentence in CLAUDE.md saying
# that round 3+ means something is off and should be surfaced to the operator. It
# is a paragraph asking the agent to notice, and the agent did not notice, twenty-two
# times. A bound that depends on the bounded party spotting it is not a bound —
# which is this file's own oldest lesson pointed at the review process instead of
# at the script.
#
# So: ROUND_CAP (default 3) gives each repository directory and branch that many
# rounds and refuses the next with exit 4. Two properties make it safe to state in
# thirty lines rather than defending over sixteen rounds. It can only REFUSE — no
# failure of the round state can manufacture a pass, because the pass is decided
# 500 lines below by the reviewer's own verdict and the round state is never consulted
# there. And it spends a round only on a review that HAPPENED: exit 2, 3 and 4 keep
# nothing, so a vendor outage cannot exhaust the budget for a branch that has had no
# review. Raise it explicitly (`ROUND_CAP=6`) or reset the branch (`ROUND_RESET=1`);
# both are a deliberate number rather than an off switch, and `ROUND_CAP=0` is refused
# by the numeric validator like any other useless bound.
#
# THE FIRST VERSION OF IT WAS THIS FILE'S OWN SIGNATURE DEFECT, and the PR-side review
# caught it in the round that added it: it read a count, compared it, and wrote count+1
# when the review returned — three steps with a vendor review in the middle, so two
# wrappers on one branch both read 2, both passed, and both sent a diff. A cap of three
# admitted six. Admission is now an O_EXCL claim of a slot named 1..ROUND_CAP, which is
# why there is no count anywhere below. See defect 17 of the log for the alternative
# (a lock across the review) and why it was declined.
#
# THE DEFECTS FOUND BY USING IT are in `scripts/vendor-gate-defect-log.md`, which is
# the only copy — and the only place their COUNT is written, because every figure ever
# mirrored out of that list has gone stale, the last one on the day the mirrors were
# collapsed to one. All fixed here; every one found by using this script or by a reviewer
# reading it, and none by the author reasoning about it. Read that log before changing
# anything below: most of the list is one defect — an advertised bound, or an advertised
# verdict, that was not the one advertised — and nearly all of them had a test that should
# have caught them and could not, in every case because the vacuity was in the fixture,
# the harness, the inherited environment, the unrun mode, the unmodelled reader, or the
# assertion's anchor rather than in the assertion's logic.
#
# Most of this header used to be that log. On 2026-08-31 the header alone was 588 comment
# lines and the whole file 951, against 229 executable ones — measured, not estimated: run
# `git show <the commit before the log moved>:scripts/bounded-vendor-review.sh` and count
# lines whose first non-space character is `#`, minus the shebang. And it was mirrored, in
# prose and never verbatim, into four other
# documents, which is a second staleness surface on top of the first. Its summary
# arithmetic went stale in three places at once, twice; two review rounds went on nothing
# but those numbers, and two more on the check written to catch them and on that check's
# own defects — four whole rounds spent inside a loop about the commentary. So
# BOTH header self-checks are gone with the enumeration they read: the one that parsed
# these ordinals, and the one that banned absolute suite totals. Nothing now fails when a
# count in a comment goes stale. One copy cannot disagree with itself — a structural
# guarantee where those were mechanical ones, and weaker on purpose.
#
# 120s for the connect is not a guess about how long connecting should take —
# it is a claim that connecting does not take two minutes. NOT VERIFIED as a
# normal duration, and stated as a limit rather than glossed: the logs of the 17
# successful runs had been pruned before this was written. What IS now verified is
# the failure mode of getting it wrong. Before defect 4 was fixed the cap fired
# against healthy reviews, so "spurious exit 3" was not hypothetical — it was
# every run. With the detector reading the phase name, a legitimately slow
# connect is the only remaining way to trip it spuriously, and the fix for that
# is still to raise the cap, which is the safe direction to be wrong in.
#
# WHAT THIS DOES NOT DO. It does not judge findings, retry, or fall back to
# another reviewer. Exit 0 means a verdict exists, not that it was clean — the
# CLI's own exit status and the head of its output are printed for the caller to
# read, because that leg has always had to be read rather than gated on.
set -uo pipefail

# Round 10 of the sibling guard, and it applies here for the same reason: git's
# location variables outrank any `cd`, so a review can enumerate a repository the
# preceding check never inspected. This script does not run `git`, but it launches
# something that does, and a child inherits them. Refusing keeps the whole chain
# honest instead of only this process.
# `${!v+x}` asks whether the variable is SET, not whether it has content. This was
# `[ -n "${!v:-}" ]` until 2026-09-01 — defect 6 of the log — and an explicitly
# empty value walked straight through it. Empty is not harmless: `GIT_DIR=''` makes
# git fail with `fatal: not a git repository: ''` rather than reading elsewhere, and
# `GIT_INDEX_FILE=''` makes git report every tracked file as deleted. Same family as
# defect 3's `${VAR:-default}`: an empty value is a value someone set on purpose.
poisoned=""
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; do
  [ -n "${!v+x}" ] && poisoned="${poisoned:+$poisoned }$v"
done
if [ -n "$poisoned" ]; then
  echo "STOP: git location variable(s) set in the environment: $poisoned" >&2
  echo "      They redirect what the reviewer reads, so it can enumerate a" >&2
  echo "      different repository than the preflight check inspected. Unset" >&2
  echo "      them in YOUR shell, not just here:" >&2
  echo "        unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR" >&2
  echo "      If you need them for other work, wrap the WHOLE gate:" >&2
  echo "        env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \\" >&2
  echo "          -u GIT_COMMON_DIR bash -c '<the entire gate>'" >&2
  exit 2
fi

# `${VAR-default}`, NOT `${VAR:-default}`, and the colon is the whole point.
# With the colon, an EXPLICITLY EMPTY value gets the default too, so `POLL=`
# silently became 5 and the `''` branch of the validator below was unreachable
# dead code — a bound the operator tried to set and did not, reading as a bound
# that was set. Caught by CI on 2026-09-01, on the one variable the suite
# probed; the other four had the same hole and no case at all. Empty now reaches
# the validator, which refuses it. Unset still defaults, which is the whole
# point of having defaults.
CR_BIN="${CR_BIN-coderabbit}"
TOTAL_CAP="${TOTAL_CAP-900}"
CONNECT_CAP="${CONNECT_CAP-120}"
POLL="${POLL-5}"
ROUND_CAP="${ROUND_CAP-3}"
# `${HOME:+...}` rather than a bare `$HOME`, and this one is defect 12 — the one
# status this file promises never to use, produced by the line that builds a
# default. Under `set -u` an UNSET HOME aborts the script here with
# `HOME: unbound variable` and exit 1, and 1 is the CLI's own status for FINDINGS
# as well as for an unknown flag and for "not a git repository", which is exactly
# why exit 3 exists. A caller reading 1 as "reviewed and flagged something" would
# be reading a script that never reached the reviewer. Measured 2026-09-01:
# `env -u HOME` against the old form gives `HOME: unbound variable`, exit 1.
# Not exotic — HOME is absent from cron, from systemd units, and from git hooks
# run by some daemons, and the gate docs suggest wiring this into a pre-push hook.
# `${HOME:+...}` yields empty for both unset and empty HOME, which reaches the
# validator immediately below and is refused with exit 2. Empty is the right
# answer for both: a log root of `/` degrades connect_verdict() to `unknown`
# forever, which is the early kill switched off again (defect 3's shape).
LOG_DIR="${CR_LOG_DIR-${HOME:+$HOME/.coderabbit/logs}}"
# Same `${HOME:+...}` form and the same reason, one variable later.
ROUND_DIR="${VENDOR_ROUND_DIR-${HOME:+$HOME/.claude/vendor-review-rounds}}"

# THE REFUSAL BELOW CANNOT SPEAK FOR THIS CASE, and letting it try was a defect of
# its own — raised by the PR-side review on 2026-09-01, one round after the HOME
# hole above was fixed. With CR_LOG_DIR unset and HOME unset or empty, the
# expansion yields empty and the generic branch prints "CR_LOG_DIR is set but
# empty. Unset it to take the default" — and BOTH sentences are false: CR_LOG_DIR
# is not set, and unsetting it changes nothing. The operator who lands here is in
# cron, a systemd unit, or a git hook, which is precisely where HOME is absent and
# where there is nobody to guess; they would be handed an instruction that cannot
# resolve the refusal, with the actual cause unnamed.
#
# Advice that cannot resolve its own refusal is part of the defect, not cosmetics
# on top of one. That is the sibling guard's eleventh round exactly: it told the
# caller to use `env -u`, which covers one leg of an && chain, so following the
# guard's advice defeated the guard. Same lesson, this file's turn.
#
# `${CR_LOG_DIR+x}` asks whether it is SET, not whether it has content — the same
# distinction that made defect 12 and the sibling's twelfth round, and the reason
# `CR_LOG_DIR=` still reaches the generic branch below, where the message is true.
#
# A LOOP OVER BOTH HOME-DERIVED DEFAULTS rather than one branch about CR_LOG_DIR,
# since ROUND_DIR was added on the same expansion. Naming the variable that is
# actually missing is the entire content of this refusal, so a second default
# quietly answered for by the first one's message would be defect 13 again.
if [ -z "${HOME:-}" ]; then
  for v in CR_LOG_DIR VENDOR_ROUND_DIR; do
    [ -n "${!v+x}" ] && continue
    echo "STOP: cannot build a default $v, because HOME is unset or empty" >&2
    echo "      and $v was not set either. Set $v explicitly, or" >&2
    echo "      set HOME. This is exit 2 and never exit 1: the CLI spends 1 on real" >&2
    echo "      findings, so a 1 from here would read as a review that happened." >&2
    exit 2
  done
fi

# CR_BIN and LOG_DIR are not numbers, so the numeric loop below cannot speak for
# them. An empty CR_BIN would reach `command -v ""` and refuse by luck rather
# than by decision; an empty LOG_DIR would silently root every log path at `/`,
# where nothing matches and the connect verdict degrades to "unknown" forever —
# i.e. the early kill switched off again, which is the defect this script was
# just fixed for.
for pair in "CR_BIN:$CR_BIN" "CR_LOG_DIR:$LOG_DIR" "VENDOR_ROUND_DIR:$ROUND_DIR"; do
  case "${pair#*:}" in
    '')
      echo "STOP: ${pair%%:*} is set but empty. Unset it to take the default," >&2
      echo "      or give it a value; an empty value is not a default." >&2
      exit 2
      ;;
  esac
done

# The phase the hang sits in, as the CLI names it on its own stdout progress
# lines. Being in ANY other phase is what "connected" means here. This replaced a
# log-file marker on 2026-09-01, because the log is silent during a healthy review
# and therefore could not distinguish one from a hang — see connect_verdict().
CONNECT_PHASE='Connecting to CodeRabbit'
# The same phase in the OTHER output shape. `--agent` replaces the whole prose
# progress stream with NDJSON and emits NO `elapsed` line at all, which was defect
# 15 — see the header. Measured 2026-09-01 on 0.7.5: agent-mode stdout carries
# `{"type":"status","phase":"connecting","status":"connecting_to_review_service"}`
# and then `"phase":"setup"` / `"phase":"analyzing"`, and stderr is EMPTY. So the
# CLI still names its own phase in that mode, more explicitly than in prose; the
# detector reads both shapes and needs no flag-sniffing to tell which one it is in.
CONNECT_PHASE_AGENT='"phase":"connecting"'

# ROUND_CAP is a COUNT and not a duration, so it is refused here rather than by the
# loop below: that loop's message says "a whole number of seconds", which would be
# false about this variable, and a refusal that misdescribes what it wants is the
# shape of defect 13 — right status, wrong diagnosis, operator sent the wrong way.
case "$ROUND_CAP" in
  '' | *[!0-9]*)
    echo "STOP: ROUND_CAP must be a whole number of reviews, got '$ROUND_CAP'." >&2
    exit 2
    ;;
esac
[ "$ROUND_CAP" -gt 0 ] || {
  echo "STOP: ROUND_CAP must be greater than 0, got '$ROUND_CAP'. There is no" >&2
  echo "      value that means 'do not count' — that is what an off switch would" >&2
  echo "      be, and a bound with an off switch is the paragraph this replaced." >&2
  exit 2
}

for pair in "TOTAL_CAP:$TOTAL_CAP" "CONNECT_CAP:$CONNECT_CAP" "POLL:$POLL"; do
  name="${pair%%:*}" val="${pair#*:}"
  case "$val" in
    '' | *[!0-9]*)
      echo "STOP: $name must be a whole number of seconds, got '$val'." >&2
      exit 2
      ;;
  esac
  [ "$val" -gt 0 ] || { echo "STOP: $name must be greater than 0, got '$val'." >&2; exit 2; }
done
if [ "$CONNECT_CAP" -gt "$TOTAL_CAP" ]; then
  # Not fatal and not silent. A CONNECT_CAP above TOTAL_CAP can never fire, so
  # the early kill is simply absent — which is a supported configuration (it is
  # what CONNECT_CAP=999999 means) but must not be mistaken for having one.
  echo "note: CONNECT_CAP ${CONNECT_CAP}s exceeds TOTAL_CAP ${TOTAL_CAP}s, so the" >&2
  echo "      early connect kill can never fire. TOTAL_CAP is the only bound." >&2
fi

command -v "$CR_BIN" >/dev/null 2>&1 || {
  echo "STOP: '$CR_BIN' is not on PATH, so no review ran." >&2
  echo "      brew install --cask coderabbit && coderabbit auth login --agent" >&2
  exit 2
}

# --- THE ROUND CAP ------------------------------------------------------------
#
# Keyed on the physical working directory and the branch. `pwd -P` is a builtin and
# cannot fail into a shared bucket; `git rev-parse` CAN fail, and when it does the
# key falls back to the literal `no-branch`, which merges every branch in that
# directory into one counter. That is over-refusal, i.e. the safe direction, and it
# is stated rather than left for someone to discover: a broken git makes the cap
# stricter, never absent.
#
# The state lives under a `cksum` of the key so a deep path cannot overflow a
# filename, and EVERY key that lands on that hash is appended to a `key` file in the
# directory so a collision is READABLE instead of merely suspected. A collision shares
# a budget, which is again over-refusal. Appended, and never overwritten: the write was
# a `>` for one round, which made a collision read exactly like its absence — see the
# comment on the write itself.
#
# `cksum` IS AN EXTERNAL COMMAND, AND THE PARAGRAPH ABOVE ENUMERATED TWO FAILURE
# PATHS WHILE THE LINE BELOW HAD THREE. An unreachable `cksum` — a restricted PATH
# is the realistic trigger, and `.github/workflows/guard-suites.yml` in the template
# repo builds one on purpose — leaves the substitution EMPTY, which is not a
# degraded key, it is ONE BUCKET FOR EVERY KEY: every directory and every branch
# then shares one budget, and a branch that has had no review at all refuses with
# exit 4. That is a wrong verdict rather than a late one, i.e. the same class as the
# write probe below and NOT the same class as the `no-branch` fallback, which is
# still over-refusal within one directory. So an empty hash refuses here.
#
# A ROUND IS A CLAIMED SLOT, NOT AN INCREMENTED COUNTER, and that is the whole
# design of this block. It WAS a counter until the PR-side review on 2026-09-01
# read the two lines apart: `round_count=$(head -n1 ...)`, the cap test, and then a
# write after the review are three separate steps with a vendor review sitting in
# the middle of them, so two wrappers could both read 2, both pass the test, both
# send a diff, and both write 3. A fourth review under a cap of three — this file's
# signature defect, an advertised bound that was not the one advertised, in the
# block written to stop that class of thing happening to the review process.
#
# And concurrency here is the ORDINARY case, not a tail risk: defect 1 was found
# because two gates running at once is how this machine is normally used, and it was
# measured, two new logs 79s apart. A TOCTOU whose window is the length of a vendor
# review is not narrow.
#
# So admission is one atomic act. Each round is a file named `1`..`ROUND_CAP`,
# created under `set -C` — an O_EXCL create, which exactly one process can win — and
# claiming the lowest free number IS being admitted. No count is parsed, so there is
# no corrupt count to guess about; the number of claimed slots is the count.
#
# The claim is RELEASED on every path that is not a verdict, from the EXIT trap, so
# a cap kill or a vendor failure still spends nothing. What a `kill -9` of the
# wrapper leaks is one held slot, i.e. a refusal arriving one round early — the
# direction this file always chooses, and the escape hatch for it is the same
# `ROUND_RESET=1` as everything else here.
round_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || round_branch=''
[ -n "$round_branch" ] || round_branch='no-branch'
round_key="$(pwd -P)|$round_branch"
round_key_hash="$(cksum <<<"$round_key" | tr -cd '0-9' | cut -c1-20)"
[ -n "$round_key_hash" ] || {
  echo "STOP: could not hash the round key, so the round cap would share one budget" >&2
  echo "      across every directory and branch and could refuse a branch that has" >&2
  echo "      had no review. Nothing ran. Is 'cksum' on PATH?" >&2
  exit 2
}
round_state="$ROUND_DIR/$round_key_hash.rounds"

mkdir -p "$round_state" 2>/dev/null || {
  echo "STOP: cannot create the round-count directory $round_state, so the round" >&2
  echo "      cap cannot be enforced and this refuses rather than proceed" >&2
  echo "      uncounted. Set VENDOR_ROUND_DIR somewhere writable." >&2
  exit 2
}
# WRITABILITY IS PROBED SEPARATELY, and not folded into the claim, because a failed
# `set -C` redirect cannot say WHY it failed: EEXIST (this slot is taken, try the
# next) and EACCES (nothing here can be written, the cap is unenforceable) arrive as
# the same non-zero status. Without this probe a read-only state directory would
# exhaust the loop and report exit 4 — "the branch is out of rounds" over a branch
# that has had none, which is a wrong verdict rather than a late one. The probe name
# carries `$$` so two concurrent wrappers cannot collide on it.
: >"$round_state/.probe.$$" 2>/dev/null || {
  echo "STOP: cannot write inside $round_state, so the round cap cannot be" >&2
  echo "      enforced and this refuses rather than proceed uncounted. Set" >&2
  echo "      VENDOR_ROUND_DIR somewhere writable." >&2
  exit 2
}
rm -f "$round_state/.probe.$$"
# THE `key` FILE IS APPEND-IF-ABSENT AND IS NEVER OVERWRITTEN. It was one `>` until
# 2026-09-02, so the SECOND colliding key replaced the first and the paragraph above —
# promising that a collision is "READABLE instead of merely suspected" — described a
# diagnostic that did not exist. An operator inspecting `key` after an unexplained exit
# 4 saw their own key, alone, which is byte-for-byte the reading a NON-colliding
# directory produces. Not a wrong bound and not a wrong verdict: the verdict was right
# and the one artifact for checking it was silently the wrong artifact, which is the
# class defect 16 is. Found by the vendor leg on the round that shipped the empty-hash
# refusal above, in the block that refusal was added to.
#
# MEMBERSHIP, not "differs from what is in the file". The obvious form compares the
# file's contents against this key and appends when they differ, which is correct
# exactly once: with two keys recorded, every subsequent run under EITHER of them
# differs from the whole file, appends again, and the note below fires forever over a
# file growing without bound. A diagnostic that cries collision on every run is one
# nobody reads, which is how the file stops being readable a second time.
if [ ! -e "$round_state/key" ] || ! grep -qxF "$round_key" "$round_state/key" 2>/dev/null; then
  printf '%s\n' "$round_key" >>"$round_state/key" 2>/dev/null || true
fi
# Said on EVERY run while the file holds more than one key, not only on the run that
# discovered the second one. The operator who needs this sentence is the one staring at
# an exit 4 on a branch they have not reviewed, and that is rarely the run that
# collided. `grep -c ''` rather than `wc -l` because `wc` pads its output and `[ -gt ]`
# on a padded number is an interpreter-dependent answer, which is the same defect the
# reachable-command floor's `[ -x ]` note records.
#
# COUNTED OVER DISTINCT KEYS, NOT LINES, because the check-and-append above is two steps
# and this script's whole design admits concurrent wrappers — the suite races six of them
# for one round. Two arriving together both find the key absent and both append it, and
# a line count then reports a SHARED BUDGET over one key present twice. That is this
# file's own recurring defect wearing the newest clothes: a false positive
# indistinguishable from the real reading, on the one artifact that exists to tell them
# apart, and it trains the operator to ignore the note. Raised by the vendor leg on the
# round that added the note.
#
# `sort -u` rather than a lock or an O_EXCL per-key file, and the rejected options are
# the interesting half. A file named after a HASH of the key is the obvious atomic
# registration, and it would merge two COLLIDING keys into one filename — reintroducing,
# in the fix, the exact blindness this file exists to make readable. A `mkdir` mutex
# would work and is declined for cost: it serialises a path that has no other lock, to
# prevent a duplicate LINE, once. The residual is stated rather than closed: a racing
# pair can leave one duplicate line in `key`. It cannot leave two, because the loser of
# the next race finds the key present; it cannot tear a line, because each `printf` is a
# single short write to an O_APPEND descriptor; and it can no longer be read as a
# collision, which was the only harm in it.
key_count=$(sort -u "$round_state/key" 2>/dev/null | grep -c '') || key_count=0
[ -n "$key_count" ] || key_count=0
if [ "$key_count" -gt 1 ]; then
  echo "note: this round budget is SHARED. $key_count keys hash to $round_state," >&2
  echo "      so every one of them counts against the same ROUND_CAP=$ROUND_CAP." >&2
  echo "      They are listed in $round_state/key; ROUND_RESET=1 clears the slots." >&2
fi

# A RESET MUST NOT DELETE A LIVE WRAPPER'S SLOT, because doing so breaches the very
# cap it is clearing. Wrapper A holds slot 1 and is reviewing; a reset frees 1; B
# claims 1 and reviews; A finishes without a verdict and its release deletes what is
# now B's file; C claims 1 while B is still going. Three reviews under a cap of one,
# reached by an operator clearing a count — defect 18, found by the vendor leg on the
# round that shipped defect 17's fix, in that fix's own block.
#
# So the reset asks who holds each slot and refuses while anyone does. The two ways
# that question can be answered wrongly point in OPPOSITE directions, which is the
# whole reason this is a function and not one `kill -0`: a recycled pid makes a leaked
# slot read as live, which refuses a reset that was safe and costs one `force`; a slot
# held by ANOTHER USER reads as EPERM, which reads as dead and permits a reset that
# was not safe. Only the second manufactures a cap breach, so every answer that is not
# an unambiguous "gone" is treated as LIVE.
#
# THIS PARAGRAPH DESCRIBED THAT PROTECTION BEFORE THE CODE PROVIDED IT. The previous
# round wrote "an unparseable or unreadable slot is treated as LIVE" and then tested
# `kill -0 "$pid" 2>/dev/null && live` — and an EPERM pid is neither unparseable nor
# unreadable, it is a perfectly readable pid whose probe returns 1. Measured 2026-09-02:
# `kill -0 1` (root's launchd, as a non-root user) exits 1 saying "operation not
# permitted", indistinguishable by status from pid 999999's "no such process". So the
# comment read as considered while the code fell the unsafe way — the log's own
# recurring shape, in the sentence claiming to have handled it. Reachable rather than
# exotic: VENDOR_ROUND_DIR is documented as configurable, and pointing it at a shared
# path on a multi-user host is what puts another user's pid in the file.
#
# `ps -p` is the second opinion because it answers across users where `kill -0` cannot
# (measured: `ps -p 1` exits 0, `ps -p 999999` exits 1). It is consulted only AFTER the
# builtin says "not mine", so the ordinary same-user path still runs with no external
# command in it, and DEAD requires `ps` to exit exactly 1 — a missing binary, a usage
# error, or any other status is LIVE, because a helper whose failure is indistinguishable
# from "found nothing" is the one thing this file has learned not to put above a decision.
pid_is_live() {
  kill -0 "$1" 2>/dev/null && return 0
  ps -p "$1" >/dev/null 2>&1
  case "$?" in
    1) return 1 ;;  # the only unambiguous "gone"
    *) return 0 ;;  # alive, or unanswerable — both are LIVE
  esac
}

# THE SCAN AND THE DELETE ARE NOT ONE OPERATION, so a wrapper can claim a slot in
# between them and have its live claim deleted — after which a third wrapper claims
# that same name while the second is still reviewing. Two reviews under a cap of one,
# reached without anyone doing anything wrong: the scan was honest and the delete was
# honest, and the gap between them is the whole defect. Raised by the vendor leg on the
# round that fixed the EPERM half above, in the block that fix is in.
#
# CLOSED WITH THE PRIMITIVE ALREADY HERE, not a new lock. `.resetting` is created under
# `set -C` — so two concurrent resets cannot both proceed — and it is created BEFORE the
# liveness scan, while the claim loop below refuses while it exists. That ordering is
# the entire argument: a wrapper that got past the claim loop's check must have done so
# before `.resetting` existed, so its slot file already exists when the scan runs, so
# the scan sees it. A wrapper arriving after is turned away. There is no third case.
#
# A reset that dies mid-way would otherwise wedge every future run, which is the failure
# this branch is named after. So `.resetting` carries its owner's pid and is judged by
# the same `pid_is_live` as a slot: a stale one from a dead process is taken over rather
# than obeyed. No new trust assumption — if that test can be wrong here it is already
# wrong one function up.
#
# ONLY `1` AND `force` ARE RESET REQUESTS. Until this check existed every non-empty value
# was one, so `ROUND_RESET=0` — which reads as "off" to anyone who writes it — cleared the
# branch's slots, and so did a misspelling. That is this file's own defect once more: a
# value whose plain meaning is the opposite of what it did. An EMPTY value stays "off"
# rather than joining the caps' set-but-empty refusal, and that difference is argued
# rather than assumed: an empty cap silently drops a bound the operator tried to set,
# while an empty `ROUND_RESET` does the safe thing the operator's `=` reads as.
#
# The message expands `${ROUND_RESET-}` rather than `$ROUND_RESET` because the `''` arm is
# the only thing keeping this branch unreachable with the variable unset, and an error path
# that would itself abort on `set -u` if that arm ever moved is the wrong way to be wrong.
case "${ROUND_RESET-}" in
  ''|1|force) : ;;
  *)
    echo "STOP: ROUND_RESET=${ROUND_RESET-} is not a reset request this understands." >&2
    echo "      Use ROUND_RESET=1, or ROUND_RESET=force to clear a slot that reads" >&2
    echo "      as live. Nothing was cleared and no review ran — refusing rather" >&2
    echo "      than guessing, because guessing here DELETES the cap's state." >&2
    exit 2
    ;;
esac
if [ -n "${ROUND_RESET-}" ]; then
  round_gate="$round_state/.resetting"
  round_gate_token="$$.$RANDOM.$RANDOM"
  # Invoked from the EXIT trap below and from the end of the block, which no version of
  # the linter can see: 0.9.0 reports SC2317 across the body and 0.10+ reports SC2329 on
  # the definition, and suppressing only one of them is how a green laptop shipped a red
  # CI job (defect 21). An explanatory line must not BEGIN with the linter's own name —
  # that parses as a directive, SC1073, and the first draft of this comment did it.
  # shellcheck disable=SC2329,SC2317
  round_gate_drop() {
    case "$(cat "$round_gate" 2>/dev/null)" in
      *"token $round_gate_token") rm -f "$round_gate" 2>/dev/null ;;
    esac
  }
  if ! (set -C; printf 'pid %d token %s\n' "$$" "$round_gate_token" >"$round_gate") 2>/dev/null; then
    round_gate_pid="$(cat "$round_gate" 2>/dev/null)" || round_gate_pid=''
    round_gate_pid="${round_gate_pid#pid }"
    round_gate_pid="${round_gate_pid%% *}"
    case "$round_gate_pid" in
      ''|*[!0-9]*) round_gate_pid='' ;;
    esac
    if [ -n "$round_gate_pid" ] && pid_is_live "$round_gate_pid"; then
      echo "STOP: another reset is in progress (pid $round_gate_pid). Nothing was" >&2
      echo "      cleared and no review ran. Wait for it and try again." >&2
      exit 2
    fi
    # Stale: its owner is gone, or it is unreadable and no live pid claims it. TAKING IT
    # OVER IS NOT AN OVERWRITE. The first version wrote straight over the marker, so two
    # resets that both judged it stale both proceeded, and then the first one's delete
    # removed the second one's marker and left it scanning with the door open — defect 20
    # again, through its own repair. Remove and re-create under `set -C`, so exactly one
    # of them creates the file, and refuse if that create is lost.
    rm -f "$round_gate" 2>/dev/null
    if ! (set -C; printf 'pid %d token %s\n' "$$" "$round_gate_token" >"$round_gate") 2>/dev/null; then
      echo "STOP: another reset took the stale marker in $round_state first, or it" >&2
      echo "      cannot be replaced. Nothing was cleared and no review ran." >&2
      exit 2
    fi
    echo "note: took over a stale reset marker in $round_state." >&2
  fi
  # From here every exit must drop the marker, or the next run refuses forever — and it
  # must drop only its OWN, which is what makes the residual above harmless rather than
  # merely narrow. If a racing reset does replace this marker in the two syscalls between
  # the create and here, ITS marker is the one standing, and the claim loop below is shut
  # for as long as either of them runs. A path delete is what breaks that; an ownership
  # delete cannot.
  trap round_gate_drop EXIT
  round_live=''
  for round_n in $(seq 1 "$ROUND_CAP"); do
    [ -e "$round_state/$round_n" ] || continue
    round_held="$(cat "$round_state/$round_n" 2>/dev/null)" || round_held=''
    round_pid="${round_held#pid }"
    round_pid="${round_pid%% *}"
    case "$round_pid" in
      ''|*[!0-9]*) round_live="$round_live $round_n(unreadable)" ;;
      *) pid_is_live "$round_pid" && round_live="$round_live $round_n(pid $round_pid)" ;;
    esac
  done
  if [ -n "$round_live" ] && [ "$ROUND_RESET" != force ]; then
    echo "STOP: ROUND_RESET refused — a round is still held:$round_live" >&2
    echo "      Clearing it would let another wrapper claim that same slot while" >&2
    echo "      this one is still reviewing, which breaks the cap rather than" >&2
    echo "      resetting it. Wait for the run to finish, or if you are certain" >&2
    echo "      nothing is running — a 'kill -9' leaks a slot, and a recycled pid" >&2
    echo "      reads as live — use ROUND_RESET=force." >&2
    exit 2
  fi
  # Only the slot files. `key` stays, because it is the thing that makes a hash
  # collision readable and a reset is not a reason to lose it, and `.resetting` stays
  # until this process exits because it is what keeps the claim loop out.
  for round_n in $(seq 1 "$ROUND_CAP"); do rm -f "$round_state/$round_n"; done
  echo "note: ROUND_RESET set — round count for $round_branch reset to 0." >&2
  round_gate_drop
  trap - EXIT
fi

# THE CLAIM. `set -C` makes the redirect O_EXCL, so of two wrappers reaching the
# same free slot at the same moment exactly one creates it and the other moves on.
# A stray file in this directory that is not named 1..ROUND_CAP is ignored rather
# than refused: only these names can hide a slot, so a garbage byte cannot switch
# the cap off — which is what the old numeric counter had to fail closed about.
#
# The slot carries the pid, so a reset can ask whether its holder is alive, and a
# token, so the release can ask whether the slot is still the one this process
# created. `$$` alone answers neither question across a `ROUND_RESET=force`.
# REFUSE WHILE A RESET IS MID-FLIGHT. This is the other half of the `.resetting`
# ordering above and is useless without it: claiming here while a reset is between its
# scan and its delete is exactly how a live claim gets deleted. Exit 2 rather than 4 —
# nothing was counted and nothing is exhausted, this is "ask again in a moment". A stale
# marker is judged by pid, not obeyed on sight, for the same reason as above.
if [ -e "$round_state/.resetting" ]; then
  round_gate_was="$(cat "$round_state/.resetting" 2>/dev/null)" || round_gate_was=''
  round_gate_pid="${round_gate_was#pid }"
  round_gate_pid="${round_gate_pid%% *}"
  case "$round_gate_pid" in
    ''|*[!0-9]*) round_gate_pid='' ;;
  esac
  if [ -z "$round_gate_pid" ] || pid_is_live "$round_gate_pid"; then
    echo "STOP: a ROUND_RESET is in progress for this branch, so no round was" >&2
    echo "      claimed and NO VENDOR REVIEW HAPPENED. Claiming a slot now is how" >&2
    echo "      a reset comes to delete a live claim. Re-run in a moment." >&2
    [ -n "$round_gate_pid" ] && echo "      Holder: pid $round_gate_pid" >&2
    exit 2
  fi
  # THIS SIDE DOES NOT DELETE THE MARKER, AND IT DID FOR TWO ROUNDS. First as a path
  # delete, then as a re-read followed by a delete — and the second was narrower rather
  # than closed, because POSIX has no unlink-that-checks-content: whatever gap is left
  # between the last read and the `rm` is a gap in which a new reset takes the same stale
  # marker over (the takeover path removes and re-creates the file), after which this
  # delete removes a LIVE reset's marker and the claim loop below is open for every
  # wrapper that arrives while that reset scans. `mv` does not fix it either — an atomic
  # rename moves whichever inode is at that name, so it steals a live marker just as
  # readily and leaves no un-racy way to put it back.
  #
  # So the fix is not a better delete, it is one fewer writer: MARKER MUTATION BELONGS
  # ONLY TO THE RESET PATH, which serialises it with `set -C` and an ownership token.
  # Leaving a stale marker in place costs nothing here — its holder is dead, so nothing
  # is scanning, and a claim made under it is a claim made with the door shut against
  # nobody. It is cleared by the next reset's takeover, which is the one writer allowed
  # to touch it. The visible cost is a marker that outlives its owner until then, which
  # is why this says so on every run rather than clearing it quietly.
  #
  # The re-read below survives the delete it used to guard, because it is worth more than
  # that: a marker that changed hands between the liveness test and here means a reset is
  # live NOW, and the honest answer is the refusal above rather than a claim made on a
  # verdict that has expired.
  if [ "$(cat "$round_state/.resetting" 2>/dev/null)" != "$round_gate_was" ]; then
    echo "STOP: the reset marker changed hands while it was being read, so no round" >&2
    echo "      was claimed and NO VENDOR REVIEW HAPPENED. Re-run in a moment." >&2
    exit 2
  fi
  echo "note: ignoring a stale reset marker in $round_state (pid $round_gate_pid is" >&2
  echo "      gone). Only a ROUND_RESET run clears it; this path never deletes it." >&2
fi

round_claim=''
round_count=0
round_token="$$.$RANDOM.$RANDOM"
for round_n in $(seq 1 "$ROUND_CAP"); do
  if (set -C; printf 'pid %d token %s\n' "$$" "$round_token" >"$round_state/$round_n") 2>/dev/null; then
    round_claim="$round_state/$round_n"
    round_count="$round_n"
    break
  fi
done

# RELEASE IS AN OWNERSHIP TEST, NOT A PATH TEST. `rm -f "$round_claim"` deletes
# whatever is at that name now, which after a `ROUND_RESET=force` is another
# wrapper's live claim — the same breach the reset refusal above exists to prevent,
# arriving from the other end. Comparing the token means the worst this can do is
# leave a slot behind, which refuses a round early.
# Invoked from the EXIT trap string below, not by name, which no shellcheck version can
# see. BOTH codes are needed and neither is redundant: 0.9.0 (what CI installs from apt)
# reports SC2317 on every line of the body, and 0.10+ (what brew ships, so what runs
# locally) reports SC2329 once on the definition. Suppressing only the local one is how
# this reached CI green-on-this-laptop and red-on-Linux — see the severity note in the
# workflow, which is the other half of that fix.
# shellcheck disable=SC2329,SC2317
release_claim() {
  [ -n "$round_claim" ] || return 0
  local held
  held="$(cat "$round_claim" 2>/dev/null)" || return 0
  case "$held" in
    *"token $round_token") rm -f "$round_claim" 2>/dev/null ;;
  esac
  return 0
}

# Released unless the verdict path below sets round_keep. Installed the instant the
# claim exists, so nothing between here and the launch can exit holding it.
round_keep=''
out=''
err=''
# shellcheck disable=SC2064  # $out/$err are set later; expansion must be at trap time
trap 'rm -f "$out" "$err" 2>/dev/null; [ -n "$round_keep" ] || release_claim' EXIT

if [ -z "$round_claim" ]; then
  echo "STOP: this branch has already had $ROUND_CAP vendor reviews (ROUND_CAP=$ROUND_CAP)." >&2
  echo "      Key: $round_key" >&2
  echo "      Rounds: $round_state" >&2
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED, and that is the point. Past this many the" >&2
  echo "      rounds stop being about the change and start being about the last" >&2
  echo "      round — on 2026-09-01 one 229-line script took 25 of them, 11 of" >&2
  echo "      which changed no behaviour at all. SURFACE THIS TO THE OPERATOR" >&2
  echo "      rather than working around it: say what the open findings are and" >&2
  echo "      let them decide whether another round is the right move." >&2
  echo >&2
  echo "      If it is: ROUND_CAP=$((ROUND_CAP + 3)) for a deliberate larger" >&2
  echo "      budget, or ROUND_RESET=1 if this branch is now doing different work." >&2
  exit 4
fi

out=$(mktemp) || { echo "STOP: cannot create a temp file; nothing was run." >&2; exit 2; }
# TWO FILES, because the launch below used `2>&1` into one until 2026-09-01 and
# `cat "$out"` then replayed the merged stream to our own stdout — defect 10. The
# agent-mode chain passes `--agent`, where the CLI's stdout is NDJSON, so any
# diagnostic the reviewer wrote to stderr came back out as a record the vendor
# never emitted. That is defect 7's rule ("stdout belongs to the reviewer") one
# layer in, and it is the merged-streams vacuity from defect 7's own harness in the
# PRODUCTION path: `2>&1` destroys the distinction the caller needs.
err=$(mktemp) || { echo "STOP: cannot create a temp file; nothing was run." >&2; exit 2; }
# The EXIT trap is installed ABOVE, with the round claim, and removes both these
# files as well as the claim. It used to be installed here, which would now be a
# defect rather than a tidier place for it: re-arming it at this line would silently
# drop the release clause, and a mktemp failure would then exit 2 holding a round.
# Inline rather than a `cleanup()` function: shellcheck reports SC2329 on a function
# only ever reached through `trap`, and a disable comment to keep a one-line wrapper
# is worse than not having the wrapper.

# Every pid from $1 downward, parents before children. `pgrep -P` is the only
# portable way to walk descendants on both macOS and Linux, and it lives here in
# the KILL path rather than the decision path on purpose: if it fails, a refusal
# takes longer or leaves a process behind, but no pass is manufactured.
descendants() {
  local pid="$1" kid
  printf '%s\n' "$pid"
  for kid in $(pgrep -P "$pid" 2>/dev/null); do
    descendants "$kid"
  done
}

# Kill $1 and everything under it with signal $2. The process GROUP is tried
# first, for the `setsid` case where the CLI leads one; without setsid (macOS)
# that fails and the enumerated tree is what actually does the work. Everything
# is tolerated — an already-dead target is a success for the goal here, which is
# that nothing survives this script.
#
# $3 is a tree captured BEFORE the first signal, and both escalation sites pass
# one. DEFECT 8: this used to enumerate on every call, so the KILL pass walked a
# tree that no longer existed. The direct child normally dies on TERM and its own
# children are reparented to init, `pgrep -P "$pid"` then returns nothing, and the
# escalation reached only `$pid` — missing precisely the grandchild that ignored
# TERM, which is defect 2's orphan arriving one signal later. Enumerating once and
# escalating over the same list is the whole fix.
kill_tree() {
  local pid="$1" sig="$2" tree="${3-}" p
  [ -n "$tree" ] || tree=$(descendants "$pid")
  kill "-$sig" "-$pid" 2>/dev/null || true
  for p in $tree; do
    kill "-$sig" "$p" 2>/dev/null || true
  done
}

# Defect 2 (see the header): without this, an outer timeout or a Ctrl-C killed
# the wrapper and left the reviewer running — reproduced on demand in the fixture
# suite. A vendor process that outlives its bound is the exact thing this file
# exists to prevent, so being killed is a case it has to handle, not only a case
# it causes.
#
# The disable below covers two codes, both saying the same wrong thing: SC2329
# "never invoked" and SC2317 "command appears to be unreachable". This function is
# reached only through the traps under it, and the linter does not follow trap
# strings, so every line in the body reads as dead code. Note that the reason
# cannot be written on a second comment line — a line beginning with the linter's
# own name is parsed as another directive and errors out.
#
# SC2317 was added to the list on 2026-09-01 because CI FOUND IT AND THIS MACHINE
# COULD NOT: shellcheck 0.11.0 locally emits only SC2329, while the version on the
# GitHub runner emits SC2317 on all 15 lines of the body and failed the template
# repo's `guards` job. Same class as defect 3 of the log — an environment the
# author does not have is not an environment that does not exist. This paragraph
# used to end by saying the workflows repo stayed green because its CI did not lint
# these files at all. That stopped being true when #75 added the step, and the very
# next function added to this file (`release_claim`) shipped with only SC2329 and
# turned that step red. A precedent 100 lines away, with the reason spelled out,
# does not transfer itself — copy the whole list or neither code. (Note the wording:
# an explanatory line may not BEGIN with the linter's own name, per the paragraph
# above, and the first draft of this one did, which is a parse error not a finding.)
# shellcheck disable=SC2329,SC2317
on_signal() {
  local sig="$1"
  trap - INT TERM HUP
  # Reap the wait loop's nap first. It is a real `sleep` process (defect 11 backgrounded
  # it so this trap could run at all), and leaving it behind would be defect 8's stray
  # descendant in miniature. Before the reviewer kill, because the reviewer is what the
  # operator is waiting on.
  if [ -n "$nap_pid" ]; then kill "$nap_pid" 2>/dev/null || true; fi
  if [ -n "$cr_pid" ]; then
    local tree
    tree=$(descendants "$cr_pid")
    kill_tree "$cr_pid" TERM "$tree"
    sleep 1
    kill_tree "$cr_pid" KILL "$tree"
  fi
  echo >&2
  echo "STOP: bounded-vendor-review took SIG$sig and killed the reviewer with it." >&2
  echo "      NO VENDOR REVIEW HAPPENED. Whatever killed this wrapper — an outer" >&2
  echo "      timeout, a Ctrl-C — did not produce a verdict, and the branch has" >&2
  echo "      had only the deterministic local gate." >&2
  exit 3
}
cr_pid=""
nap_pid=""
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
trap 'on_signal HUP' HUP

# Which log files already exist. Used ONLY to name this run's log(s) in the
# failure message, so the reader can go look. NOT part of any decision — the logs
# were the decision until 2026-09-01 and could not distinguish a working review
# from a hung one (defect 4). `|| true` because an unreadable or absent log
# directory must not abort the review; it just means the refusal cannot cite a
# file.
pre_logs=$(ls -1 "$LOG_DIR" 2>/dev/null || true)

# `setsid` where available so the whole process group can be killed; the CLI
# spawns children and a bare `kill` on the parent leaves them holding the socket.
# Absent on macOS, hence the fallback — the group kill below is attempted either
# way and its failure is tolerated.
if command -v setsid >/dev/null 2>&1; then
  setsid "$CR_BIN" review "$@" >"$out" 2>"$err" &
else
  "$CR_BIN" review "$@" >"$out" 2>"$err" &
fi
cr_pid=$!

# SECONDS is a Bash builtin that counts wall-clock seconds since it was assigned.
# No `date`, no arithmetic on timestamps, no external command in the decision.
SECONDS=0
connected=0
killed_reason=""

# Every log file present now and absent from the pre-launch snapshot, one path per
# line; empty output means nothing new appeared. ALL of them, not the single one
# the first version demanded: a concurrent gate in another repo writes its own log
# (defect 1). That fix now only affects which files a refusal cites, since defect 4
# took logs out of the decision entirely — but naming only some of the files still
# sends the reader to the wrong one, so "all of them" remains correct here.
new_logs() {
  local now
  now=$(ls -1 "$LOG_DIR" 2>/dev/null || true)
  comm -13 <(printf '%s\n' "$pre_logs" | sort) <(printf '%s\n' "$now" | sort) 2>/dev/null \
    | awk -v d="$LOG_DIR" 'NF { print d "/" $0 }'
}

# connected | stuck | unknown, read from THE REVIEWER'S OWN OUTPUT — both captures,
# for the ORDER LIMIT reason stated below rather than by accident.
#
# THIS READ THE LOG FILE UNTIL 2026-09-01, AND THAT WAS THE WRONG STREAM. The
# detector was built from the outage log, which is three entries ending at the
# WebSocket marker, and concluded that "no line after the marker" means hung. It
# does not. **The CLI writes nothing to its log after that marker during a
# perfectly healthy review** — all progress goes to stdout. Measured: a review
# whose stdout reached `Writing review comments... 1m 01s elapsed` had a log whose
# last line before our SIGTERM was still the marker, logged 118s earlier. So a
# working review and a hung one produced BYTE-IDENTICAL evidence, and the check
# could not tell them apart in either direction. It killed healthy reviews at
# CONNECT_CAP and called the vendor unreachable while the vendor was up.
#
# That is this repo's own rule turned on the one check written here rather than
# inherited: a check whose failure is indistinguishable from its success is not a
# check. It is also why the suite stayed green — the "connected then slow" fake
# wrote a log line after the marker, inventing the very signal the real CLI never
# emits. A double that manufactures the evidence under test proves only itself.
#
# The reviewer's stdout is already captured in "$out" and was sitting there unread
# the whole time, which is the part worth wincing at. It names its own phase on
# every progress line:
#
#   Connecting to CodeRabbit... 1m 01s elapsed - still working    <- not connected
#   Summarizing changes... 30s elapsed                            <- connected
#   Writing review comments... 54s elapsed                        <- connected
#
# So the decision is the LAST progress line, and it needs no list of phase names
# to recognise — only the one phase that means "still connecting". A vendor
# renaming or adding a later phase reads as connected, which is the safe way to be
# wrong about it.
#
#   connected  a progress line exists and the last one is not the connect phase
#   stuck      a progress line exists and the last one IS still the connect phase
#   unknown    no progress line yet, or neither capture readable — decline to kill
#              and let TOTAL_CAP carry the whole bound
#
# `tr '\r' '\n'` because the CLI redraws its progress in place with carriage
# returns, so without it the entire progress stream is one unsplittable line and
# "the last one" is meaningless.
#
# IT READS BOTH CAPTURES, and that is deliberate rather than lazy. Splitting stdout
# from stderr (defect 10) raised a question the merged file never posed: WHICH stream
# carries the progress lines? Measured only as merged, so the honest answer is
# unmeasured — and pointing this at stdout alone on the assumption it is stdout would
# recreate defect 4 exactly, a detector reading a stream that carries nothing,
# verdict permanently `unknown`, connect kill dead and every findings run refused by
# the verdict gate. Reading both is correct whichever stream it turns out to be, and
# costs only that a diagnostic containing the word `elapsed` could be mistaken for a
# progress line — which lands on `connected`, the safe side. BOTH, IN ORDER: $out
# first, $err only if $out has no progress line at all. See defect 14 of the log for why
# that ordering is not a preference.
#
# TWO CALLERS as of 2026-09-01. The early kill above, live, mid-run; and the verdict
# gate at the bottom, once, after the reviewer has returned, to tell a CLI that
# failed BEFORE reviewing from one that reviewed and found something — the CLI
# spends exit 1 on both. Same question either way ("did it get past connecting?"),
# and the same fail-safe direction: `unknown` declines to kill early and, at the end,
# declines to call a failed run a verdict.
# ORDER, NOT CONCATENATION — defect 14, and the round before it got this wrong twice
# over. `cat "$out" "$err"` merges BY FILE, not by time, so `tail -n 1` preferred an
# `elapsed` line in $err over a later one in $out: a stderr line carrying both `elapsed`
# and the connect phase read as `stuck` on a review that had connected, which is the
# UNSAFE direction — a false refusal, defect 9's shape. That was recorded here as a
# STATED LIMIT waiting on a measurement, and the second mistake was believing it needed
# one. It does not. Reading $out first and falling back to $err only when $out carries no
# progress line is correct WHICHEVER stream turns out to carry them, keeps `unknown` when
# neither does, and adds no assumption to replace the one it removes. A limit that can be
# closed without new evidence is a defect with a note on it. Raised by the PR-side review
# on 2026-09-01, one round after the same reviewer's note produced the comment above.
#
# THE FALLBACK TO $err IS NOT A STALENESS HOLE, and the next round asked whether it was.
# The fallback fires only when $out carries NO progress line at all, so a connect-phase
# line in $err is not being preferred over later evidence — it is the only evidence in
# existence, and `stuck` is the same verdict that line would produce arriving on stdout.
# Dropping the fallback there would send that case to `unknown`, which switches the early
# kill off for a run whose own output says it never connected: defect 3's shape, a bound
# disabled by ordinary conditions. What the round DID find is that no fixture constructed
# the state — the tenth shape of test blindness, two streams as competing sources of one
# signal — so `connect line on stderr is the only evidence -> still stuck` now pins it.
# Residual, stated rather than left implicit: a stderr diagnostic containing both `elapsed`
# and the connect phrase lands on `stuck` when stdout has said nothing, which is the
# refusal side. That is the safe direction here and the unsafe one when stdout HAS spoken,
# which is exactly the asymmetry the ordering above encodes.
# Last phase-naming line of one capture, empty if it has none. TWO shapes, because
# the CLI has two output modes and the skills document both: a prose progress line
# carrying `elapsed`, and an `--agent` NDJSON status record carrying `"phase":`.
# Matching either is what makes this mode-agnostic — no flag parsing, so a caller
# that reaches agent mode by any route (`--agent`, a future env var, a config file)
# is read correctly, and a mode that emits neither shape still lands on `unknown`.
_last_progress_line() {
  [ -r "$1" ] || return 0
  tr '\r' '\n' <"$1" 2>/dev/null | grep -E 'elapsed|"phase":' | tail -n 1
}

connect_verdict() {
  local last
  [ -r "$out" ] || [ -r "$err" ] || { printf 'unknown\n'; return 0; }
  last=$(_last_progress_line "$out")
  [ -n "$last" ] || last=$(_last_progress_line "$err")
  if [ -z "$last" ]; then
    printf 'unknown\n'
  elif [ "${last#*"$CONNECT_PHASE"}" != "$last" ] ||
       [ "${last#*"$CONNECT_PHASE_AGENT"}" != "$last" ]; then
    printf 'stuck\n'
  else
    printf 'connected\n'
  fi
}

while kill -0 "$cr_pid" 2>/dev/null; do
  # NEVER SLEEP PAST A DEADLINE. `sleep "$POLL"` unconditionally was defect 5,
  # raised by the PR-side review on 2026-09-01, and it is this script's own
  # recurring bug one more time: the advertised bound was not the bound. `POLL` is
  # validated as a positive integer and never against the caps, so
  # `TOTAL_CAP=900 POLL=3600` left a hung reviewer alive for about an hour, and
  # even the defaults overshot TOTAL_CAP by up to 5s. So the nap is the shortest of
  # POLL and whichever deadline is nearer.
  #
  # The connect deadline only constrains the nap while it is still IN THE FUTURE.
  # Clamping to it once passed would leave `nap` at 0 on every iteration after a
  # verdict of `unknown` — a hot spin for the rest of TOTAL_CAP, which is a worse
  # bug than the one being fixed.
  #
  # `nap` of 0 or less means a deadline is already reached, so skip the sleep
  # entirely and let the checks below fire this iteration rather than one second
  # late. No spin results: those checks break.
  nap="$POLL"
  if [ "$((TOTAL_CAP - SECONDS))" -lt "$nap" ]; then nap="$((TOTAL_CAP - SECONDS))"; fi
  if [ "$connected" -eq 0 ]; then
    connect_left="$((CONNECT_CAP - SECONDS))"
    if [ "$connect_left" -gt 0 ] && [ "$connect_left" -lt "$nap" ]; then nap="$connect_left"; fi
  fi
  # NEVER SLEEP THROUGH A SIGNAL EITHER. Defect 11, raised by the PR-side review on
  # 2026-09-01, and it is defects 2 and 8 arriving from a third direction: a signal
  # that does not reach the reviewer. Bash does not run a trap while a FOREGROUND
  # command is executing — it waits for that command to finish first — so `sleep "$nap"`
  # deferred `on_signal` by up to a whole nap. The clamp above bounds the nap by
  # TOTAL_CAP and never by POLL, so `POLL=900` held a killed wrapper's reviewer alive
  # for about fifteen minutes, sending a worktree to a vendor unsupervised, which is
  # precisely what the traps exist to prevent.
  #
  # MEASURED rather than read out of the manual, 2026-09-01: a probe script trapping
  # TERM and running `sleep 10` in the foreground, sent TERM at t=1s, printed
  # `TRAP at 10s`; the same script with the nap backgrounded and `wait`ed printed
  # `TRAP at 1s`. `wait` is the interruptible one, which is the whole fix.
  #
  # `|| true` because `wait` on an interrupted job returns 128+signal. THE FIRST
  # VERSION OF THIS COMMENT SAID that status would abort the loop under `set -e`, and
  # this script runs `set -uo pipefail` and deliberately NOT `-e` — the wait loop
  # depends on non-zero statuses from `kill`, `wait` and `grep`, so `-e` would break
  # it rather than protect it. So `|| true` is defensive against `-e` ever being added
  # and a statement at the call site that this status is EXPECTED, not the load-bearing
  # thing the comment claimed. Corrected in place, one round after it was written,
  # because a comment that gives the wrong reason for correct code is how the next
  # reader "simplifies" the code away. The pid
  # is published so on_signal can reap the nap; a trap that killed the reviewer and
  # left a stray `sleep` behind would be a smaller version of defect 8.
  if [ "$nap" -gt 0 ]; then
    sleep "$nap" &
    nap_pid=$!
    wait "$nap_pid" || true
    nap_pid=""
  fi

  # ONE LIVENESS RE-TEST BEFORE ANY DECISION. Defect 9, raised by the PR-side review
  # on 2026-09-01. The nap above is clamped to end exactly ON a deadline, and
  # liveness was tested only at the top of the loop — so a reviewer that RETURNED
  # during that final nap was reported as a cap kill: `NO VENDOR REVIEW HAPPENED`
  # printed over a review that happened, with the reviewer's own status thrown away.
  # Same family as defects 1-6 — an advertised verdict that was not the one
  # advertised — running in the other direction, a false refusal rather than a false
  # pass. Narrow window, wrong report, and this file's whole claim is that when that
  # sentence prints it is true.
  #
  # It costs no external command and no new trust: `kill -0` is a builtin, and it is
  # the test this loop ALREADY runs as its `while` condition. If it could lie about
  # death the loop would exit early into this same path anyway. Breaking with no
  # `killed_reason` hands the outcome to the verdict gate at the bottom, which reads
  # the reviewer's real status — and `wait` cannot block there, because reaching this
  # break means the process is already gone.
  kill -0 "$cr_pid" 2>/dev/null || break

  # THE DECISION. Arithmetic only.
  if [ "$SECONDS" -ge "$TOTAL_CAP" ]; then
    killed_reason="total"
    break
  fi

  # The early kill. Every failure path below leaves `connected` at 0 and simply
  # does not break, deferring to the branch above.
  if [ "$connected" -eq 0 ] && [ "$SECONDS" -ge "$CONNECT_CAP" ]; then
    case "$(connect_verdict)" in
      connected) connected=1 ;;
      stuck) killed_reason="connect"; break ;;
      *) : ;;  # unknown: nothing readable to judge by, so defer to TOTAL_CAP
    esac
  fi
done

if [ -n "$killed_reason" ]; then
  # The whole tree, not the pid: without setsid the CLI's children are in this
  # shell's process group, so a bare `kill` on the parent left them alive and
  # holding the socket. That orphan was measured, not theorised — see defect 2.
  # Enumerated ONCE, here, because after the TERM there is nothing left to
  # enumerate: the child is gone and its children belong to init. See defect 8.
  cr_tree=$(descendants "$cr_pid")
  kill_tree "$cr_pid" TERM "$cr_tree"
  sleep 2
  kill_tree "$cr_pid" KILL "$cr_tree"
fi

wait "$cr_pid" 2>/dev/null
cr_status=$?

if [ -n "$killed_reason" ]; then
  # BOTH captures, LABELLED AND IN THE VERDICT'S OWN ORDER — defect 16. And
  # `tr '\r' '\n'` before the tail, which was the fix for the first half of this:
  # it was `tail -n 15 "$out"` until 2026-09-01, and on the runs that matter most
  # — a wedged reviewer, whose entire output is in-place progress redraws — the
  # whole capture is ONE line, so the tail showed one line while the message below
  # told the operator to read "its last progress line above".
  #
  # The second half survived that round. `cat "$out" "$err"` orders BY FILE, which
  # is exactly the bug defect 14 removed from `connect_verdict`: a single stale
  # connect-phase line in `$err` printed after every later-phase line in `$out`, so
  # the display's last line was not the run's last line. The verdict below is
  # computed from the ordered read and the block above it was not, and both skills
  # tell the operator to overrule this refusal by reading this block — so the one
  # reader who cannot work around it was shown the one arrangement that cannot
  # answer the question the message asks of it. Labelled sections rather than a
  # merge with a sort: there is no shared clock across two files to sort by, and
  # inventing an interleaving would be defect 4's mistake (asserting what a stream
  # carries) in the display layer. Naming the streams lets the reader do what the
  # verdict does — read stdout first, fall back to stderr — and keeps the vendor's
  # own diagnostic, which discarding `$err` would lose.
  echo "--- reviewer stdout before the kill (the verdict reads this first) -" >&2
  tr '\r' '\n' <"$out" 2>/dev/null | tail -n 15 >&2
  echo "--- reviewer stderr before the kill -------------------------------" >&2
  tr '\r' '\n' <"$err" 2>/dev/null | tail -n 15 >&2
  echo "-------------------------------------------------------------------" >&2
  if [ "$killed_reason" = "connect" ]; then
    echo "STOP: the reviewer never got past its connect phase in ${CONNECT_CAP}s." >&2
    echo "      Its last phase in the stdout block above (or in stderr, if stdout" >&2
    echo "      carried no phase line at all) was still the connect one ('$CONNECT_PHASE'" >&2
    echo "      in prose, '$CONNECT_PHASE_AGENT' under --agent), so it" >&2
    echo "      had not reached any later phase — the signature of the vendor being" >&2
    echo "      unreachable, not of a slow review. A slow review names the phase it" >&2
    echo "      is slow in. The CLI has no timeout of its own and would have waited" >&2
    echo "      indefinitely." >&2
  else
    echo "STOP: the reviewer produced no verdict in ${TOTAL_CAP}s and was killed." >&2
  fi
  # Every log it wrote, because a run can write more than one and naming only
  # some of them sends the reader looking in the wrong file.
  while IFS= read -r log; do
    [ -n "$log" ] && echo "      Log: $log" >&2
  done < <(new_logs)
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED. This is not a clean pass and must not" >&2
  echo "      be reported as one. The branch has had only the deterministic" >&2
  echo "      local gate. Either re-run later, or push and let the PR-side" >&2
  echo "      review be the vendor review — it runs server-side and is" >&2
  echo "      unaffected by whatever broke this leg. Say in the PR which one" >&2
  echo "      the branch actually got." >&2
  exit 3
fi

# The reviewer returned on its own. Its verdict is the caller's to read: this
# script's contract is only that a verdict EXISTS. Printing the CLI's own status
# rather than adopting it keeps the one-code-for-everything problem visible
# instead of laundering it through this script's exit code.
cat "$out"
# Its stderr goes to OUR stderr — same stream it was written on. Not dropped, because
# a diagnostic the reviewer chose to emit is the operator's; not folded into the line
# above, because that is the merge defect 10 removed. Reviewer stdout to stdout,
# reviewer stderr to stderr, wrapper prose to stderr: three sources, two streams, and
# the one distinction a `--agent` parser depends on kept intact.
cat "$err" >&2
# STDOUT BELONGS TO THE REVIEWER, NOT TO THIS SCRIPT. `cat "$out"` above is the
# CLI's own output and belongs on stdout; every message this wrapper writes goes to
# stderr, including this blank separator. One documented chain calls this script
# with `--agent`, and in that mode the CLI's stdout is NDJSON — prose appended to
# it is a record the vendor never emitted, read by a parser that cannot tell the
# difference. Same shape as the rest of this file: our own output made to look like
# the thing we are reporting on.
echo >&2

# THE VERDICT GATE — defect 6. This path exited 0 UNCONDITIONALLY until 2026-09-01,
# on the contract stated just above: a verdict exists, read it yourself. The hole is
# that "returned" is not "produced a verdict". A CLI killed by a signal returns. A
# CLI that rejects its own flags, or cannot find the repository, returns before
# reviewing anything. Both scored exit 0 here, which is this file's oldest lesson
# arriving as an actual silent pass rather than a late refusal: A CHECK WHOSE
# FAILURE IS INDISTINGUISHABLE FROM ITS SUCCESS IS NOT A CHECK.
#
# Two branches, and BOTH FAIL TOWARD REFUSAL. Note what is deliberately NOT done:
# the CLI's status is not adopted. Findings exit 1, so adopting it would turn every
# review that flagged something into "no review happened" — the same conflation
# inverted. The discrimination has to come from somewhere the CLI is honest, which
# is its progress output.
reviewer_phase="$(connect_verdict)"

# Branch 1: a signal death. 128+N is unambiguous because the CLI never spends 128 or
# above on a verdict — its whole vocabulary is 0 and 1. So this needs no help from
# the output parse and holds even if that parse is broken.
if [ "$cr_status" -ge 128 ]; then
  echo "STOP: the reviewer was killed by a signal (exit status ${cr_status}) after ${SECONDS}s." >&2
  echo "      Not by this script — its own kills exit 3 with a reason above. Something" >&2
  echo "      else in the session, or the OS, took it down mid-review. A signal death" >&2
  echo "      is NOT a verdict: the CLI only ever exits 0 or 1 when it has one." >&2
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED. Read the output above for how far it got." >&2
  exit 3
fi

# Branch 2: a non-zero status with no evidence it ever got past connecting. The CLI
# names its phase from the first one onward — as an `elapsed` progress line in prose
# mode and as a `"phase":` NDJSON record under `--agent` — so a run that reached ANY
# later phase names it, and one that names none, and then failed, failed before
# reviewing. Reading only the prose shape was defect 15, and it made this branch fire
# on every findings run in the agent invocation the skills document.
# `connect_verdict` is reused here rather than reimplemented; its
# `unknown` (nothing parseable) and `stuck` (still connecting) both land on this
# side, which is the safe direction. LIMIT, stated rather than glossed: a CLI that
# reaches a later phase and THEN fails still reads as a verdict here. Whether it has
# one at that point is unmeasured — only one real transcript of a non-zero run
# exists, a findings run, and it exits 1 with a full phase sequence.
if [ "$cr_status" -ne 0 ] && [ "$reviewer_phase" != "connected" ]; then
  echo "STOP: the reviewer exited ${cr_status} without ever reaching a review phase, after ${SECONDS}s." >&2
  echo "      Its output above names no phase past the connect one ('$CONNECT_PHASE'" >&2
  echo "      in prose, '$CONNECT_PHASE_AGENT' under --agent), so it" >&2
  echo "      failed before reviewing rather than reviewing and finding something." >&2
  echo "      The CLI spends exit 1 on an unknown flag and on 'not a git repository'" >&2
  echo "      as well as on findings, so the status alone cannot tell those apart —" >&2
  echo "      the absence of any phase can, and does." >&2
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED. Fix what the output above is complaining" >&2
  echo "      about and re-run; do not report this branch as vendor-reviewed." >&2
  exit 3
fi

# KEPT HERE AND NOWHERE ELSE — past both verdict branches, on the one path where a
# review demonstrably happened. The slot was claimed before the launch, so this line
# is the decision NOT to release it; every exit above releases, and a vendor outage,
# a bad flag, a cap kill or a signal therefore spends nothing. A findings run
# (cr_status 1) reaches this line and IS a round: it happened, and it is exactly the
# round that tends to be followed by another.
#
# There is nothing here that can fail. The old shape wrote the counter at this point
# and could only WARN when that write failed — a review that happened and went
# uncounted — because refusing over a completed review is the false-refusal
# direction. Claiming up front removed the choice: the write that can fail now
# happens before the launch, where refusing it is free.
round_keep=1
echo "bounded-vendor-review: round $round_count of $ROUND_CAP for $round_branch." >&2
echo "bounded-vendor-review: reviewer returned after ${SECONDS}s with exit status ${cr_status}." >&2
echo "  That status is NOT a verdict — the CLI uses 1 for an unknown flag, for" >&2
echo "  'not a git repository', and for 'found actionable issues' alike. Read the" >&2
echo "  output above, including the 'reviewing N of M' line, which is the only" >&2
echo "  place a path filter or an empty diff shows up." >&2
exit 0
