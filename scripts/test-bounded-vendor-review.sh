#!/usr/bin/env bash
# Fixture suite for scripts/bounded-vendor-review.sh.
#
# Every case drives a FAKE `coderabbit` on PATH, so the suite is offline, fast,
# and deterministic. Nothing here contacts a vendor.
#
# THE VACUITY RISK IN THIS SUITE, named up front because it is the whole reason
# the fake is shaped the way it is. The guard under test decides "did the reviewer
# connect?" by reading the CLI's own PROGRESS OUTPUT — its stdout, not its log; this
# paragraph said "log" until 2026-09-01 and was describing the fourth defect rather
# than the design. A fake that prints something plausible and then exits promptly
# tests the happy path and nothing else — the hang is the only behaviour worth
# guarding, and a fake that never hangs removes it. So the fakes here HANG for real
# (`sleep 600`), and the assertions are about the caps firing. A case that passes in
# under its own cap has proven nothing.
#
# The corollary, which cost defect 4 and then defect 6: THE FAKES THAT DO NOT HANG
# ARE JUST AS LOAD-BEARING, and they have to print what the real CLI prints. Their
# progress lines are what separates a run that reviewed from one that failed before
# reviewing, and the two share an exit status. A fake that skips its phase lines
# models a run the CLI does not produce, and it will read the verdict gate as broken
# when it is right, or right when it is broken, depending on which way you lean.
#
# The second trap is subtler and cost a rewrite: a fake that hangs while writing
# NO log at all passes against both the real guard and a guard with the early
# kill deleted, because TOTAL_CAP catches it either way. That case is still worth
# having (it is the fail-closed path) but it cannot be the only one — so the
# stuck-at-connect case asserts on the EARLY kill's wording and its timing, which
# only the connect logic can produce.
#
# THE THIRD TRAP COST A LIVE DEFECT AND IS THE REASON THIS SUITE GREW BY THREE
# CASES. Every fake here ran ALONE and wrote exactly ONE log, while the guard
# required exactly one new log before it would run its early kill. On this machine
# two gates running at once is the ordinary case, and the second one writes its own
# log — so in the field the early kill switched off and the 120s bound silently
# became the 900s TOTAL_CAP, with the suite green throughout. Measured 2026-08-31:
# our log at 04:41:02Z, a second at 04:42:21Z from a `bounded-vendor-review` in
# another repo whose wrapper was alive and watching its own child. The fakes
# modelled a machine with one thing happening on it, which is not the machine.
# That is the usual vacuity warning from its other side: a double removes the
# condition under test by modelling too LITTLE mess as readily as too much, and
# reading either file would not have shown it. See `fake_hang_two_logs`.
#
# The other half is `fake_hang_with_grandchild`: the wrapper trapped no signals,
# so being killed from outside left the reviewer running. No existing case could
# have caught it, because every case ran the wrapper to its own conclusion. This
# is the first case that signals the wrapper instead, and the first that asserts
# on PROCESSES rather than output — which is also why it is the proof. The field
# sighting that prompted it (a live `coderabbit review` at 5m51s after a wrapper
# was killed) recorded the child's parent pid without checking whether that parent
# was still alive, and a concurrent gate's wrapper was alive on the same machine
# at the same time. That sighting is NOT VERIFIED. This case is.
#
# SEEN RED, each mutation failing in a different place. Each line carries the
# FAILURE count and the date it was measured, and NO suite total — not the pass
# count, and not the suite size the run was measured against. Both of those go
# stale on the next added case, and both were sitting right here, in this list,
# on the day the check at the bottom of this file was written to ban them: it
# scanned this file's comments and could not see them, because they were written
# with an uppercase verdict word and an `(of N, date)` tail that its pattern
# matched neither of. The PR-side review found that on 2026-09-01, one round
# after the check landed. An earlier version of this block date-stamped the
# stale counts instead of removing them, which is the same defect with an alibi
# on it: a reader still reads a number, and the date only tells them it was true
# once:
#
#   restore the log-reading detector     -> 1 FAILED (2026-09-01) — the
#     (`git show HEAD~:...`)                healthy-but-slow case, and no other,
#                                           refused with "never got past its
#                                           connect phase". That red run IS the
#                                           fourth defect stated out loud
#   replace `tr '\r' '\n'` with `cat`    -> 1 FAILED (2026-09-01) — the same
#     in the connect detector               case. The CLI redraws progress in
#                                           place, so without the split "the
#                                           last progress line" is the whole
#                                           stream and means nothing
#   `${VAR:-default}` back on the caps   -> 5 FAILED (2026-09-01) — one per
#                                           variable whose empty value silently
#                                           took a default
#   the whole pre-verdict-gate script    -> 7 FAILED (2026-09-01) — the three
#     (`git show HEAD:...`, defect 6)       verdict-gate cases and the four
#                                           empty-git-variable cases. Every
#                                           OTHER case stayed green, which is how
#                                           the reworked fakes were shown not to
#                                           have moved the old ground
#   make the 128+ branch unreachable     -> 1 FAILED (2026-09-01) — the signal
#                                           case alone, which is the point of it
#                                           being a separate branch: it holds
#                                           when the output parse does not
#   make the failed-before-reviewing     -> 2 FAILED (2026-09-01) — both
#     branch `if false`                     non-review cases, and NEITHER
#                                           findings case, so the two halves are
#                                           independent
#   drop the phase test from that        -> 2 FAILED (2026-09-01) — both
#     branch, i.e. adopt the CLI's          FINDINGS cases, the opposite pair.
#     status after all                      The gate is pinned from both sides:
#                                           too narrow loses the non-review, too
#                                           broad loses the review
#   revert `fake_found_issues` to its    -> 2 FAILED (2026-09-01) — both findings
#     pre-2026-09-01 phaseless form         cases, on a CORRECT script. That is
#     (a FIXTURE mutation, not a            the shape of a vacuous double caught
#     script one)                           from the other direction: the fake
#                                           made right code look wrong, and one
#                                           written the other way round makes
#                                           wrong code look right
#   delete the early connect kill        -> 2 FAILED (2026-08-31) — the connect
#                                           case and the two-log case
#   make a kill `exit 0` instead of 3    -> 4 FAILED (2026-08-31) — all four hang
#                                           cases
#   adopt the CLI's exit status as ours  -> 2 FAILED (2026-08-31) — both findings
#                                           cases
#   the whole pre-fix script             -> 2 FAILED (2026-08-31) — the two-log
#                                           case and the orphan case, which is
#                                           how both defects were confirmed
#                                           rather than argued
#   remove the INT/TERM/HUP traps        -> 1 FAILED (2026-08-31) — the orphan
#                                           case, reporting both surviving pids
#   kill the pid but not its descendants -> 1 FAILED (2026-08-31) — the orphan
#                                           case, reporting exactly ONE
#                                           surviving pid
#
# The last pair is worth reading together. Removing the traps orphans two
# processes; killing only the pid orphans one. That difference is what makes
# `descendants()` load-bearing rather than decoration — without the tree walk the
# grandchild survives, which is precisely the shape of the orphan measured in the
# field.
#
# The first two are the pair to keep in mind now. Both fail the SAME case and
# nothing else, so `fake_healthy_but_slow` is the only fixture standing between
# this guard and a detector that kills working reviews. An earlier version of this
# list named an "invert the awk connected test" mutation; that detector no longer
# exists — it read the log file, which is the defect — and the mutation is gone
# with it rather than silently retained as a line nobody could reproduce.
#
# ONE ASSERTION HAS NOT BEEN SEEN RED ON ITS OWN, and saying so is cheaper than
# implying otherwise. The connect case asserts both a wording and a time bound
# ("under 11s, so the early kill fired rather than TOTAL_CAP"). Deleting the early
# kill changes the wording too, so that mutation trips the text check first and
# the time bound is never the deciding assertion. It is a secondary guard against
# a future change that keeps the connect wording while losing its timeliness, and
# it has not been demonstrated to catch anything by itself.
#
# THE `setsid` BRANCH IS NOT EXERCISED ON macOS, so it was exercised by proxy.
# `bounded-vendor-review.sh` launches the CLI under `setsid` where available and
# bare where it is not; macOS has no `setsid`, so every local run of this suite
# tests only the fallback — and CI runs on Linux, which takes the other branch.
# The risk is specific: util-linux `setsid` FORKS when it is already a
# process-group leader, and if it forked here then `$!` would be setsid rather
# than the CLI, `kill -0` would go false the instant setsid exited, and a hang
# would be reported as `exit status 0` after 0s. That is a pass manufactured out
# of a hang, so it is not a difference to reason about.
#
# MEASURED 2026-08-31 with a shim on PATH implementing exactly that rule (fork if
# `pgid == pid`, else `exec`) and logging which branch it took: `11 EXECED, 0
# FORKED`. The branch log is what makes that a result rather than a green run —
# without it, a shim that quietly forked would have passed for an unrelated reason.
#
# THAT MEASUREMENT IS NOW HISTORICAL AND ITS COUNT IS NOT CURRENT, which is worth
# stating rather than quietly leaving an `11` for a reader to trust. `11` was every
# launch the suite made that day: nine `case_run` fixtures plus the orphan case
# plus the CONNECT_CAP-above-TOTAL_CAP case (the refusal cases never launch a CLI —
# they exit at the guard, or name an absent `CR_BIN`). The suite has gained
# `case_run` cases and hand-rolled launches since, so the current figure is larger
# and is deliberately not written here: it is the `case_run` fixtures, plus the
# stream-separation launches, plus the orphan and signal launches, plus the
# CONNECT_CAP-above-TOTAL_CAP case, and it is derived below. Everything added after
# 2026-08-31 was never put in front of the shim.
#
# THIS NUMBER HAS NOW BEEN WRONG TWICE IN TWO DAYS, which is the argument for deriving
# it rather than reading it. Count the `case_run` calls with
# `grep -c '\bcase_run "'` rather than `^case_run`: one of them carries a
# `POLL_OVERRIDE=` prefix, and anchoring at the line start undercounts by one — which
# it did on 2026-09-01, in the very act of correcting this number. Then add the
# `bash "$UNDER_TEST"` launches that build a fake, which is not all of them: the
# GIT_DIR and empty-value refusals build one and exit at the guard before it runs, and
# the HOME case names a real `CR_BIN` on purpose so that nothing is launched at all.
#
# The reason that is acceptable rather than a gap: since 2026-08-31 this suite runs
# in CI on ubuntu-24.04, which has a REAL util-linux `setsid`, so every case
# exercises the branch itself on every PR. The shim was a stand-in for a Linux
# runner that did not exist yet. Keep the paragraph for the failure mode it names,
# not for the number.
#
# The pass total from that day is deliberately not quoted here. It was, and a
# reader arriving after the suite grew would have read a stale number as a current
# one — which is a small instance of exactly what the block at the bottom of this
# file is about, and it recurred anyway: the counts in the SEEN RED list above went
# stale the same way and had to be date-stamped one by one. The suite's own run
# prints its own total.
#
# Usage:  scripts/test-bounded-vendor-review.sh
# Exit:   0 every case passed
#         1 at least one case failed
#         2 a fixture could not be built
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UNDER_TEST="$HERE/bounded-vendor-review.sh"
[ -f "$UNDER_TEST" ] || { echo "ERROR: $UNDER_TEST not found" >&2; exit 2; }

