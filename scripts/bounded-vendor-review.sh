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
#   OUTPUT to decide — BOTH captured streams, for the reason in 10 below — see
#   `connect_verdict`. It asks whether the last progress
#   line still names the connect phase or a later one. That read can fail in every
#   way a parse can — no progress line yet, an unreadable capture, a renamed
#   phase — and every one of those failures makes it decline to kill early, which
#   defers to TOTAL_CAP. So the worst a broken CONNECT_CAP can do is make the
#   refusal arrive 900s late instead of 120s. It cannot manufacture a pass. That
#   asymmetry is the only reason a parse is allowed in this file at all.
#
#   THIS PARAGRAPH SAID "reads the CLI's log" until 2026-09-01 and was describing
#   the defect rather than the design — see 4 below. It then said "stdout" for one
#   round after defect 10 split the streams, which was the same class of stale claim
#   one revision smaller: `connect_verdict` reads both captures deliberately, because
#   WHICH stream carries the progress lines has only ever been measured merged, and
#   picking one on an assumption is how defect 4 happened. Kept as a correction rather
#   than silently reworded, because a design comment that outlives the design it
#   describes is how the next reader reproduces the bug.
#
# THE DEFECTS FOUND BY USING IT, all fixed here, all kept in the header because
# each is a way this file's own claims were false. Fourteen of them. Ten are the same
# defect — AN ADVERTISED BOUND, OR AN ADVERTISED VERDICT, THAT WAS NOT THE ONE
# ADVERTISED — and the other four are their own classes, listed anyway because
# dropping them would make the pattern look tidier than it is. Not one of the fourteen
# was found by the author reasoning about the code. TEN of the fourteen had a test that
# should have caught them and could not — defects 3, 4, and 7 through 14 — and in every
# one of those ten the vacuity was in the FIXTURE, THE HARNESS, THE INHERITED
# ENVIRONMENT, or THE ASSERTION'S ANCHOR rather than in the assertion's logic.
#
# The count is anchored to those defect IDs rather than asserted on its own, because it
# has now been wrong in three different places at once: this line said SIX, all five
# docs said SEVEN, and the entries below already numbered EIGHT distinct shapes (11 is
# labelled "a seventh shape", so 12 is the eighth). A summary number with nothing
# anchoring it drifts one round after it is written, which is the same reason the
# suite's launch count now states how to derive itself instead of naming a figure.
#
# THAT ANCHORING IS NOW A TEST, AND ITS FIRST REAL USE WAS CATCHING THIS PARAGRAPH.
# `header's own counts match its enumeration` parses the ordinals below and checks the
# totals above against them. Adding entry 13 turned it red — 13 entries against a total
# still written as the previous number — before any human read the diff. That is the
# whole argument for a mechanical check over a rule in a comment: the rule was already
# in the comment, two lines up, and it did not stop the number going stale a fourth time.
#
# AND THEN THE CHECK ITSELF WAS THE NEXT THING FOUND WRONG, one round later, which is
# the ugliest and most useful thing in this header. It greped LINE BY LINE for a claim
# that is a sentence, so a count phrase wrapped across two comment lines was invisible
# to it — and one was: entry 6 named a total of six, stale since the seventh defect
# landed, sitting green through every run of the case written to catch exactly that. The
# fix reads the comment block as one flattened string. A check whose failure is
# indistinguishable from its success is not a check, and writing a check FOR that
# failure mode is not the same as being immune to it. One cost of the fix, stated
# because it shapes this header: the check cannot tell a QUOTATION of a retired count
# from a live claim, so a stale phrase being retired is described here rather than
# quoted. Verbatim would be better history and would also be a permanent red.
#
# Six of the fourteen (9 through 14) were found only AFTER the other eight were fixed
# and written up, by reviewers reading the fixed file — 11 was found in the round that
# fixed 9 and 10, 12 in the round that fixed 11, 13 in the round that fixed 12, and 14
# in the round that fixed 13. The list is not converging on zero, and pretending
# otherwise in this header would be the same category of false claim as the defects
# themselves.
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
#   6. A REVIEWER THAT NEVER REVIEWED READ AS A VERDICT. This is the first entry in
#      this list that was a genuine SILENT PASS rather than a late refusal, and it
#      took two of them composed to get there. (Until 2026-09-01 this entry named a
#      total instead — six, which went stale five defects later and was invisible to
#      the case that checks these numbers, because the phrase wrapped across two
#      comment lines and that check read the file line by line. A count with no reason
#      to be a count is a claim that will rot; this is now a claim about the list.) The reviewer-returned path exited 0
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
#   7. THE WRAPPER'S OWN PROSE WENT OUT ON THE REVIEWER'S STDOUT. Not a bound this
#      time, and listed anyway rather than dropped for spoiling the pattern — the
#      convention above is that every defect found in this file stays in the header,
#      and quietly omitting the one that does not fit the tidy sentence is its own
#      version of the problem. The skills invoke this script with `--agent`, where
#      the CLI's stdout is a machine-readable stream; the summary line and its four
#      continuation lines went to that same stream, so a consumer parsing the vendor
#      leg read records the vendor never emitted. Every other message here was
#      already on stderr, so this was inconsistency rather than design. Caught by the
#      PR-side review on the promotion branch, before any consumer parsed it.
#
#      Its own test hole is the more interesting half: `case_run` captures `2>&1`, so
#      all thirteen fixtures were structurally blind to which stream anything went
#      to. Same lesson as 3 and 4 from a third angle — the HARNESS removed the
#      condition under test, and no amount of reading the assertions would show it.
#      The suite now has one case that captures the two streams separately, and it is
#      red on exactly one assertion against the pre-fix script.
#
#   8. THE KILL PASS RE-ENUMERATED A TREE THE TERM HAD ALREADY DISMANTLED, so a
#      grandchild that ignored SIGTERM was never killed — defect 2's orphan holding
#      the socket, arriving one signal later. `kill_tree` walked `pgrep -P` on every
#      call, and both escalation sites called it twice. After the TERM the direct
#      child is gone and its children belong to init, so the second walk returns
#      nothing and the KILL reaches only the corpse. The tree is now enumerated once,
#      before the first signal, and both passes escalate over that same list.
#
#      The fixture is again where the vacuity lived, and this is its fourth distinct
#      shape. `fake_hang_with_grandchild` runs `exec sleep 600`, which DIES ON TERM —
#      so the KILL pass was never asked to find anything, and the case that exists
#      specifically to catch orphans passes against the buggy script. Not an invented
#      signal (4), not an absent double (3), not a merged stream (7): a double that
#      COOPERATES with the thing under test. A companion fixture whose grandchild
#      does `trap '' TERM` and loops is red at `30 passed, 1 failed` against the
#      re-enumerating version, on that one case and no other. Raised by the PR-side
#      review on 2026-09-01, which named the fixture as the reason the suite was
#      blind to it and was right.
#
#   9. IT CALLED A COMPLETED REVIEW A CAP KILL — the first FALSE REFUSAL in the list
#      rather than a false pass. Liveness was tested only at the top of the wait
#      loop, and the nap inside it is clamped (defect 5's fix) to end exactly ON a
#      deadline. So a reviewer that RETURNED during that final nap met
#      `SECONDS >= TOTAL_CAP` on wake, and the loop set `killed_reason="total"`,
#      threw the reviewer's own exit status away, and printed NO VENDOR REVIEW
#      HAPPENED over a review that happened. Seventh instance of an advertised
#      verdict that was not the one advertised, running in the other direction.
#
#      The window is one nap wide, which is exactly why no case touched it: every
#      other fixture either hangs well past the cap or returns well inside a nap. A
#      boundary needs a fixture that lands ON it, and
#      `fake_finishes_during_the_final_nap` under `TOTAL_CAP=3 POLL=5` is that in the
#      smallest form there is. Fix is one `kill -0` — a builtin, and the same test the
#      loop already runs as its `while` condition, so it adds no trust assumption.
#      Red at `31 passed, 1 failed` without it, on that case and no other.
#
#  10. IT REPLAYED THE REVIEWER'S STDERR ON STDOUT. The CLI was launched with
#      `>"$out" 2>&1` and `$out` was then `cat` to this script's stdout, so any
#      diagnostic the vendor wrote to stderr came back as a line on the stream a
#      `--agent` consumer parses as NDJSON. Its own class, and a galling one: defect 7
#      is "stdout belongs to the reviewer, not to this script", fixed by moving this
#      wrapper's prose to stderr — and the merge one layer in, in the production
#      launch line, survived that whole round. Now two temp files, reviewer stdout to
#      stdout and reviewer stderr to stderr, and `connect_verdict` reads BOTH because
#      which stream carries the progress lines has only ever been measured merged.
#
#      THE HARNESS, for the second time and the sixth blind test overall.
#      `case_run` captures `2>&1`, which is right for what those cases assert and is
#      precisely what removed this condition — and defect 7's own write-up says so, in
#      this file, about this harness. The case added for defect 7 pins where THIS
#      SCRIPT's prose goes and says nothing about the reviewer's two streams, which is
#      the near-miss that reads as coverage. Red at `32 passed, 1 failed` with the
#      streams re-merged, on the new case and no other.
#
#  11. IT SLEPT THROUGH THE SIGNAL THAT WAS SUPPOSED TO KILL THE REVIEWER. The wait
#      loop's nap was a FOREGROUND `sleep "$nap"`, and bash does not run a trap while a
#      foreground command is executing — it waits for that command to finish. So
#      `on_signal` was deferred by up to a whole nap, and the clamp above it bounds the
#      nap by TOTAL_CAP and never by POLL: `POLL=900` left a killed wrapper's reviewer
#      alive for about fifteen minutes, holding the vendor socket over an unsupervised
#      worktree. Defects 2 and 8 from a third direction — a signal that does not reach
#      the reviewer — and the eighth instance of an advertised bound that was not the
#      bound, since the traps advertise "killed the reviewer with it" and that sentence
#      was true up to POLL seconds later than it read.
#
#      MEASURED, not read out of the manual, 2026-09-01: a probe trapping TERM around a
#      foreground `sleep 10`, sent TERM at t=1s, printed `TRAP at 10s`; backgrounded and
#      `wait`ed, the same probe printed `TRAP at 1s`. `wait` is the interruptible one.
#      The nap is now backgrounded, `wait`ed with `|| true` (an interrupted `wait`
#      returns 128+signal; this file runs `set -uo pipefail` and deliberately NOT `-e`,
#      so that `|| true` is defensive and declarative rather than load-bearing — the
#      first version of this entry said `-e` would abort the loop, which is not true of
#      this script and is corrected here rather than reworded away), and its pid is
#      reaped by `on_signal` — a trap that killed the reviewer and left a stray `sleep`
#      would be defect 8's orphan in miniature.
#
#      NO FIXTURE COULD HAVE CAUGHT IT AS THE SUITE WAS BUILT, which is a seventh shape
#      of blindness rather than a seventh excuse: every signal case ran at the short
#      test POLL, where a deferred trap is indistinguishable from a prompt one. The new
#      case runs `POLL` LONGER THAN THE WHOLE TEST TIMELINE, which is the only
#      arrangement in which the deferral is visible at all.
#
#  12. THE DEFAULT LOG PATH COULD MAKE THIS SCRIPT EXIT 1 — the one status it promises
#      never to use, produced by the line that builds a default. `LOG_DIR` was
#      `"${CR_LOG_DIR-$HOME/.coderabbit/logs}"`, and under `set -u` an UNSET HOME aborts
#      right there with `HOME: unbound variable`. Measured 2026-09-01: `env -u HOME`
#      against that form gives exactly that, at exit 1. The whole reason exit 3 exists is
#      that the CLI spends 1 on FINDINGS, on an unknown flag, and on "not a git
#      repository" alike; a caller reading 1 as "reviewed and flagged something" would be
#      reading a script that never reached the reviewer. Ninth instance of the advertised
#      verdict that was not the one advertised, and the second (after 6) to manufacture
#      the appearance of a review rather than merely delay a refusal.
#
#      NOT EXOTIC, which is the part worth arguing rather than asserting: HOME is absent
#      from cron, from systemd units, and from git hooks run by some daemons, and the gate
#      documentation this script belongs to suggests wiring it into a pre-push hook — the
#      same environment that armed defect 9 of the SIBLING guard, since git exports its
#      location variables to every hook it runs. Fix is `${HOME:+$HOME/...}`, which
#      yields empty for unset AND for empty, so both reach the validator below and are
#      refused with exit 2. Empty is the correct answer for both: a log root of `/`
#      matches nothing, connect_verdict() degrades to `unknown` forever, and the early
#      kill is switched off again, which is defect 3's shape one layer out.
#
#      A test could have caught this one, and the reason none did is the plainest in the
#      list: HOME is set in every shell anybody runs a test from, so absence of the
#      variable was never a state any fixture constructed. `env -u HOME` is the whole
#      case, and it is red at exit 1 against the old form.
#
#  13. THE REFUSAL THAT FIXED 12 NAMED THE WRONG VARIABLE AND GAVE ADVICE THAT COULD NOT
#      WORK. Defect 12's fix made an absent HOME yield an empty LOG_DIR, which reaches
#      the generic empty-value validator below — correct in status, and the message it
#      prints is `CR_LOG_DIR is set but empty. Unset it to take the default`. With HOME
#      absent and CR_LOG_DIR never set, EVERY CLAUSE OF THAT IS FALSE: CR_LOG_DIR is not
#      set, unsetting it changes nothing, and there is no default to take, because the
#      thing that would have built one is the variable the message does not mention. The
#      operator who lands here is in cron, a systemd unit, or a git hook — precisely
#      where HOME goes missing and precisely where there is nobody to guess.
#
#      ITS OWN CLASS, and the reason it is not filed under the nine is that the exit
#      status was right: 2, refused, no review claimed. What was false was the DIAGNOSIS.
#      That makes it the sibling guard's eleventh round arriving here — that one told the
#      caller to use `env -u`, which covers a single leg of an `&&` chain, so following
#      the guard's advice defeated the guard. Advice that cannot resolve its own refusal
#      is part of the defect and not cosmetics on top of one. Fixed with an explicit
#      branch above the generic loop, on `[ -z "${CR_LOG_DIR+x}" ] && [ -z "${HOME:-}" ]`
#      — `+x` asks SET, not non-empty, which is what leaves a genuinely set-but-empty
#      CR_LOG_DIR in the generic branch where that message is true.
#
#      THERE WAS A CASE, IT WAS MINE, AND IT PINNED THE WRONG MESSAGE — a ninth shape of
#      blindness, and the only one so far where the vacuity is in the ANCHOR rather than
#      in a fixture, a harness, or the environment. Defect 12's case asserted exit 2 and
#      the substring `CR_LOG_DIR`, and the WRONG message contains that substring as
#      readily as the right one, so it scored green on advice that could not work. Written
#      one day after the sibling guard's twelfth round said, about nine of its own
#      assertions: grep for the SENTENCE the check produces, not for a token that appears
#      in the wrong one too. Knowing the rule was not what caught it; a reviewer was.
#      The case now also requires the refusal to name HOME and to NOT carry `is set but
#      empty`, and a companion case pins the mirror image, since both refusals name
#      CR_LOG_DIR and the generic loop cannot tell them apart. Red one mutation per
#      assertion: `if false` gives "refused without naming HOME"; keeping the false
#      sentence while adding HOME gives "it is unset"; routing set-but-empty into the HOME
#      branch reds both cases at 35/2 while the generic loop's own `CR_LOG_DIR=` case
#      stays GREEN, which is what makes the new one load-bearing rather than duplicate.
#
#  14. A STALE LINE ON STDERR OUTRANKED A LIVE ONE ON STDOUT, AND REFUSED A REVIEW THAT
#      HAD CONNECTED. `connect_verdict` read `cat "$out" "$err" | tail -n 1`, and `cat`
#      orders BY FILE rather than by time: a connect-phase `elapsed` line anywhere in
#      $err beat every later phase line in $out, the verdict was `stuck`, and the early
#      kill reported the vendor unreachable at CONNECT_CAP. Defect 4's outcome exactly —
#      healthy reviews killed — reached by a different route, and the FALSE-REFUSAL
#      direction, which is defect 9's shape.
#
#      WHAT MAKES IT WORTH ITS OWN ENTRY IS THAT THE PREVIOUS ROUND KNEW AND FILED IT AS
#      A LIMIT. The comment above `connect_verdict` named this exact ordering, named the
#      unsafe direction, and said the only thing that resolves it is measuring which
#      stream carries the progress lines. That was wrong, and it is a tidier kind of wrong
#      than a missed bug: reading $out first and falling back to $err is correct whichever
#      stream carries them, keeps `unknown` when neither does, and needs no measurement at
#      all. A limit that can be closed with no new evidence was never a limit; it was a
#      defect with a note on it, and the note made it read as considered.
#
#      TENTH TEST HOLE, and it is defect 9's blindness at one remove: a STATE NO FIXTURE
#      CONSTRUCTED. Every fixture that wrote to stderr wrote one non-progress diagnostic
#      (defect 10's), and every fixture with progress lines put them all on stdout, so no
#      case ever made the two streams competing sources of the same signal.
#      `fake_slow_with_connect_line_on_stderr` is `fake_healthy_but_slow` with one line
#      moved, and it is red against the merged read with `never got past its connect
#      phase` — the outage sentence printed over a working review.
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
if [ -z "${CR_LOG_DIR+x}" ] && [ -z "${HOME:-}" ]; then
  echo "STOP: cannot build a default CR_LOG_DIR, because HOME is unset or empty" >&2
  echo "      and CR_LOG_DIR was not set either. Set CR_LOG_DIR explicitly, or" >&2
  echo "      set HOME. This is exit 2 and never exit 1: the CLI spends 1 on real" >&2
  echo "      findings, so a 1 from here would read as a review that happened." >&2
  exit 2
