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
# The gate's OTHER guard, preflight-vendor-review, took eleven review rounds on
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
#   STDOUT to decide — see `connect_verdict`. It asks whether the last progress
#   line still names the connect phase or a later one. That read can fail in every
#   way a parse can — no progress line yet, an unreadable capture, a renamed
#   phase — and every one of those failures makes it decline to kill early, which
#   defers to TOTAL_CAP. So the worst a broken CONNECT_CAP can do is make the
#   refusal arrive 900s late instead of 120s. It cannot manufacture a pass. That
#   asymmetry is the only reason a parse is allowed in this file at all.
#
#   THIS PARAGRAPH SAID "reads the CLI's log" until 2026-09-01 and was describing
#   the defect rather than the design — see 4 below. Kept as a correction rather
#   than silently reworded, because a design comment that outlives the design it
#   describes is how the next reader reproduces the bug.
#
# THE DEFECTS FOUND BY USING IT, all fixed here, all kept in the header because
# each is a way this file's own claims were false. Six of them, and every single
# one is the same defect: AN ADVERTISED BOUND THAT WAS NOT THE BOUND. Not one was
# found by the author reasoning about the code.
#
#   1. THE EARLY KILL WAS DEAD WHENEVER A SECOND CLI SESSION WAS RUNNING. The
#      original `this_log()` demanded EXACTLY one log file new since launch and
#      returned empty otherwise, so that a concurrent session's log could not time
#      our run against someone else's progress. That is what it did, and the cost
#      is the defect: running two gates at once on this machine is the ORDINARY
#      case, and whenever the second one's log appeared the count went to 2, the
#      early kill switched off, and the advertised 120s bound silently became the
#      900s TOTAL_CAP. Measured 2026-08-31 on a real branch: our log at 04:41:02Z,
#      a second at 04:42:21Z belonging to a `bounded-vendor-review` running in
#      another repo (its wrapper pid was alive and watching its own child, checked
#      with `ps -eo pid,ppid,pgid,lstart`). Fail-closed, and the 120s promise in
#      this header was still not what happened. A bound that switches off when a
#      second copy of the gate runs is not a bound you have.
#
#      THE ATTRIBUTION WAS WRONG FIRST TIME, and the wrong version is worth
#      recording because it is the more alarming one and it was not true: this
#      header said the CLI writes a second log from a child process within one
#      invocation. It does not. Two logs 79s apart is two chains offset by the
#      runtime of leg 1, and the same 79s appearing twice is what that offset
#      looks like, not a CLI behaviour. The fix below is unchanged by the
#      correction — the condition is "more than one new log", whatever wrote them.
#
#      So the connect test is now over ALL logs new since launch: any one of them
#      showing progress past the marker counts as connected. That keeps the
#      fail-closed direction (a healthy concurrent session makes us DECLINE to
#      kill and defer to TOTAL_CAP) while still bounding the case where every new
#      log is stuck, which is what a vendor outage looks like from here.
#
#   2. IT ORPHANED THE REVIEWER WHEN THE WRAPPER ITSELF WAS KILLED. The only trap
#      was `trap 'rm -f "$out"' EXIT`, so an outer timeout or a Ctrl-C killed the
#      wrapper and left the CLI running: an unsupervised vendor process is an
#      egress nothing is bounding, and it contradicts this file's own stated goal
#      that nothing survives. INT/TERM/HUP are now trapped and kill the reviewer's
#      whole tree before exiting 3.
#
#      PROVEN BY FIXTURE, NOT BY FIELD MEASUREMENT, and the difference matters
#      because the field observation that prompted it was misread. A live
#      `coderabbit review` was seen at 5m51s elapsed after a wrapper was killed,
#      and its parent pid was recorded without checking whether that parent was
#      still alive — on the same machine, at the same time, a concurrent gate's
#      wrapper was alive and watching exactly such a child. So treat that sighting
#      as NOT VERIFIED. What is verified is the fixture: with no signal trap, a
#      wrapper killed by SIGTERM leaves the reviewer and its grandchild running,
#      reproduced on demand in `test-bounded-vendor-review.sh` and failing red two
#      independent ways. The defect is real; the anecdote was not evidence of it.
#
#      Killing the TREE, not the pid, is the point. Without `setsid` (macOS has
#      none) the CLI shares this shell's process group, so `kill -- -$pid` fails
#      and a bare `kill $pid` leaves the grandchildren holding the socket — which
#      is precisely the orphan measured above. `pgrep -P` walks the descendants.
#      It is an external command, but it is in the KILL path, never the decision,
#      so its failure can delay a refusal and cannot manufacture a pass.
#
#   3. AN EXPLICITLY EMPTY OVERRIDE SILENTLY BECAME THE DEFAULT, so a bound the
#      operator tried to set was not set and read exactly like one that was.
#      `${VAR:-default}` substitutes for an empty value as well as an unset one, so
#      `POLL=` became 5 and `TOTAL_CAP=` became 900, and the validator's own `''`
#      branch below was unreachable dead code. Five variables had the hole and the
#      suite probed one. Found by CI rather than here, and this machine
#      structurally could not have found it: the cases asserted the exit STATUS and
#      never the message, so any exit 2 scored green, and their `CR_BIN=/bin/true`
#      does not exist on macOS (it is `/usr/bin/true`) — the harmless-real-binary
#      trick whose whole job is to leave the bad value as the only remaining reason
#      to exit 2 instead handed the script a missing binary, and every case exited 2
#      down the PATH check. On Linux the same line worked as designed and failed on
#      the real bug within a day. Fix is `${VAR-default}` throughout, one case per
#      variable, each asserting the refusal NAMES what it rejected. Two things worth
#      keeping: `CR_BIN=` fell back to the real `coderabbit` and launched an actual
#      vendor review from inside the test suite, so a vacuous default is not only a
#      wrong answer but an egress; and a double does not have to be elaborate to be
#      vacuous — this one only had to be ABSENT, which is the cheapest way there is
#      to remove the condition under test.
#
#   4. THE CONNECT DETECTOR READ THE WRONG STREAM, AND SO COULD NOT TELL A WORKING
#      REVIEW FROM A HUNG ONE. It looked in the CLI's LOG FILE for any line after
#      the WebSocket marker. The CLI writes nothing to its log after that marker
#      during a healthy review — every progress line goes to stdout. Measured
#      2026-09-01: a review whose stdout had reached `Writing review comments...
#      1m 01s elapsed` had a log whose last line before our SIGTERM was the marker,
#      written 118s earlier. Identical evidence to an outage. So the detector was
#      killing healthy reviews at CONNECT_CAP while reporting the vendor as
#      unreachable, and it had been doing so on every run since it was written.
#
#      This is the file's own rule applied to the one check invented here rather
#      than inherited from the sibling guard: A CHECK WHOSE FAILURE IS
#      INDISTINGUISHABLE FROM ITS SUCCESS IS NOT A CHECK. Worth sitting with, given
#      the header above it had already said that four times about someone else's
#      code. The fixtures could not catch it because the "connected then slow" fake
#      wrote a log line after the marker, manufacturing the signal the real CLI
#      never emits — a double that invents its own evidence proves only itself.
#
#      `connect_verdict` now reads "$out", the reviewer's own stdout, which was
#      captured and sitting unread the entire time. Consequence for defect 1 above:
#      logs are no longer part of the decision at all, so the multi-log fix is
#      correct but no longer load-bearing. `new_logs` survives only to name files
#      in the failure message, where listing all of them is still right.
#
#   5. THE POLL SLEPT PAST THE DEADLINE, so once again the advertised bound was not
#      the bound. `sleep "$POLL"` ran unconditionally at the top of the wait loop,
#      before either cap was consulted, and `POLL` is validated as a positive
#      integer and never against the caps. `TOTAL_CAP=900 POLL=3600` therefore left
#      a hung reviewer alive for about an hour, and even the defaults overshot
#      TOTAL_CAP by up to one poll interval. Raised by the PR-side review rather
#      than found here, which is worth recording: it is the FIFTH instance in this
#      one file of a bound that reads as enforced and is not, and the previous four
#      did not make the fifth visible. The nap is now the shortest of POLL and
#      whichever deadline is nearer — see the wait loop, including why the connect
#      deadline stops constraining it once passed.
#
#   6. A REVIEWER THAT NEVER REVIEWED READ AS A VERDICT. This is the first of the
#      six that was a genuine SILENT PASS rather than a late refusal, and it took
#      two of them composed to get there. The reviewer-returned path exited 0
#      unconditionally, on the stated contract that this script's job is only that
#      a verdict EXISTS and the CLI's status is the caller's to read. But a CLI that
#      died on a signal, or errored before reviewing anything, also "returns" — and
#      it produced no verdict at all. Meanwhile the git-location refusal above
#      tested `[ -n "${!v:-}" ]`, which is blind to an explicitly EMPTY value, the
#      same hole as 3 one file over. Compose them: `GIT_DIR='' <gate>` passes the
#      refusal (empty is not "set" to that test), and empty `GIT_DIR` does not
#      redirect git to another repository, it BREAKS git outright — measured
#      2026-09-01, `fatal: not a git repository: ''`, exit 128. The reviewer then
#      errors instead of reviewing, and the unconditional exit 0 reported a clean
#      vendor review that never happened.
#
#      Both halves fixed. The refusal is `[ -n "${!v+x}" ]`, which asks whether the
#      variable is SET rather than whether it has content. And the reviewer-returned
#      path now has a verdict gate with two fail-safe branches, both of which
#      refuse: a status of 128 or above is a signal death, unambiguous because the
#      CLI never spends 128+ on findings; and any non-zero status with no
#      post-connect phase line on stdout means it errored before reviewing. Note
#      what is NOT done — the CLI's status is still not adopted, because findings
#      exit 1 and adopting it would turn every flagged review into a refusal. Read
#      the output; the status is reported beside it, not laundered through ours.
#
#      `GIT_INDEX_FILE=''` behaves differently from the other three and from what
#      the sibling guard's docs record: it does not error, and git reports every
#      tracked file as `D` deleted. Those docs measure `GIT_INDEX_FILE=/tmp/empty`
#      as exit 128 `index file smaller than expected`; the empty STRING is the
#      quieter case, and both suites now cover the empty-value form of all four.
#
# 120s for the connect is not a guess about how long connecting should take —
# it is a claim that connecting does not take two minutes. NOT VERIFIED as a
# normal duration, and stated as a limit rather than glossed: the logs of the 17
# successful runs had been pruned before this was written. What IS now verified is
# the failure mode of getting it wrong. Before defect 3 was fixed the cap fired
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
# `[ -n "${!v:-}" ]` until 2026-09-01 — defect 6 in the header — and an explicitly
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
LOG_DIR="${CR_LOG_DIR-$HOME/.coderabbit/logs}"