# REFUSE rather than repair. This was `[ -x ] || chmod +x "$UNDER_TEST"` until
# 2026-09-01, raised by the PR-side review, and it is a small member of a large
# family in this repo: the suite REPAIRED the thing it was testing, so a script
# committed without its executable bit scored a full green here and then failed in
# the field, where `~/.local/bin/bounded-vendor-review` is a symlink and a symlink
# cannot execute a non-executable target. Fixing the condition under test removes
# the condition under test — the same shape as a fake that manufactures the signal
# it is supposed to detect, one directory up.
#
# Exit 2 (a fixture could not be built), not 1: no case has run, so this is not a
# failing assertion about the guard's behaviour. `git update-index --chmod=+x` is
# the fix, because the mode has to be right in the COMMIT, not in the worktree.
if [ ! -x "$UNDER_TEST" ]; then
  echo "ERROR: $UNDER_TEST is not executable." >&2
  echo "       The installed entry point is a symlink, which cannot execute a" >&2
  echo "       non-executable target. Fix the committed mode, not the worktree:" >&2
  echo "         git update-index --chmod=+x scripts/bounded-vendor-review.sh" >&2
  exit 2
fi

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

# --- fake CLI builders -------------------------------------------------------
#
# Each writes a `coderabbit` into its own bin dir. The fakes take the log
# directory from CR_LOG_DIR so a case's log lands where the guard will look.

# EVERY HANG FAKE HERE LEAVES ITS LOG STOPPED AT THE WEBSOCKET MARKER, AND SO
# DOES THE HEALTHY ONE. That is not laziness, it is the measured behaviour of the
# real CLI (2026-09-01): the log gets nothing after that line whether the review
# is working or wedged, and all progress goes to stdout. The fakes used to
# disagree about this — the healthy one wrote a log line past the marker, which is
# a signal the real CLI never emits — and that single invented byte is why the
# suite stayed green while the guard killed working reviews. Keep them agreeing.

fake_hang_at_connect() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# The 2026-08-31 outage signature: reach the WebSocket line, then nothing, with
# stdout stuck redrawing the SAME phase. \r not \n, because that is how the CLI
# redraws in place — and without the wrapper's `tr` the whole progress stream is
# one unsplittable line, so this also covers that.
mkdir -p "$CR_LOG_DIR"
log="$CR_LOG_DIR/$(date -u +%Y-%m-%dT%H-%M-%S)-fake-$$.log"
echo '{"timestamp":"T","level":"INFO","message":"Starting CodeRabbit CLI v0.7.5"}' >>"$log"
echo '{"timestamp":"T","level":"INFO","message":"Establishing WebSocket connection to URL","url":"wss://x/ws"}' >>"$log"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Connecting to CodeRabbit... 30s elapsed\r'
printf 'Connecting to CodeRabbit... 1m 01s elapsed - still working\r'
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_healthy_but_slow() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# THE REGRESSION CASE, and the one the old fixtures could not express. A review
# that connected and is genuinely working, slowly. Its LOG IS SILENT AFTER THE
# MARKER — byte-identical to the outage fake above — and the only thing that says
# it is alive is stdout naming a later phase. Transcribed from a real run on
# 2026-09-01 whose stdout reached `Writing review comments... 1m 01s elapsed`
# while its log's last line was the marker from 118s earlier.
#
# The early kill MUST NOT fire here. Only TOTAL_CAP may. Before the detector was
# moved to stdout this fake was killed at CONNECT_CAP and told the vendor was
# unreachable.
mkdir -p "$CR_LOG_DIR"
log="$CR_LOG_DIR/$(date -u +%Y-%m-%dT%H-%M-%S)-fake-$$.log"
echo '{"timestamp":"T","level":"INFO","message":"Starting CodeRabbit CLI v0.7.5"}' >>"$log"
echo '{"timestamp":"T","level":"INFO","message":"Establishing WebSocket connection to URL","url":"wss://x/ws"}' >>"$log"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Preparing sandbox... 4s elapsed\r'
printf 'Summarizing changes... 30s elapsed\r'
printf 'Writing review comments... 1m 01s elapsed - still working\r'
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_hang_two_logs() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Two new logs from one gate's lifetime, which is what a CONCURRENT gate in
# another repo looks like from here (defect 1: the guard once required EXACTLY one
# new log, so a second one switched the early kill off). Logs no longer decide
# anything, so what this now pins is the REFUSAL MESSAGE: it must cite both files,
# because naming one of two sends the reader to the wrong file. stdout is stuck at
# the connect phase, so the early kill must still fire.
mkdir -p "$CR_LOG_DIR"
one="$CR_LOG_DIR/aaa-first-$$.log"
two="$CR_LOG_DIR/bbb-second-$$.log"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$one"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
sleep 1
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$two"
printf 'Connecting to CodeRabbit... 30s elapsed\r'
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_hang_with_grandchild() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Spawns a grandchild that outlives a bare `kill` on this process. THIS FIXTURE IS
# THE ONLY PROOF THE ORPHAN BUG WAS REAL — the 5m51s `coderabbit review` sighting
# that prompted it is NOT VERIFIED, because it recorded the child's parent pid
# without checking whether that parent was alive, and a concurrent gate's wrapper
# was alive at the same moment. Writes both pids so the case can assert nothing
# survives; neuter the wrapper's tree walk to `tree="$pid"` and one pid is left
# behind, remove its traps and two are.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
bash -c 'echo $$ >"$GRANDCHILD_PIDFILE"; exec sleep 600' &
echo $$ >"$CHILD_PIDFILE"
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_hang_with_stubborn_grandchild() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Same shape as fake_hang_with_grandchild, except the grandchild IGNORES SIGTERM.
# That one difference is the whole case. Its `exec sleep 600` dies on TERM, so the
# KILL pass never had to find anything and DEFECT 8 — a KILL that re-enumerated a
# tree the TERM had already dismantled — sat under a green suite. `trap '' TERM`
# plus a sleep loop rather than `exec`, because exec discards the trap and would
# quietly restore the vacuity this fixture exists to remove.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
bash -c 'trap "" TERM; echo $$ >"$GRANDCHILD_PIDFILE"; while :; do sleep 1; done' &
echo $$ >"$CHILD_PIDFILE"
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_hang_no_progress() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Hangs printing no parseable progress at all — no `elapsed` line, no log. The
# early kill has nothing to read, so this is the fail-closed path where TOTAL_CAP
# must carry the whole bound. This case used to be named for its missing LOG; the
# log stopped mattering when the detector moved to stdout, and what it actually
# pins now is that an UNRECOGNISED stdout format defers rather than kills. That is
# the direction a format change has to fail in: late refusal, never a false one.
echo "Connecting to CodeRabbit..."
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_slow_with_connect_line_on_stderr() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# DEFECT 14, and it is `fake_healthy_but_slow` with ONE LINE MOVED. A review that is
# connected and working, whose stderr carries an early CONNECT-phase progress line —
# a plausible thing for a vendor to write there, and the detector merged the two
# captures with `cat "$out" "$err"`, which orders BY FILE. So the stale connect line
# in $err outranked the live `Writing review comments` line in $out, the verdict was
# `stuck`, and the early kill refused a review that had connected. False refusal, the
# unsafe direction, on a review the previous fixture proves the wrapper can see.
#
# Why nothing caught it: every fixture that wrote to stderr at all wrote ONE
# non-progress diagnostic (defect 10's), and every fixture with progress lines wrote
# them only to stdout. The two streams were never both plausible sources of the same
# signal in any single case — a state no fixture had reason to construct rather than
# a bad double, which is defect 9's blindness at one remove.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
printf 'Connecting to CodeRabbit... 1s elapsed\r' >&2
printf 'Preparing sandbox... 4s elapsed\r'
printf 'Summarizing changes... 30s elapsed\r'
printf 'Writing review comments... 1m 01s elapsed - still working\r'
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_hang_connect_line_on_stderr_only() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# The OTHER HALF of the fixture above, and it is the state the defect-14 fix raised a
# question about one round later: a genuinely wedged reviewer whose only progress line
# is on STDERR. stdout says nothing at all, so `_last_progress_line "$out"` is empty and
# the verdict comes from $err — which is the fallback the reviewer asked whether stale
# stderr could poison. It cannot, and this case is the statement of why: there is no
# later evidence being outranked here, because there is no other evidence. The connect
# line is the whole of what the CLI has said, and `stuck` is the same verdict it would
# produce on stdout.
#
# What this pins is therefore the fallback ITSELF, not the ordering. Delete the `[ -n
# "$last" ] || last=$(_last_progress_line "$err")` line and this case goes to `unknown`,
# the early kill declines, and TOTAL_CAP arrives 900s later on a run whose own output
# said it never connected — defect 3's shape, a bound switched off by conditions the
# vendor chose. Read with the case above it, the pair fixes the ordering in both
# directions: $err never beats a live $out, and $err still counts when $out is silent.
printf 'Connecting to CodeRabbit... 1s elapsed\r' >&2
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_clean() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Its LOG STOPS AT THE MARKER, exactly like a hang fixture's, because that is what
# the real CLI does during a healthy review — every progress line goes to stdout and
# nothing more is logged. This fake wrote `{"message":"done"}` to the log until
# 2026-09-01, which is a line the real CLI never emits, and that one invented byte is
# what let defect 4 survive its own test: the fake manufactured the signal the
# detector was looking for, so the case proved the detector could read the fake.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Preparing sandbox... 4s elapsed\r'
printf 'Summarizing changes... 6s elapsed\r'
echo
echo "reviewing 3 of 3 changed file(s)"
echo "No findings."
exit 0
EOF
  chmod +x "$bin/coderabbit"
}