fi

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
# TWO FILES, because the launch below used `2>&1` into one until 2026-09-01 and
# `cat "$out"` then replayed the merged stream to our own stdout — defect 10. The
# skills pass `--agent`, where the CLI's stdout is NDJSON, so any diagnostic the
# reviewer wrote to stderr came back out as a record the vendor never emitted. That
# is defect 7's rule ("stdout belongs to the reviewer") one layer in, and it is the
# merged-streams vacuity from defect 7's own test harness appearing in the
# PRODUCTION path: `2>&1` destroys the distinction the caller needs.
err=$(mktemp) || { echo "STOP: cannot create a temp file; nothing was run." >&2; exit 2; }
# Inline rather than a `cleanup()` function: shellcheck reports SC2329 on a
# function only ever reached through `trap`, and a disable comment to keep a
# one-line wrapper is worse than not having the wrapper.
trap 'rm -f "$out" "$err"' EXIT

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
# repo's `guards` job. Same class as defect 3 in the header — an environment the
# author does not have is not an environment that does not exist. The workflows
# repo stayed green throughout, because its CI does not shellcheck these files at
# all, so the byte-identical twin was linted in exactly one of the two places.
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
# first, $err only if $out has no progress line at all. See defect 14 below for why
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
_last_progress_line() {  # last `elapsed` line of one capture, empty if it has none
  [ -r "$1" ] || return 0
  tr '\r' '\n' <"$1" 2>/dev/null | grep -F 'elapsed' | tail -n 1
}