# CR_BIN and LOG_DIR are not numbers, so the numeric loop below cannot speak for
# them. An empty CR_BIN would reach `command -v ""` and refuse by luck rather
# than by decision; an empty LOG_DIR would silently root every log path at `/`,
# where nothing matches and the connect verdict degrades to "unknown" forever —
# i.e. the early kill switched off again, which is the defect this script was
# just fixed for.
for pair in "CR_BIN:$CR_BIN" "CR_LOG_DIR:$LOG_DIR"; do
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

out=$(mktemp) || { echo "STOP: cannot create a temp file; nothing was run." >&2; exit 2; }
# Inline rather than a `cleanup()` function: shellcheck reports SC2329 on a
# function only ever reached through `trap`, and a disable comment to keep a
# one-line wrapper is worse than not having the wrapper.
trap 'rm -f "$out"' EXIT

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
kill_tree() {
  local pid="$1" sig="$2" p tree
  tree=$(descendants "$pid")
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
# The disable below is for SC2329 "never invoked": this function is reached only
# through the traps under it, and the linter does not follow trap strings. Note
# that the reason cannot be written on a second comment line — a line beginning
# with the linter's own name is parsed as another directive and errors out.
# shellcheck disable=SC2329
on_signal() {
  local sig="$1"
  trap - INT TERM HUP
  if [ -n "$cr_pid" ]; then
    kill_tree "$cr_pid" TERM
    sleep 1
    kill_tree "$cr_pid" KILL
  fi
  echo >&2
  echo "STOP: bounded-vendor-review took SIG$sig and killed the reviewer with it." >&2
  echo "      NO VENDOR REVIEW HAPPENED. Whatever killed this wrapper — an outer" >&2
  echo "      timeout, a Ctrl-C — did not produce a verdict, and the branch has" >&2
  echo "      had only the deterministic local gate." >&2
  exit 3
}
cr_pid=""
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
trap 'on_signal HUP' HUP

# Which log files already exist. Used ONLY to name this run's log(s) in the
# failure message, so the reader can go look. NOT part of any decision — the logs
# were the decision until 2026-09-01 and could not distinguish a working review
# from a hung one (defect 3). `|| true` because an unreadable or absent log
# directory must not abort the review; it just means the refusal cannot cite a
# file.
pre_logs=$(ls -1 "$LOG_DIR" 2>/dev/null || true)

# `setsid` where available so the whole process group can be killed; the CLI
# spawns children and a bare `kill` on the parent leaves them holding the socket.
# Absent on macOS, hence the fallback — the group kill below is attempted either
# way and its failure is tolerated.
if command -v setsid >/dev/null 2>&1; then
  setsid "$CR_BIN" review "$@" >"$out" 2>&1 &
else
  "$CR_BIN" review "$@" >"$out" 2>&1 &
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
# (defect 1). That fix now only affects which files a refusal cites, since defect 3
# took logs out of the decision entirely — but naming only some of the files still
# sends the reader to the wrong one, so "all of them" remains correct here.
new_logs() {
  local now
  now=$(ls -1 "$LOG_DIR" 2>/dev/null || true)
  comm -13 <(printf '%s\n' "$pre_logs" | sort) <(printf '%s\n' "$now" | sort) 2>/dev/null \
    | awk -v d="$LOG_DIR" 'NF { print d "/" $0 }'
}

# connected | stuck | unknown, read from THE REVIEWER'S OWN STDOUT.
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
#   unknown    no progress line yet, or "$out" unreadable — decline to kill and let
#              TOTAL_CAP carry the whole bound
#
# `tr '\r' '\n'` because the CLI redraws its progress in place with carriage
# returns, so without it the entire progress stream is one unsplittable line and
# "the last one" is meaningless.
#
# TWO CALLERS as of 2026-09-01. The early kill above, live, mid-run; and the verdict
# gate at the bottom, once, after the reviewer has returned, to tell a CLI that
# failed BEFORE reviewing from one that reviewed and found something — the CLI
# spends exit 1 on both. Same question either way ("did it get past connecting?"),
# and the same fail-safe direction: `unknown` declines to kill early and, at the end,
# declines to call a failed run a verdict.
connect_verdict() {
  local last
  [ -r "$out" ] || { printf 'unknown\n'; return 0; }
  last=$(tr '\r' '\n' <"$out" 2>/dev/null | grep -F 'elapsed' | tail -n 1)
  if [ -z "$last" ]; then
    printf 'unknown\n'
  elif [ "${last#*"$CONNECT_PHASE"}" != "$last" ]; then
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
  if [ "$nap" -gt 0 ]; then sleep "$nap"; fi

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
  kill_tree "$cr_pid" TERM
  sleep 2
  kill_tree "$cr_pid" KILL
fi

wait "$cr_pid" 2>/dev/null
cr_status=$?

if [ -n "$killed_reason" ]; then
  echo "--- reviewer output before the kill -------------------------------" >&2
  tail -n 15 "$out" >&2
  echo "-------------------------------------------------------------------" >&2
  if [ "$killed_reason" = "connect" ]; then
    echo "STOP: the reviewer never got past its connect phase in ${CONNECT_CAP}s." >&2
    echo "      Its last progress line above still said '$CONNECT_PHASE', so it" >&2
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
echo

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

# Branch 2: a non-zero status with no evidence it ever got past connecting. `elapsed`
# progress lines are emitted from the first phase onward, so a run that reached ANY
# later phase names it — and one that names none, and then failed, failed before
# reviewing. `connect_verdict` is reused here rather than reimplemented; its
# `unknown` (nothing parseable) and `stuck` (still connecting) both land on this
# side, which is the safe direction. LIMIT, stated rather than glossed: a CLI that
# reaches a later phase and THEN fails still reads as a verdict here. Whether it has
# one at that point is unmeasured — only one real transcript of a non-zero run
# exists, a findings run, and it exits 1 with a full phase sequence.
if [ "$cr_status" -ne 0 ] && [ "$reviewer_phase" != "connected" ]; then
  echo "STOP: the reviewer exited ${cr_status} without ever reaching a review phase, after ${SECONDS}s." >&2
  echo "      Its stdout above shows no progress line past '$CONNECT_PHASE', so it" >&2
  echo "      failed before reviewing rather than reviewing and finding something." >&2
  echo "      The CLI spends exit 1 on an unknown flag and on 'not a git repository'" >&2
  echo "      as well as on findings, so the status alone cannot tell those apart —" >&2
  echo "      the absence of any phase can, and does." >&2
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED. Fix what the output above is complaining" >&2
  echo "      about and re-run; do not report this branch as vendor-reviewed." >&2
  exit 3
fi

echo "bounded-vendor-review: reviewer returned after ${SECONDS}s with exit status ${cr_status}."
echo "  That status is NOT a verdict — the CLI uses 1 for an unknown flag, for"
echo "  'not a git repository', and for 'found actionable issues' alike. Read the"
echo "  output above, including the 'reviewing N of M' line, which is the only"
echo "  place a path filter or an empty diff shows up."
exit 0