fake_clean_with_stderr_noise() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# DEFECT 10. `fake_clean` plus one line on STDERR, which is the whole case. The
# wrapper launched the CLI with `>"$out" 2>&1` and then replayed `$out` on its own
# stdout, so a diagnostic the vendor wrote to stderr came back as a line on the
# NDJSON stream the skills parse under `--agent`.
#
# No fixture could see it, for the reason defect 7 already documented and this file
# then repeated in the production path: `case_run` merges the streams, so a case that
# runs through it cannot assert which stream anything arrived on. The fixture is not
# the vacuity this time — the harness is, again.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Summarizing changes... 6s elapsed\r'
echo
echo "VENDOR-DIAGNOSTIC-ON-STDERR" >&2
echo "reviewing 3 of 3 changed file(s)"
echo "No findings."
exit 0
EOF
  chmod +x "$bin/coderabbit"
}

fake_finishes_during_the_final_nap() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# DEFECT 9. A healthy review, identical to `fake_clean` except that it returns
# INSIDE the wait loop's last nap. Driven by TOTAL_CAP=3 POLL=5: the nap is clamped
# to `TOTAL_CAP - SECONDS` = 3, this exits at 2, and the loop wakes at exactly the
# cap. Liveness was tested only at the top of the loop, so the cap branch fired on a
# reviewer that had already succeeded — `NO VENDOR REVIEW HAPPENED` over a review
# that happened, and the reviewer's own exit 0 discarded.
#
# The window is one nap wide, which is why no existing case touched it: every other
# fixture either hangs past the cap or returns well inside a nap. A boundary needs a
# fixture that lands ON it.
mkdir -p "$CR_LOG_DIR"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$CR_LOG_DIR/fake-$$.log"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
sleep 2
printf 'Summarizing changes... 2s elapsed\r'
echo
echo "reviewing 3 of 3 changed file(s)"
echo "No findings."
exit 0
EOF
  chmod +x "$bin/coderabbit"
}

fake_found_issues() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# The CLI's one-code-for-everything: findings exit 1, same as a broken flag. The
# PHASE LINES are what separate the two, and this fake had none until 2026-09-01 —
# it went straight to `reviewing N of M` and exited 1. That absence is the same
# vacuity as the log line above, from the other side: it modelled a run that reviewed
# without ever reporting a phase, which the real CLI does not do, and it would have
# scored the verdict gate green while the gate refused every real findings run.
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Preparing sandbox... 4s elapsed\r'
printf 'Writing review comments... 9s elapsed\r'
echo
echo "reviewing 3 of 3 changed file(s)"
echo "Actionable comments posted: 2"
exit 1
EOF
  chmod +x "$bin/coderabbit"
}

# DEFECT 15's two fixtures, and the hole they close is A MODE NO FIXTURE RAN. Every
# other fake in this file speaks the CLI's prose progress stream, `fake_found_issues`
# included — which is why that case, whose whole subject is the findings path this
# defect broke, is GREEN against the buggy script. It speaks the one mode the bug does
# not touch. Both fakes below are transcribed from a real `coderabbit review --agent`
# run measured 2026-09-01 on 0.7.5: NDJSON status records on stdout, no `elapsed`
# anywhere, and stderr EMPTY. Inventing a plausible-looking record here would be
# defect 4's fixture lesson again, so nothing below was written from imagination.
fake_agent_findings() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# A findings run in agent mode: reviewed, flagged something, exit 1. The verdict gate
# MUST report this as a review that happened. Against the prose-only detector the
# phase verdict is `unknown`, branch 2 fires, and the wrapper prints NO VENDOR REVIEW
# HAPPENED at exit 3 over a completed review.
echo '{"type":"review_context","reviewType":"all","currentBranch":"b","baseBranch":"main","workingDirectory":"/tmp/x"}'
echo '{"type":"status","phase":"connecting","status":"connecting_to_review_service"}'
echo '{"type":"status","phase":"setup","status":"setting_up"}'
echo '{"type":"status","phase":"analyzing","status":"summarizing"}'
echo '{"type":"status","phase":"analyzing","status":"reviewing"}'
echo '{"type":"finding","file":"a.sh","comment":"x"}'
exit 1
EOF
  chmod +x "$bin/coderabbit"
}

fake_agent_hang() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# The other direction, and the reason the fix is not "ignore `unknown`": a genuine
# agent-mode wedge, stopped at the connect record. CONNECT_CAP must still fire here,
# which it cannot do while the detector is blind to this shape — a prose-only detector
# defers to TOTAL_CAP and the advertised 120s bound is silently the 900s one, which is
# defect 1's shape. Log stopped at the marker, like every hang fake in this file.
mkdir -p "$CR_LOG_DIR"
log="$CR_LOG_DIR/$(date -u +%Y-%m-%dT%H-%M-%S)-fake-$$.log"
echo '{"timestamp":"T","level":"INFO","message":"Starting CodeRabbit CLI v0.7.5"}' >>"$log"
echo '{"timestamp":"T","level":"INFO","message":"Establishing WebSocket connection to URL","url":"wss://x/ws"}' >>"$log"
echo '{"type":"review_context","reviewType":"all","currentBranch":"b","baseBranch":"main","workingDirectory":"/tmp/x"}'
echo '{"type":"status","phase":"connecting","status":"connecting_to_review_service"}'
sleep 600
EOF
  chmod +x "$bin/coderabbit"
}

fake_error_before_reviewing() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# The CLI failing before it reviews anything: an unknown flag, or not a git
# repository. Exit 1 — the SAME status as findings (verified on 0.7.5, 2026-08-29) —
# and no phase line at all, because it never got as far as having a phase. This is
# the fake for the second branch of the verdict gate, and it is the fake the gate was
# missing when it exited 0 unconditionally.
echo "Error: Git repository not found."
exit 1
EOF
  chmod +x "$bin/coderabbit"
}

fake_dies_by_signal_mid_review() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
# Reaches a real review phase and is then killed by a signal from outside the
# wrapper — an outer harness, another agent session, the OS. It kills ITSELF here so
# the case needs no second process to time against; `wait` reports 128+15 either way.
# Distinct from the wrapper's own kills, which exit 3 with a cap named.
printf 'Connecting to CodeRabbit... 1s elapsed\r'
printf 'Summarizing changes... 5s elapsed\r'
echo
kill -TERM $$
sleep 5
EOF
  chmod +x "$bin/coderabbit"
}

# --- harness -----------------------------------------------------------------
#
# case_run <label> <want_exit> <want_text|""> <max_secs|""> <builder>
# max_secs, when set, asserts the case finished FASTER than that. For the
# connect case this is the anti-vacuity assertion: it is what distinguishes the
# early kill from TOTAL_CAP catching the same fake later.
#
# TOTAL_CAP_OVERRIDE / CONNECT_CAP_OVERRIDE / POLL_OVERRIDE let a single case
# retune the wrapper without disturbing the defaults every other case shares.
# `POLL_OVERRIDE` exists for the defect-5 case: a poll interval LONGER than a cap
# is the whole condition under test there, and it cannot be expressed while the
# harness pins `POLL=1`.