connect_verdict() {
  local last
  [ -r "$out" ] || [ -r "$err" ] || { printf 'unknown\n'; return 0; }
  last=$(_last_progress_line "$out")
  [ -n "$last" ] || last=$(_last_progress_line "$err")
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
  echo "--- reviewer output before the kill -------------------------------" >&2
  # BOTH captures, and `tr '\r' '\n'` before the tail. This was `tail -n 15 "$out"`
  # until 2026-09-01, and on the runs that matter most — a wedged reviewer, whose
  # entire output is in-place progress redraws — the whole capture is ONE line, so
  # the tail showed one line while the message below told the operator to read "its
  # last progress line above". `connect_verdict` had split the returns since defect 4
  # and the human-facing display had not, which is the same signal made unreadable
  # for the only reader who cannot work around it.
  cat "$out" "$err" 2>/dev/null | tr '\r' '\n' | tail -n 15 >&2
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
# Its stderr goes to OUR stderr — same stream it was written on. Not dropped, because
# a diagnostic the reviewer chose to emit is the operator's; not folded into the line
# above, because that is the merge defect 10 removed. Reviewer stdout to stdout,
# reviewer stderr to stderr, wrapper prose to stderr: three sources, two streams, and
# the one distinction a `--agent` parser depends on kept intact.
cat "$err" >&2
# STDOUT BELONGS TO THE REVIEWER, NOT TO THIS SCRIPT. `cat "$out"` above is the
# CLI's own output and belongs on stdout; every message this wrapper writes goes to
# stderr, including this blank separator. The skills call this script with `--agent`,
# and in that mode the CLI's stdout is a machine-readable stream — prose appended to
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
  echo "      Its output above shows no progress line past '$CONNECT_PHASE', so it" >&2
  echo "      failed before reviewing rather than reviewing and finding something." >&2
  echo "      The CLI spends exit 1 on an unknown flag and on 'not a git repository'" >&2
  echo "      as well as on findings, so the status alone cannot tell those apart —" >&2
  echo "      the absence of any phase can, and does." >&2
  echo >&2
  echo "      NO VENDOR REVIEW HAPPENED. Fix what the output above is complaining" >&2
  echo "      about and re-run; do not report this branch as vendor-reviewed." >&2
  exit 3
fi

echo "bounded-vendor-review: reviewer returned after ${SECONDS}s with exit status ${cr_status}." >&2
echo "  That status is NOT a verdict — the CLI uses 1 for an unknown flag, for" >&2
echo "  'not a git repository', and for 'found actionable issues' alike. Read the" >&2
echo "  output above, including the 'reviewing N of M' line, which is the only" >&2
echo "  place a path filter or an empty diff shows up." >&2
exit 0