case_run() {
  # $6 is an optional substring that must be ABSENT. Only ever meaningful alongside
  # the exit-status assertion: on its own, "the output does not say X" is satisfied by
  # a script that died before printing anything, which is the absent-double vacuity
  # from defect 3 wearing an assertion instead of a fixture.
  local label="$1" want_exit="$2" want_text="$3" max_secs="$4" builder="$5" reject_text="${6-}"
  local n=$((passed + failed + 1))
  local dir="$TMP/case-$n"
  local bin="$dir/bin" logs="$dir/logs"

  mkdir -p "$dir" "$logs" || { echo "FIXTURE FAIL: $label" >&2; exit 2; }
  "$builder" "$bin" || { echo "FIXTURE FAIL: $label" >&2; exit 2; }

  local out status started elapsed
  started=$SECONDS
  out=$(
    PATH="$bin:$PATH" \
    CR_LOG_DIR="$logs" \
    TOTAL_CAP="${TOTAL_CAP_OVERRIDE:-12}" \
    CONNECT_CAP="${CONNECT_CAP_OVERRIDE:-4}" \
    POLL="${POLL_OVERRIDE:-1}" \
    bash "$UNDER_TEST" --base main 2>&1
  )
  status=$?
  elapsed=$((SECONDS - started))

  local why=""
  [ "$status" -eq "$want_exit" ] || why="exit $status, wanted $want_exit"
  if [ -z "$why" ] && [ -n "$want_text" ] && ! grep -qF "$want_text" <<<"$out"; then
    why="output lacked '$want_text'"
  fi
  if [ -z "$why" ] && [ -n "$reject_text" ] && grep -qF "$reject_text" <<<"$out"; then
    why="output contained '$reject_text' and must not have"
  fi
  if [ -z "$why" ] && [ -n "$max_secs" ] && [ "$elapsed" -ge "$max_secs" ]; then
    # Deliberately not "the early kill did not fire", which this said until
    # 2026-09-01. The bound under test is the connect kill in some cases and
    # TOTAL_CAP in the defect-5 case, and naming the wrong one sends the reader to
    # the wrong half of the script.
    why="took ${elapsed}s, needed under ${max_secs}s — the bound under test did not fire in time"
  fi

  if [ -z "$why" ]; then
    passed=$((passed + 1))
    printf 'ok   %-56s (%ds)\n' "$label" "$elapsed"
  else
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "$why"
    # awk, not `sed 's/^/.../'`: shellcheck's SC2001 fires on the sed form, and
    # the parameter expansion it suggests cannot prefix every line of a
    # multi-line string. Same choice the preflight suite makes.
    awk '{ print "       | " $0 }' <<<"$out" | head -20
  fi
}

echo "== bounded-vendor-review fixtures (TOTAL_CAP=12 CONNECT_CAP=4) =="

# The case this script exists for. Exit 3, and FAST — under TOTAL_CAP, which is
# what proves the early connect kill fired rather than the wall-clock backstop.
case_run "stuck at the WebSocket connect -> exit 3, early" \
  3 "never got past its connect phase" 11 fake_hang_at_connect

# A hang is NEVER a pass. Asserted separately from the exit code because this is
# the sentence the guard exists to make true.
case_run "stuck at connect -> says NO VENDOR REVIEW HAPPENED" \
  3 "NO VENDOR REVIEW HAPPENED" "" fake_hang_at_connect

# DEFECT 4, AND THE CASE THAT DID NOT EXIST WHEN IT SHIPPED. A review that
# CONNECTED and is working, whose log is byte-identical to the outage fake above
# because the real CLI logs nothing after the marker either. The early kill must
# NOT fire; TOTAL_CAP must catch it, and the assertion is the WORDING, since both
# paths exit 3 and only the sentence distinguishes them.
#
# Seen red against the log-reading detector: it printed "never got past its
# connect phase" at CONNECT_CAP. That is a working review declared an outage, and
# it was every real run for as long as the detector read the log.
case_run "connected but slow -> TOTAL_CAP, not the connect kill" \
  3 "produced no verdict in 12s" "" fake_healthy_but_slow

# DEFECT 14. The same review, with its connect-phase progress line on STDERR and the
# later phases on stdout. `cat "$out" "$err"` orders by file, so the stale line won and
# a connected review was refused as stuck. Asserted the same way as the case above —
# both paths exit 3, so the sentence is the whole discrimination — plus the refusal it
# must NOT print, because "produced no verdict" and "never got past its connect phase"
# are the two ways this run can end and only one of them is true of it.
case_run "connect line on stderr must not outrank a later one on stdout" \
  3 "produced no verdict in 12s" "" fake_slow_with_connect_line_on_stderr \
  "never got past its connect phase"

# The case above's mirror, and the reason both exist. The round after defect 14 asked
# whether falling back to $err could classify STALE stderr as stuck; the answer is that
# when stdout carries no progress line the $err line is not stale, it is the only thing
# the CLI has said, and `stuck` is what it would mean on either stream. Nothing had
# constructed that state — the tenth shape of blindness, two streams as competing
# sources of one signal, which is defect 14's own hole from the opposite side. So the
# fallback needs its own case or the fix to defect 14 could be "simplified" into
# switching the early kill off for every reviewer that reports progress on stderr.
#
# The 11s bound is the load-bearing half here, not the exit code: without the fallback
# this fixture still exits 3 with the wrong sentence at TOTAL_CAP. Seen red by deleting
# the `|| last=$(_last_progress_line "$err")` line — `output lacked 'never got past its
# connect phase'`, this case and no other.
case_run "connect line on stderr is the only evidence -> still stuck" \
  3 "never got past its connect phase" 11 fake_hang_connect_line_on_stderr_only

# DEFECT 1, still stuck, still early-killed. Logs are out of the decision now, so
# the time bound has stopped being about them; what is load-bearing here is the
# next case.
case_run "two logs, both stuck -> early kill still fires" \
  3 "never got past its connect phase" 11 fake_hang_two_logs

# What defect 1's fix is FOR, now that logs only appear in the refusal: a run that
# wrote two logs must have both named, because sending the reader to one of two
# files is how you conclude the wrong thing about which session hung.
case_run "two logs -> the refusal names the second one too" \
  3 "bbb-second" "" fake_hang_two_logs

# Fail closed with nothing parseable to read. TOTAL_CAP alone must still stop it.
case_run "no progress line -> TOTAL_CAP still stops it" \
  3 "produced no verdict in 12s" "" fake_hang_no_progress

# DEFECT 5: NEVER SLEEP PAST A DEADLINE. The wait loop slept the full `POLL`
# before checking either cap, and `POLL` is validated as a positive integer and
# never against the caps — so `TOTAL_CAP=900 POLL=3600` left a hung reviewer alive
# for about an hour while the script reported a 900s bound. The fifth instance in
# one file of an advertised bound that was not the bound.
#
# `POLL=40` against `TOTAL_CAP=12` states the condition in the smallest possible
# form. `fake_hang_no_progress` on purpose: its verdict is `unknown`, so the early
# kill declines and TOTAL_CAP is the ONLY thing that can stop the run, which is
# what makes the time bound here a measurement of TOTAL_CAP rather than of the
# connect kill happening to fire first.
#
# The 20s bound is the load-bearing assertion, not the exit code. Against the bare
# `sleep "$POLL"` this case exits 3 with the right wording after ~40s and passes
# every check except that one. Seen red exactly there.
POLL_OVERRIDE=40 case_run "POLL longer than TOTAL_CAP -> still stops at TOTAL_CAP" \
  3 "produced no verdict in 12s" 20 fake_hang_no_progress

# A reviewer that returns is exit 0 whatever it found, and the output passes
# through so the caller can read the verdict.
case_run "clean review -> exit 0, output passed through" \
  0 "No findings." "" fake_clean

# Findings are the CLI's exit 1. This script must NOT adopt that as its own exit
# code, or a caller cannot distinguish it from a reviewer that never ran.
case_run "findings (CLI exit 1) -> this script still exits 0" \
  0 "Actionable comments posted: 2" "" fake_found_issues

case_run "findings -> reports the CLI status without adopting it" \
  0 "exit status 1" "" fake_found_issues

# DEFECT 15, and the two cases below are the mode this whole suite had never run. The
# skills document `bounded-vendor-review --agent`, where the CLI emits NDJSON and NO
# `elapsed` line at all, so the prose-only detector returned `unknown` forever. The two
# consequences pull in opposite directions and each needs its own case, because a fix
# that only satisfied one of them is available and wrong: making branch 2 ignore
# `unknown` would pass this first case and switch the guard off for a reviewer that
# genuinely failed before connecting.
#
# The findings case is the false refusal. Same substance as the two cases above it and
# the same expected outcome, differing only in the mode — which is exactly why those two
# were green while this path was broken. The rejected substring is load-bearing here,
# since the pre-fix script exits 3 and prints it over a completed review.
case_run "agent-mode findings -> a verdict, not a refusal" \
  0 "exit status 1" "" fake_agent_findings "NO VENDOR REVIEW HAPPENED"

# And the mirror: CONNECT_CAP must still fire in agent mode. Without reading the NDJSON
# phase, the verdict is `unknown`, the early kill declines, and this run is stopped by
# TOTAL_CAP instead — the same wording swap as defect 4's case, so the SENTENCE is the
# discrimination and the 11s bound proves which cap did it.
case_run "agent-mode wedge -> the connect kill still fires" \
  3 "never got past its connect phase" 11 fake_agent_hang

# DEFECT 9, and it is the first FALSE REFUSAL in this file rather than a false pass.
# `TOTAL_CAP=3 POLL=5` makes the first nap end exactly on the cap, and the fake
# returns 0 one second inside it. The old loop then read `SECONDS >= TOTAL_CAP`
# without re-testing liveness and called a completed review a cap kill.
#
# Three assertions on one run, and the third is the point: exit 0 and the passed-through
# output prove the reviewer's status survived, and the REJECTED substring is the sentence
# this whole file is a claim about. Against the pre-fix script this case exits 3 and
# prints "produced no verdict in 3s" for a review that produced one.
TOTAL_CAP_OVERRIDE=3 CONNECT_CAP_OVERRIDE=3 POLL_OVERRIDE=5 \
  case_run "returns during the final nap -> a verdict, not a cap kill" \
  0 "No findings." "" fake_finishes_during_the_final_nap "NO VENDOR REVIEW HAPPENED"

# --- STDOUT BELONGS TO THE REVIEWER -------------------------------------------
#
# Not a `case_run`, and the reason IS the case: `case_run` captures `2>&1`, so every
# fixture above is blind to which stream anything went to. That is how the wrapper
# shipped writing its own five-line summary to stdout while the skills invoke it with
# `--agent`, where the CLI's stdout is a machine-readable stream — a parser reading
# the vendor leg gets records the vendor never emitted. The merge in `case_run` is
# right for those cases and is exactly what removed the condition here, which is the
# usual shape: the harness, not the assertion.
#
# Three assertions, and the middle one is load-bearing. Against the pre-fix script
# the first and third still pass and only "stdout carries no wrapper prose" goes red,
# which is the defect stated out loud.
# The caps are pinned like every `case_run` case rather than left to the wrapper's
# defaults, where TOTAL_CAP is 900s and the only other bound is the CI job's own
# `timeout-minutes`. A case that ever stopped exiting promptly would be reported as a
# job timeout with no case output at all, instead of as the failed assertion it is.
# No figure for that bound is quoted here, on purpose: this file is byte-identical
# across two repos whose jobs set it differently, so any number written into it is
# drift by construction. The first version said `timeout-minutes: 15` and leaned on it
# coinciding exactly with the 900s default — by then one of the two repos had moved to
# 25, and the coincidence the sentence argued from was gone along with the number.
n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" TOTAL_CAP=12 CONNECT_CAP=4 POLL=1 \
  bash "$UNDER_TEST" --base main >"$dir/stdout" 2>"$dir/stderr"
status=$?
label="wrapper prose on stderr, reviewer output on stdout"
why=""
[ "$status" -eq 0 ] || why="exit $status, wanted 0"
if [ -z "$why" ] && ! grep -qF "No findings." "$dir/stdout"; then
  why="stdout did not carry the reviewer's own output"
fi
if [ -z "$why" ] && grep -qF "bounded-vendor-review:" "$dir/stdout"; then
  why="stdout carried this wrapper's prose, which --agent consumers parse as vendor records"
fi
if [ -z "$why" ] && ! grep -qF "bounded-vendor-review: reviewer returned" "$dir/stderr"; then
  why="stderr did not carry the wrapper's summary"
fi
if [ -z "$why" ]; then
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
else
  failed=$((failed + 1)); printf 'FAIL %s -- %s\n' "$label" "$why"
fi

# --- DEFECT 10: THE REVIEWER'S OWN TWO STREAMS --------------------------------
#
# The case above pins where THIS SCRIPT's prose goes. It says nothing about the
# reviewer's own stderr, because the wrapper merged that into `$out` with `2>&1` and
# then replayed `$out` on stdout — so a vendor diagnostic arrived as a record on the
# NDJSON stream a `--agent` consumer parses. Same distinction, one layer in, and the
# case that pins the outer layer is exactly the kind of near-miss that reads as
# coverage.
#
# Four assertions. The second is the defect: against `2>&1` the diagnostic appears on
# stdout and only that one goes red. The third is what stops the fix from being
# "throw stderr away" — a diagnostic the vendor chose to emit is the operator's.
n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean_with_stderr_noise "$dir/bin"
PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" TOTAL_CAP=12 CONNECT_CAP=4 POLL=1 \
  bash "$UNDER_TEST" --base main >"$dir/stdout" 2>"$dir/stderr"
status=$?
label="reviewer stderr stays off stdout and is not dropped"
why=""
[ "$status" -eq 0 ] || why="exit $status, wanted 0"
if [ -z "$why" ] && ! grep -qF "No findings." "$dir/stdout"; then
  why="stdout did not carry the reviewer's own stdout"
fi
if [ -z "$why" ] && grep -qF "VENDOR-DIAGNOSTIC-ON-STDERR" "$dir/stdout"; then
  why="the reviewer's STDERR was replayed on stdout, where --agent consumers parse NDJSON"
fi
if [ -z "$why" ] && ! grep -qF "VENDOR-DIAGNOSTIC-ON-STDERR" "$dir/stderr"; then
  why="the reviewer's stderr was dropped entirely — the operator never sees it"
fi
if [ -z "$why" ]; then
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
else
  failed=$((failed + 1)); printf 'FAIL %s -- %s\n' "$label" "$why"
fi

# --- DEFECT 6: "returned" is not "produced a verdict" -------------------------
#
# The reviewer-returned path exited 0 unconditionally, so a CLI that died on a
# signal or failed before reviewing anything reported as a completed review — the
# first of this script's defects that was a genuine SILENT PASS. The two cases
# above are the other half of the guard and must keep passing: the gate has to
# refuse a non-review while still letting a findings run through, and the two are
# the same exit status. Break the gate in either direction and one pair goes red.
case_run "CLI failed before reviewing -> exit 3, not 0" \
  3 "without ever reaching a review phase" "" fake_error_before_reviewing

case_run "CLI failed before reviewing -> says NO VENDOR REVIEW HAPPENED" \
  3 "NO VENDOR REVIEW HAPPENED" "" fake_error_before_reviewing

# 128+N needs no help from the output parse, which is why it is a separate branch
# and gets its own case: it holds even if `connect_verdict` is broken.
case_run "reviewer killed by a signal mid-review -> exit 3, not 0" \
  3 "killed by a signal" "" fake_dies_by_signal_mid_review

# --- DEFECT 2: the wrapper itself gets killed ---------------------------------
#
# Not a case_run: it has to signal the wrapper from outside, which means running
# it in the background rather than in a command substitution. The caps are set
# above the test's own timeline on purpose — neither may fire, because the
# behaviour under test is the SIGNAL path, not the watchdog.
#
# This is the one case in the suite that asserts on a process rather than on
# output, and it is the only one that can catch an orphan. Reading the script
# will not reveal the bug: the old code's kill block was correct and simply never
# ran, because nothing trapped the signal that killed the wrapper.

echo "== killed from outside =="

n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_with_grandchild "$dir/bin"
cpid="$dir/child.pid"; gpid="$dir/grandchild.pid"

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" \
  CHILD_PIDFILE="$cpid" GRANDCHILD_PIDFILE="$gpid" \
  TOTAL_CAP=60 CONNECT_CAP=59 POLL=1 \
  bash "$UNDER_TEST" --base main >"$dir/out" 2>&1 &
wrapper=$!

for _ in $(seq 1 30); do
  [ -s "$cpid" ] && [ -s "$gpid" ] && break
  sleep 0.5
done
child=$(cat "$cpid" 2>/dev/null); grandchild=$(cat "$gpid" 2>/dev/null)

kill -TERM "$wrapper" 2>/dev/null
wait "$wrapper" 2>/dev/null
sleep 2

survivors=""
for p in $child $grandchild; do
  kill -0 "$p" 2>/dev/null && survivors="${survivors:+$survivors }$p"
done

label="wrapper killed by SIGTERM -> reviewer tree dies with it"
if [ -z "$child" ] || [ -z "$grandchild" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "fixture never recorded both pids"
elif [ -n "$survivors" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "orphaned: $survivors"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
elif ! grep -qF "NO VENDOR REVIEW HAPPENED" "$dir/out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "killed the tree but did not say no review happened"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
else
  passed=$((passed + 1))
  printf 'ok   %s\n' "$label"
fi

# Whatever the verdict, do not leak `sleep 600` processes out of the suite.
for p in $child $grandchild; do kill -KILL "$p" 2>/dev/null || true; done

# --- DEFECT 8: the KILL pass had nothing left to escalate against --------------
#
# The case above passes against the buggy script, and that is the point of this
# one. Its grandchild is `exec sleep 600`, which dies on the TERM, so the KILL pass
# was never asked to find anything and could re-enumerate a dismantled tree
# undetected. Here the grandchild IGNORES TERM, which is the only state in which
# the escalation matters: the child dies, its children are reparented to init,
# `pgrep -P "$child"` returns nothing, and a KILL that enumerates at call time
# reaches only the corpse. Raised by the PR-side review on 2026-09-01 — which also
# named the fixture as the reason the suite could not see it, and was right.
#
# Same lesson as defects 3, 4 and 7 from a fourth angle: the double did not invent
# a signal or merge two streams, it modelled a process that COOPERATES with the
# thing under test. A fake that dies politely cannot exercise an escalation.

n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_with_stubborn_grandchild "$dir/bin"
cpid="$dir/child.pid"; gpid="$dir/grandchild.pid"

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" \
  CHILD_PIDFILE="$cpid" GRANDCHILD_PIDFILE="$gpid" \
  TOTAL_CAP=60 CONNECT_CAP=59 POLL=1 \
  bash "$UNDER_TEST" --base main >"$dir/out" 2>&1 &
wrapper=$!

for _ in $(seq 1 30); do
  [ -s "$cpid" ] && [ -s "$gpid" ] && break
  sleep 0.5
done
child=$(cat "$cpid" 2>/dev/null); grandchild=$(cat "$gpid" 2>/dev/null)

kill -TERM "$wrapper" 2>/dev/null
wait "$wrapper" 2>/dev/null
sleep 2

survivors=""
for p in $child $grandchild; do
  kill -0 "$p" 2>/dev/null && survivors="${survivors:+$survivors }$p"
done

label="grandchild that IGNORES TERM -> the KILL pass still reaches it"
if [ -z "$child" ] || [ -z "$grandchild" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "fixture never recorded both pids"
elif [ -n "$survivors" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "survived TERM and was never KILLed: $survivors"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
else
  passed=$((passed + 1))
  printf 'ok   %s\n' "$label"
fi

for p in $child $grandchild; do kill -KILL "$p" 2>/dev/null || true; done

# --- DEFECT 11: the trap was correct and could not run for up to POLL seconds ---
#
# Both cases above pass against the buggy script, for one reason: they run `POLL=1`,
# where a trap deferred by a whole nap and a trap that fires at once are one second
# apart and indistinguishable. Bash does not run a trap while a FOREGROUND command is
# executing, so `sleep "$nap"` held `on_signal` off, and the clamp bounds the nap by
# TOTAL_CAP and never by POLL — `POLL=900` meant a killed wrapper's reviewer kept the
# vendor socket for about fifteen minutes over an unsupervised worktree.
#
# So this case does the only thing that makes the deferral visible: `POLL` LONGER THAN
# THE WHOLE TEST TIMELINE. It asserts on the CLOCK, not just on the outcome — the two
# scripts produce the same message and the same exit 3, and differ only in when. That
# is a seventh shape of test blindness to go with the six in the header: not an absent
# double, an invented signal, a merged harness, a cooperating process, or a boundary no
# fixture landed on, but a PARAMETER every case happened to share, which collapsed the
# very interval under test. Raised by the PR-side review on 2026-09-01.

n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_with_grandchild "$dir/bin"
cpid="$dir/child.pid"; gpid="$dir/grandchild.pid"

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" \
  CHILD_PIDFILE="$cpid" GRANDCHILD_PIDFILE="$gpid" \
  TOTAL_CAP=120 CONNECT_CAP=119 POLL=60 \
  bash "$UNDER_TEST" --base main >"$dir/out" 2>&1 &
wrapper=$!

for _ in $(seq 1 30); do
  [ -s "$cpid" ] && [ -s "$gpid" ] && break
  sleep 0.5
done
child=$(cat "$cpid" 2>/dev/null); grandchild=$(cat "$gpid" 2>/dev/null)

# The nap is already running by now: the reviewer is launched before the loop, and the
# first iteration clamps to min(POLL, TOTAL_CAP-SECONDS, CONNECT_CAP-SECONDS) = 60.
t0=$SECONDS
kill -TERM "$wrapper" 2>/dev/null
wait "$wrapper" 2>/dev/null; wstatus=$?
elapsed=$((SECONDS - t0))

label="POLL longer than the timeline -> TERM is not deferred"
if [ -z "$child" ] || [ -z "$grandchild" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "fixture never recorded both pids"
elif [ "$elapsed" -ge 20 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "took ${elapsed}s to act on TERM; the nap swallowed it"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
elif [ "$wstatus" -ne 3 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $wstatus, wanted 3"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
elif ! grep -qF "NO VENDOR REVIEW HAPPENED" "$dir/out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "acted promptly but did not say no review happened"
  awk '{ print "       | " $0 }' "$dir/out" | head -10
else
  passed=$((passed + 1))
  printf 'ok   %s\n' "$label"
fi

for p in $child $grandchild; do kill -KILL "$p" 2>/dev/null || true; done

# --- guard-refusal cases (no fake needed, and must not run one) ---------------

echo "== refusals =="

n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" GIT_DIR=/tmp/somewhere/.git \
  bash "$UNDER_TEST" --base main 2>&1); status=$?
if [ "$status" -eq 2 ] && grep -qF "git location variable(s) set" <<<"$out"; then
  passed=$((passed + 1)); printf 'ok   %s\n' "GIT_DIR set -> exit 2, refuses"
else
  failed=$((failed + 1)); printf 'FAIL %s (exit %s)\n' "GIT_DIR set -> exit 2, refuses" "$status"
fi

# Defect 6's other half. `[ -n "${!v:-}" ]` was blind to an explicitly EMPTY value,
# so `GIT_DIR= <the gate>` passed this refusal and the vendor leg inherited it.
# Empty is not harmless: `GIT_DIR=''` makes git fail outright rather than read
# elsewhere, so the reviewer errors, and before the verdict gate above that came back
# as exit 0 — the two findings composed into a clean report of a review that never
# ran. One case per variable, because the hole was in the TEST and not in one name.
#
# The assertion greps for the variable's name IN THE FIRST LINE, after the colon.
# Greping for the bare name would be vacuous: the refusal's `unset ...` advice lists
# all four every time, so every case would score green whichever one was set.
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; do
  n=$((passed + failed + 1))
  dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
  fake_clean "$dir/bin"
  out=$(env "$v=" PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" \
    bash "$UNDER_TEST" --base main 2>&1); status=$?
  label="$v set but EMPTY -> exit 2, names $v"
  if [ "$status" -eq 2 ] && grep -qF "variable(s) set in the environment: $v" <<<"$out"; then
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  else
    failed=$((failed + 1)); printf 'FAIL %s (exit %s)\n' "$label" "$status"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  fi
done

# A missing CLI must be exit 2 (cannot do the job), never exit 0. An empty PATH
# would also hide `mktemp`, so CR_BIN names something absent instead.
out=$(CR_BIN=coderabbit-does-not-exist bash "$UNDER_TEST" 2>&1); status=$?
if [ "$status" -eq 2 ] && grep -qF "is not on PATH" <<<"$out"; then
  passed=$((passed + 1)); printf 'ok   %s\n' "CLI absent -> exit 2, not 0"
else
  failed=$((failed + 1)); printf 'FAIL %s (exit %s)\n' "CLI absent -> exit 2, not 0" "$status"
fi

# Nonsense caps are a refusal, not a default. A cap silently coerced to 0 would
# kill every review instantly; one coerced to a huge number restores the
# unbounded wait this script exists to remove.
#
# TWO DEFECTS IN THIS BLOCK, both found 2026-09-01, and between them they hid a
# real product defect from the dev machine while the suite read 17 passed.
#
# 1. It asserted `status -eq 2` AND NOTHING ELSE, so any exit 2 scored green —
#    including one from a completely unrelated refusal. The house rule one layer
#    out: a check whose failure is indistinguishable from its success is not a
#    check. Each case must now exit 2 AND name the variable it rejected.
#
# 2. `CR_BIN=/bin/true` — /bin/true DOES NOT EXIST ON macOS, where it lives at
#    /usr/bin/true. The harmless-real-binary trick, whose entire job is to leave
#    the bad value as the ONLY remaining reason to exit 2, therefore handed the
#    script a MISSING binary on the dev machine, and the empty-value cases all
#    exited 2 down the PATH check instead. On Linux CI the same line worked as
#    designed and failed `POLL=` on the real bug within a day. `CR_BIN=true` is
#    portable, since `command -v` finds the builtin. A double does not have to be
#    elaborate to be vacuous; this one only had to be absent.
#
# One case per variable now, not `POLL=` alone: `${VAR:-default}` swallowed the
# empty string for all five, so four of them had the hole and no case at all.
# `$bad` goes LAST so that `CR_BIN=` overrides the CR_BIN=true before it.
for bad in "TOTAL_CAP=abc" "TOTAL_CAP=0" "CONNECT_CAP=-5" \
           "POLL=" "TOTAL_CAP=" "CONNECT_CAP=" "CR_BIN=" "CR_LOG_DIR=" ; do
  out=$(env CR_BIN=true "$bad" bash "$UNDER_TEST" 2>&1); status=$?
  label="rejects $bad, naming it"
  if [ "$status" -eq 2 ] && grep -qF "${bad%%=*}" <<<"$out"; then
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  else
    failed=$((failed + 1)); printf 'FAIL %s (exit %s, or did not name it)\n' "$label" "$status"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  fi
done

# The MIRROR IMAGE of the hole closed in the HOME case below, and it needs its own
# case for the same reason that one did: both refusals name CR_LOG_DIR, so the loop
# above cannot tell them apart, and a future fix that routed a genuinely set-but-
# empty CR_LOG_DIR into the HOME branch would be a lie in the other direction —
# blaming an absent HOME while HOME is sitting right there, set. The two branches
# turn on `${CR_LOG_DIR+x}` vs `${CR_LOG_DIR:-}`, i.e. SET vs NON-EMPTY, and that
# one character is the whole distinction; a suite that greps only the shared token
# pins neither side of it. HOME is deliberately left INHERITED here, because the
# environment this case models is the ordinary one.
out=$(env CR_BIN=true CR_LOG_DIR= bash "$UNDER_TEST" 2>&1); status=$?
label="CR_LOG_DIR= blames CR_LOG_DIR, not an absent HOME"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif ! grep -qF "is set but empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "did not say CR_LOG_DIR is set but empty"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif grep -qF "HOME is unset or empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "blamed HOME, which is set in this environment"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# --- DEFECT 12: an ABSENT HOME, which no fixture had ever constructed ---------
#
# The default log path was `"${CR_LOG_DIR-$HOME/.coderabbit/logs}"`, and under
# `set -u` an unset HOME aborts the script there with `HOME: unbound variable` at
# exit 1 — the one status this file promises never to use, because the CLI spends
# 1 on findings, on an unknown flag, and on "not a git repository" alike. A caller
# reading 1 as "reviewed and flagged something" reads a script that never launched
# the reviewer.
#
# WHY NO CASE EXISTED, and it is the plainest reason in the suite: HOME is set in
# every shell anyone runs a test from, so the ABSENCE of the variable was a state
# no fixture had reason to build. Not an absent double, an invented signal, a
# merged harness, a cooperating process, an unlanded boundary, or a shared knob —
# an environment the harness inherited and therefore never chose.
#
# Five assertions, and the last two were added on 2026-09-01 after the PR-side
# review pointed out that THE FIRST THREE PINNED THE WRONG MESSAGE. `-ne 1` because
# exit 1 IS the defect, not a symptom of it; no `unbound variable` because that
# string is the abort itself and its absence is what "the expansion was guarded"
# means; and the refusal must name CR_LOG_DIR, since an empty log root left
# unrefused would degrade connect_verdict() to `unknown` forever, which is the
# early kill switched off (defect 3's shape).
#
# WHY THAT WAS NOT ENOUGH, and it is the twelfth preflight round's lesson landing in
# this suite one day after being written down there. With HOME absent the script
# fell through to the generic empty-value refusal, which says "CR_LOG_DIR is set but
# empty. Unset it to take the default" — false in both sentences here, and silent
# about HOME. The substring `CR_LOG_DIR` appears in that wrong message too, so this
# case scored green on advice that could not resolve its own refusal. Grep for the
# SENTENCE the check produces, not for a token that appears in the wrong one as
# readily as the right one.
#
# So: the refusal must NAME HOME as the cause, and must NOT contain the phrase that
# would be a lie in this environment. The second of those is the load-bearing half —
# a fix that merely appended the word HOME to the old message would satisfy the
# first and still hand cron's operator an instruction that does nothing.
#
# No fake and no `$dir`: `CR_BIN=true` is a real command, so this case must never
# reach a launch, and giving it a bin directory would only invite one.
out=$(env -u HOME CR_BIN=true bash "$UNDER_TEST" 2>&1); status=$?
label="HOME unset -> exit 2 blaming HOME, never exit 1"
if [ "$status" -eq 1 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit 1 — the status this script must never use"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif grep -qF "unbound variable" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "aborted on an unguarded expansion"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif ! grep -qF "CR_LOG_DIR" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit 2 but did not name CR_LOG_DIR"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif ! grep -qF "HOME is unset or empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without naming HOME as the cause"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
elif grep -qF "is set but empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "said CR_LOG_DIR is set but empty; it is unset"
  awk '{ print "       | " $0 }' <<<"$out" | head -3
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# CONNECT_CAP above TOTAL_CAP is legal but must SAY the early kill is gone. A
# silent acceptance reads as "bounded on connect" while having no such bound.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" TOTAL_CAP=10 CONNECT_CAP=99 \
  bash "$UNDER_TEST" --base main 2>&1); status=$?
if [ "$status" -eq 0 ] && grep -qF "can never fire" <<<"$out"; then
  passed=$((passed + 1)); printf 'ok   %s\n' "CONNECT_CAP > TOTAL_CAP -> warns it cannot fire"
else
  failed=$((failed + 1)); printf 'FAIL %s (exit %s)\n' "CONNECT_CAP > TOTAL_CAP -> warns" "$status"
fi

# --- THE HEADER'S OWN ARITHMETIC ----------------------------------------------
#
# Rounds 3 and 4 of review on this file produced NOTHING BUT stale summary counts.
# The header said "Six of the twelve had a test that should have caught them",
# every doc said "Seven", and the enumeration those numbers summarize had EIGHT
# items — while every individual defect entry was correct. One round earlier the
# same thing happened to the suite's launch count: it said 16 and was 20.
#
# The remedy applied by hand both times was to anchor the number to something
# checkable. THIS CASE IS THAT REMEDY MADE MECHANICAL, and it is here rather than
# in a doc because a prose rule about keeping counts honest is exactly the kind of
# claim that has failed twice: the file already told its reader, in the paragraph
# above the wrong number, that unanchored counts drift.
#
# It reads the numbered entries as the ONE source of truth for how many defects
# there are, and checks the three prose claims that summarize them:
#   A. the ordinals are contiguous 1..N — a repeated or skipped number is how
#      "twelve entries" stays true while meaning nothing
#   B. "<word> of them." names N
#   C. the same-shape count plus the own-class count sums to N (ten + four)
#   D. every "of the <number>" phrase naming a count of FOUR OR MORE names N
#
# The floor of four in D is measured, not guessed. The header's `of the ...`
# phrases are three naming the defect total and one "of the two caps" — the
# second is two rate limiters, not two defects, and no rule short of parsing
# English separates them. Anything below four is left alone; every defect total
# this file has ever carried has been well above it.
#
# What it deliberately does not check is WHICH defects had a test hole — "defects 3,
# 4, and 7 through 15" is a claim about ten specific entries and no parser settles it.
# What check F below DOES pin is the range's upper end, because that part is not prose:
# it is a digit, and it is the same digit as the entry count.
#
# IT WORKED, AND ON ITS FIRST REAL USE, WHICH IS WHY THIS PARAGRAPH IS PAST TENSE
# NOW. Defect 13 landed the same day this case was written; adding the entry took
# the case red with `13 entries but no "thirteen of them" — the total is stale`,
# before anyone read the diff, and the fix was three summary lines the author had
# just walked past. That message is quoted verbatim HERE and only described in the
# script's own header, deliberately: only `^#` lines of $UNDER_TEST are scanned, so a
# retired total living in that file would be indistinguishable from a live claim once
# the prose is flattened, while the same words in this file are just history. One correction to the prediction that used to be written here:
# it said B and D would BOTH go red, and only B reported. The checks are guarded on
# `[ -z "$hdr_fail" ]` and so short-circuit on the first stale claim — which is the
# right behaviour for a message a human acts on, but it means the case names ONE
# thing per run and a second run is what confirms the rest. Do not read a single
# green as proof that every claim was checked this round; read it as proof that
# nothing was stale when the run finished. A false red here costs one reword; that
# is the cheap direction, and it is why D flags rather than tries to be clever.
label="header's own counts match its enumeration"
hdr_fail=""
# THE PROSE IS FLATTENED FIRST, and that is this case's own fail-open, caught by the
# PR-side review the day after it was written. B, C and D greped the file LINE BY LINE
# while the claims they check are sentences that wrap. Check D — the only one whose
# failure is silent — therefore could not see `of the` at the end of one comment line
# and `six` at the start of the next, and that is not hypothetical: entry 6 read "the
# first of the six that was a genuine SILENT PASS", wrapped exactly there, stale since
# the seventh defect landed, and every run reported green. The one claim D exists to
# catch was present in the file and invisible to it. Measured: `grep -oiE 'of the
# [a-z]+'` line-wise yields no `of the six`; flattened it yields one.
#
# Only comment lines are joined (`^#`), so code strings cannot fabricate a phrase, and
# the leading `#` is stripped so a wrapped sentence reads as one. B and C were blind
# the same way and in the harmless direction — a wrapped total would have read as
# missing and gone red — but they are moved onto the flattened text too, because a
# false red teaches the next author to reword the prose to suit the parser.
hdr_flat=$(grep '^#' "$UNDER_TEST" | sed -e 's/^#[[:space:]]*//' | tr '\n' ' ')
hdr_words=(zero one two three four five six seven eight nine ten eleven twelve
           thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty)
hdr_num_of() {  # number word -> value on stdout, empty if it is not one
  local w i
  w=$(tr '[:upper:]' '[:lower:]' <<<"$1")
  for i in "${!hdr_words[@]}"; do
    [ "${hdr_words[$i]}" = "$w" ] && { printf '%s' "$i"; return 0; }
  done
  return 1
}

# (A) the enumeration itself
# read with a loop rather than `mapfile`, which does not exist in the bash 3.2
# that macOS ships as /bin/bash — the rest of this suite is 3.2-clean and one
# builtin from 4.0 would make it exit 1 before reaching any assertion
#
# SCOPED TWO WAYS, because the first version scanned the whole file for any `# <n>.`
# and would have absorbed a numbered list written anywhere in it — raised by the
# PR-side review on 2026-09-01. The failure mode was loud rather than silent (an extra
# ordinal breaks contiguity, or inflates N and makes B report a stale total), but the
# message would have blamed the enumeration for a line somewhere else entirely, which
# is defect 13's class: right status, false diagnosis. So: `awk` takes the comment
# block that starts at the DEFECTS marker and ends at the first non-comment line, and
# within it an entry must match the right-aligned `#  <n>. CAPS` form the entries use.
# Both narrowings fail CLOSED — a mis-anchored scan yields too few ordinals and check A
# says the enumeration did not read at all, which cannot be mistaken for a pass.
#
# Measured both ways on 2026-09-01 with `#  99. A NUMBERED COMMENT` inserted below the
# block: the scoped scan yields `1..14` and the suite is green, the whole-file scan
# yields `1..14 99` — a 15th ordinal that breaks contiguity and reports it against the
# enumeration, which is the misdiagnosis this scoping exists to prevent.
hdr_ordinals=()
while read -r ord; do
  hdr_ordinals+=("$ord")
done < <(awk '/THE DEFECTS FOUND BY USING IT/{b=1} b && !/^#/{exit} b' "$UNDER_TEST" |
         grep -oE '^#[ ]{2,3}[0-9]{1,2}\. [A-Z]' | grep -oE '[0-9]+')
n_defects=${#hdr_ordinals[@]}
if [ "$n_defects" -lt 2 ]; then
  hdr_fail="parsed $n_defects numbered entries — the enumeration did not read at all"
else
  for i in "${!hdr_ordinals[@]}"; do
    if [ "${hdr_ordinals[$i]}" -ne $((i + 1)) ]; then
      hdr_fail="entry #$((i + 1)) is numbered ${hdr_ordinals[$i]} — ordinals not contiguous"
      break
    fi
  done
fi
total_word=""
[ "$n_defects" -lt "${#hdr_words[@]}" ] && total_word="${hdr_words[$n_defects]}"
[ -z "$total_word" ] && [ -z "$hdr_fail" ] &&
  hdr_fail="$n_defects entries is past this check's number-word table — extend it"

# (B) the stated total
#
# `([^a-z]|$)` rather than `\b`, matching the `(^|[^a-z])` on the other end. `\b` is a
# GNU extension: POSIX ERE does not define it, and where it is unsupported it can be
# read as a literal `b` or as a backspace, either of which makes `... of them.` miss and
# report a stale total that is not stale. Raised by the PR-side review on 2026-09-01 as
# a live macOS bug, and that part did NOT reproduce — measured on this machine against
# BSD grep 2.6.0-FreeBSD (/usr/bin/grep) and ugrep 7.5.0 (the PATH grep), `of them.`
# matched and `of themx` did not under both, so `\b` was honoured by every grep this
# suite can actually reach here. So this is portability hardening rather than a fixed
# defect, adopted because the character class costs nothing, behaves identically on all
# three greps measured, and needs no assumption about which grep is first on PATH.
if [ -z "$hdr_fail" ] && ! grep -qiE "(^|[^a-z])$total_word of them([^a-z]|\$)" <<<"$hdr_flat"; then
  hdr_fail="$n_defects entries but no \"$total_word of them\" — the total is stale"
fi

# (C) same-shape + own-class = total
if [ -z "$hdr_fail" ]; then
  same_w=$(grep -oiE '[a-z]+ are the same' <<<"$hdr_flat" | head -1 | cut -d' ' -f1)
  other_w=$(grep -oiE 'other [a-z]+ are their own class' <<<"$hdr_flat" | head -1 | cut -d' ' -f2)
  if ! same_n=$(hdr_num_of "$same_w") || ! other_n=$(hdr_num_of "$other_w"); then
    hdr_fail="could not read the same-shape/own-class split (\"$same_w\"/\"$other_w\")"
  elif [ $((same_n + other_n)) -ne "$n_defects" ]; then
    hdr_fail="$same_w + $other_w = $((same_n + other_n)), but there are $n_defects entries"
  fi
fi

# (D) every "of the <four or more>" names the total
if [ -z "$hdr_fail" ]; then
  hdr_bad=""
  while read -r w; do
    [ -n "$w" ] || continue
    v=$(hdr_num_of "$w") || continue
    [ "$v" -ge 4 ] || continue
    [ "$w" = "$total_word" ] || hdr_bad="$hdr_bad \"of the $w\""
  done < <(grep -oiE 'of the [a-z]+' <<<"$hdr_flat" | cut -d' ' -f3 |
           tr '[:upper:]' '[:lower:]' | sort -u)
  [ -n "$hdr_bad" ] && hdr_fail="stale count phrase:$hdr_bad — wanted \"of the $total_word\""
fi

# (E) no ABSOLUTE SUITE TOTAL in the header, or in this file's own comments
#
# A through D guard the DEFECT count. The header's OTHER kind of number went unguarded
# until the PR-side review on 2026-09-01 found three of them stale in a single round —
# three mutation results, each written as a true measurement of "N passed, one failed",
# each falsified by the next case somebody added, none of them able to say so. That is
# precisely the defect the four checks above exist for, sitting in the number nobody
# thought to count. The suite's own case total is therefore written down nowhere: this
# harness PRINTS it, which is the one form that cannot go stale.
#
# What survives the ban is the FAILURE count, because that is the information those
# measurements actually carried — "one case and no other" is the discrimination being
# claimed, and "both non-review cases, neither findings case" is a mutation matrix. The
# passed count was only ever the arithmetic complement of the suite size at one instant.
#
# THREE shapes are refused, and the first version of this check saw only one of them.
# It matched a lowercase "N passed, M failed" and the compact "N/M", scored green, and
# was reported as proven — while the SEEN RED list at the top of THIS FILE carried a
# dozen totals in a third shape it could not see: a pass count, then the verdict word
# in CAPITALS, then a parenthesised "of" with the suite size and a date after it.
# `grep -oE` is case-sensitive, and no branch of that alternation described the second
# half at all. The shape has to be described here rather than shown, for the reason the
# last paragraph of this comment gives.
# So the needle was absent from the text under test, which is defect 13's anchor
# vacuity in the check written to ban defect 13's cousin — found by the PR-side review
# one round after this check landed, in the file the check says it scans. `-i` and an
# `of N[,)]` branch are the fix, and the dozen entries were restated as failure counts
# so the ban has something to hold. Banning fewer shapes than exist is a
# half-enumerated ban, which is defect 8's shape, and this is the second time in two
# rounds that the half-enumeration was the defect.
#
# IT SCANS THIS FILE'S COMMENTS TOO, which is the one place the other four checks
# deliberately do not look: a mutation result belongs beside the case it was measured
# on, so this file is where the next stale total will be written — three of the four
# found in the round that added this check were in a comment rather than in the header,
# and every one of the dozen the check itself missed was in this file. The stated cost
# is the flattened-header cost one file over: a comment cannot QUOTE a retired total in
# order to describe it, only describe it, which is why every mention of one in this
# comment is spelled out in words. That cost is not theoretical — the first draft of
# this comment quoted three retired totals, and the second quoted the very shape the
# fix had just been written to catch. A false red costs one reword; a stale total costs
# a reader believing a number.
#
# AND IT SCANS ALL FOUR GUARD SCRIPTS, not the bounded pair, which was the THIRD
# half-enumeration in three rounds and was caught the same way as the other two — by a
# reviewer, on the round that fixed the previous one. Scanning `$UNDER_TEST` and `$0`
# left the preflight script and its suite outside a ban whose whole argument is that a
# partial ban is defect 8's shape, and there were totals sitting in the preflight suite
# while this check reported the class eliminated. The list is now every guard script in
# `scripts/`, which is the enumeration the argument requires. One pattern in one place
# rather than a copy of it in the preflight suite: two patterns can drift, and a drifted
# ban is a ban with a hole in it. A missing file here reads as a clean scan, so the
# check refuses outright if any of the four is unreadable.
# `$HERE`, not `dirname "$0"`. The two disagree the moment the suite is invoked from
# another directory or through a symlink, and $HERE is the absolute form this script
# already computed once at the top for exactly that reason. With the relative form the
# four scripts are unreadable, the refusal fires, and it reports a stale-total scan
# problem when the actual problem is the invocation path — the WRONG-DIAGNOSIS class
# that defect 13 is about, in the check written against defect 13's cousin. Raised by
# the PR-side review 2026-09-01, and it never showed locally because every run of this
# suite so far has been `./scripts/test-bounded-vendor-review.sh` from the repo root.
if [ -z "$hdr_fail" ]; then
  hdr_scan_dir="$HERE"
  hdr_scan_files=""
  for f in bounded-vendor-review.sh test-bounded-vendor-review.sh \
           preflight-vendor-review.sh test-preflight-vendor-review.sh; do
    if [ -r "$hdr_scan_dir/$f" ]; then
      hdr_scan_files="$hdr_scan_files $hdr_scan_dir/$f"
    else
      hdr_fail="cannot read $hdr_scan_dir/$f, so the absolute-total scan would report a clean pass over a file it never opened"
      break
    fi
  done
  # shellcheck disable=SC2086  # deliberate word splitting: the list is script names we built
  if [ -z "$hdr_fail" ]; then
    hdr_tot=$(grep -h '^#' $hdr_scan_files |
              grep -oiE '[0-9]{1,2} passed, [0-9]{1,2} failed|of [0-9]{1,2}[,)]|[0-9]{1,2}/[0-9]{1,2}' |
              head -1)
    [ -n "$hdr_tot" ] &&
      hdr_fail="an absolute suite total (\"$hdr_tot\") is stated in a guard script comment — it goes stale on the next added case; state the failure count instead"
  fi
fi

# (F) every quoted "7 through <n>" test-hole range ends at the entry count
#
# THE PR-SIDE REVIEW FOUND THIS ONE TWICE IN A SINGLE ROUND — the range quoted here and
# the range quoted in the review-plan-v2 skill, both still ending at fourteen the day
# after the fifteenth entry landed. A and B had already gone green on that same run,
# because the range is a DIGIT inside a sentence and nothing above was looking at it.
# The reason it went unguarded is written three paragraphs up in this file's own words:
# the test-hole claim is prose, a parser for it would break more often than the claim,
# so the whole phrase was left alone. That was true of WHICH defects the range names and
# false of WHERE IT ENDS, which is the same mistake as a stated limit that needs no new
# evidence to close — the fourteenth defect's lesson, arriving in the check written to
# hold the counts this file makes about itself.
#
# Scoped to the four guard scripts like (E), and for the same argument: a ban that skips
# a file is defect 8's half-enumeration. The doc-side copies of this sentence live in two
# other repos and are outside anything this suite can read, so they are NOT covered here
# and that is stated rather than implied — the promotion step is what keeps them honest,
# and it is a human step. Fails CLOSED in the one direction that matters: a range that
# cannot be found at all is not silently a pass, because the phrase is quoted in this
# very comment, so zero matches means the scan itself broke.
if [ -z "$hdr_fail" ]; then
  # shellcheck disable=SC2086  # deliberate word splitting: the same list (E) built
  hdr_ranges=$(grep -h '^#' $hdr_scan_files | grep -oE '7 through [0-9]{1,2}' |
               grep -oE '[0-9]{1,2}$' | sort -u)
  if [ -z "$hdr_ranges" ]; then
    hdr_fail="found no \"7 through <n>\" range in the four guard scripts, but this file quotes one — the scan broke rather than passed"
  else
    while read -r r; do
      [ -n "$r" ] || continue
      [ "$r" = "$n_defects" ] ||
        hdr_fail="a test-hole range ends at $r but the enumeration has $n_defects entries"
    done <<<"$hdr_ranges"
  fi
fi

if [ -n "$hdr_fail" ]; then
  failed=$((failed + 1)); printf 'FAIL %-56s %s\n' "$label" "$hdr_fail"
else
  passed=$((passed + 1)); printf 'ok   %s (%s entries)\n' "$label" "$n_defects"
fi

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
