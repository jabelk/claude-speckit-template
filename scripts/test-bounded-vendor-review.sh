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
#
# BOTH LOGS ARE WRITTEN BEFORE THE FIRST SLEEP, and that is a fix rather than a
# simplification. This fixture wrote the second one after `sleep 1`, to model the
# concurrent gate's log arriving partway through — the real offset was 79s. That was
# harmless against the old CONNECT_CAP of 120s and became a 1s margin against a 2s
# cap when the caps were shrunk to make the suite fast, so under load the refusal
# arrived before the second log existed and the case failed intermittently: seen
# twice in six runs on 2026-09-01. The delay was never load-bearing — `new_logs` is
# a set difference over the directory listing taken before launch, not an mtime
# comparison, so a log written at t=0 and one written at t=1 are equally new. An
# intermittent case is this file's own disease one layer out: a green run that
# proves nothing, and no assertion in it looks wrong.
mkdir -p "$CR_LOG_DIR"
one="$CR_LOG_DIR/aaa-first-$$.log"
two="$CR_LOG_DIR/bbb-second-$$.log"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$one"
echo '{"message":"Establishing WebSocket connection to URL"}' >>"$two"
printf 'Connecting to CodeRabbit... 1s elapsed\r'
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
# max_secs, when set, asserts the case finished FASTER than that.
#
# This said max_secs is what distinguishes the early kill from TOTAL_CAP catching the
# same fake later. MEASURED 2026-09-01 while halving the caps, and that is not what it
# does: the two paths print DIFFERENT sentences, so `want_text` already separates them,
# and every mutation that moves the connect kill to TOTAL_CAP is caught by the wording
# before the clock is ever consulted (two mutations tried, four and three reds, all on
# the message). What max_secs actually catches is a bound that fires at the right cap
# and then takes too long to finish — `sleep 2` to `sleep 6` in the kill escalation is
# red on five cases, every one of them on the clock with the message intact. Worth
# correcting rather than reusing, because a comment that credits an assertion with the
# wrong job is how the next reader deletes the one that was doing it.
#
# TOTAL_CAP_OVERRIDE / CONNECT_CAP_OVERRIDE / POLL_OVERRIDE let a single case
# retune the wrapper without disturbing the defaults every other case shares.
# `POLL_OVERRIDE` exists for the defect-5 case: a poll interval LONGER than a cap
# is the whole condition under test there, and it cannot be expressed while the
# harness pins `POLL=1`.
#
# THE DEFAULTS WERE 12/4 UNTIL 2026-09-01 AND ARE NOW 6/2, because the fakes hang for
# real and the caps are therefore the suite's entire wall clock. Measured per case
# before the change: six cases at 6.2s (CONNECT_CAP=4 plus ~2s of process overhead),
# six at ~13.5s (TOTAL_CAP=12), everything else about 1s, 132.5s total at 2% CPU.
# Nothing in any fake depends on real elapsed time — every one prints its whole
# progress stream immediately and then `sleep 600`, and the `Ns elapsed` text in those
# lines is a transcribed string, not a duration — so halving the caps changes only how
# long the wait loop runs. What it must NOT change is the anti-vacuity margin: an early
# kill lands at about 4s and TOTAL_CAP at about 8s, so `max_secs 6` still separates
# them by 2s in both directions, which is why 6/2 and not 4/2.
#
# VENDOR_ROUND_DIR IS PER-CASE, and it has to be. The round cap counts by working
# directory and branch, and every case here runs in this repo on one branch, so a
# shared counter would exhaust ROUND_CAP three cases in and turn the whole rest of the
# suite into exit 4. Per-case isolation is also the honest arrangement rather than a
# workaround: a counter is a stateful thing across runs, so the cases that exercise it
# are the ones below that deliberately point several runs at ONE directory.

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
    VENDOR_ROUND_DIR="$dir/rounds" \
    TOTAL_CAP="${TOTAL_CAP_OVERRIDE:-6}" \
    CONNECT_CAP="${CONNECT_CAP_OVERRIDE:-2}" \
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

echo "== bounded-vendor-review fixtures (TOTAL_CAP=6 CONNECT_CAP=2) =="

# The case this script exists for. Exit 3, and FAST — under TOTAL_CAP, which is
# what proves the early connect kill fired rather than the wall-clock backstop.
case_run "stuck at the WebSocket connect -> exit 3, early" \
  3 "never got past its connect phase" 6 fake_hang_at_connect

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
  3 "produced no verdict in 6s" "" fake_healthy_but_slow

# DEFECT 14. The same review, with its connect-phase progress line on STDERR and the
# later phases on stdout. `cat "$out" "$err"` orders by file, so the stale line won and
# a connected review was refused as stuck. Asserted the same way as the case above —
# both paths exit 3, so the sentence is the whole discrimination — plus the refusal it
# must NOT print, because "produced no verdict" and "never got past its connect phase"
# are the two ways this run can end and only one of them is true of it.
case_run "connect line on stderr must not outrank a later one on stdout" \
  3 "produced no verdict in 6s" "" fake_slow_with_connect_line_on_stderr \
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
  3 "never got past its connect phase" 6 fake_hang_connect_line_on_stderr_only

# DEFECT 1, still stuck, still early-killed. Logs are out of the decision now, so
# the time bound has stopped being about them; what is load-bearing here is the
# next case.
case_run "two logs, both stuck -> early kill still fires" \
  3 "never got past its connect phase" 6 fake_hang_two_logs

# What defect 1's fix is FOR, now that logs only appear in the refusal: a run that
# wrote two logs must have both named, because sending the reader to one of two
# files is how you conclude the wrong thing about which session hung.
case_run "two logs -> the refusal names the second one too" \
  3 "bbb-second" "" fake_hang_two_logs

# Fail closed with nothing parseable to read. TOTAL_CAP alone must still stop it.
case_run "no progress line -> TOTAL_CAP still stops it" \
  3 "produced no verdict in 6s" "" fake_hang_no_progress

# DEFECT 5: NEVER SLEEP PAST A DEADLINE. The wait loop slept the full `POLL`
# before checking either cap, and `POLL` is validated as a positive integer and
# never against the caps — so `TOTAL_CAP=900 POLL=3600` left a hung reviewer alive
# for about an hour while the script reported a 900s bound. The fifth instance in
# one file of an advertised bound that was not the bound.
#
# `POLL=40` against `TOTAL_CAP=6` states the condition in the smallest possible
# form. `fake_hang_no_progress` on purpose: its verdict is `unknown`, so the early
# kill declines and TOTAL_CAP is the ONLY thing that can stop the run, which is
# what makes the time bound here a measurement of TOTAL_CAP rather than of the
# connect kill happening to fire first.
#
# The 10s bound is the load-bearing assertion, not the exit code. Against the bare
# `sleep "$POLL"` this case exits 3 with the right wording after ~40s and passes
# every check except that one. Seen red exactly there.
POLL_OVERRIDE=40 case_run "POLL longer than TOTAL_CAP -> still stops at TOTAL_CAP" \
  3 "produced no verdict in 6s" 10 fake_hang_no_progress

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
  3 "never got past its connect phase" 6 fake_agent_hang

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
PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" TOTAL_CAP=6 CONNECT_CAP=2 POLL=1 \
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
PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" TOTAL_CAP=6 CONNECT_CAP=2 POLL=1 \
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

# --- DEFECT 16: THE REFUSAL'S OWN DISPLAY, WHICH NO ASSERTION MODELLED --------
#
# Defect 14 removed `cat "$out" "$err"` from the VERDICT and left it in the block the
# refusal prints for the operator, directly above a sentence telling them to read
# "its last phase above" — and both skills tell the operator to overrule an exit 3 by
# reading that block. So the reader with no way around it got by-file ordering: one
# stale connect-phase line in $err printed after every later-phase line in $out.
#
# The twelfth test hole, and the one shape not on the list yet: A READER NO ASSERTION
# MODELLED. Nothing was wrong in a fixture and nothing was merged in the harness —
# every case asserts on the wrapper's own MESSAGES (a status, a sentence, a stream),
# and this block exists to be interpreted by a human, so it sat outside what the
# suite treated as output. The fixture needed already existed: defect 14's, whose
# stdout reaches `Writing review comments` while its stderr holds a connect line.
#
# The assertion is on ORDER WITHIN A SECTION, which `case_run`'s substring match
# cannot express — under `cat` both lines are present and merely in the wrong order,
# so every "output contains X" test is green. Against the concatenating version the
# labelled sections do not exist at all and the first assertion reports that.
n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_slow_with_connect_line_on_stderr "$dir/bin"
PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" TOTAL_CAP=6 CONNECT_CAP=2 POLL=1 \
  bash "$UNDER_TEST" --base main >"$dir/stdout" 2>"$dir/stderr"
status=$?
label="the refusal's display is sectioned, so its last phase is readable"
why=""
[ "$status" -eq 3 ] || why="exit $status, wanted 3"
if [ -z "$why" ]; then
  # `tr` because the fake writes progress as \r redraws, exactly as the CLI does.
  stdout_section=$(tr '\r' '\n' <"$dir/stderr" |
    awk '/^--- reviewer stdout before the kill/ { f = 1; next }
         /^--- reviewer stderr before the kill/ { f = 0 }
         f')
  last_line=$(tail -n 1 <<<"$stdout_section")
  if [ -z "$stdout_section" ]; then
    why="the refusal has no labelled reviewer-stdout section, so the reader cannot tell which stream a phase line came from — this is the by-file \`cat\`"
  elif ! grep -qF "Writing review comments" <<<"$last_line"; then
    why="the stdout section's LAST line is not the run's last phase — got '$last_line'"
  fi
fi
# And not fixed by discarding stderr, which satisfies everything above (defect 10).
if [ -z "$why" ] && ! grep -qF "Connecting to CodeRabbit" "$dir/stderr"; then
  why="the reviewer's stderr was dropped from the display entirely"
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

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" \
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

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" \
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
# is a seventh shape of test blindness to go with the six before it in the defect log: not an absent
# double, an invented signal, a merged harness, a cooperating process, or a boundary no
# fixture landed on, but a PARAMETER every case happened to share, which collapsed the
# very interval under test. Raised by the PR-side review on 2026-09-01.

n=$((passed + failed + 1))
dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_with_grandchild "$dir/bin"
cpid="$dir/child.pid"; gpid="$dir/grandchild.pid"

PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" \
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
out=$(PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" GIT_DIR=/tmp/somewhere/.git \
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
  out=$(env "$v=" PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" \
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
out=$(PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" VENDOR_ROUND_DIR="$dir/rounds" TOTAL_CAP=10 CONNECT_CAP=99 \
  bash "$UNDER_TEST" --base main 2>&1); status=$?
if [ "$status" -eq 0 ] && grep -qF "can never fire" <<<"$out"; then
  passed=$((passed + 1)); printf 'ok   %s\n' "CONNECT_CAP > TOTAL_CAP -> warns it cannot fire"
else
  failed=$((failed + 1)); printf 'FAIL %s (exit %s)\n' "CONNECT_CAP > TOTAL_CAP -> warns" "$status"
fi

echo
echo "== the round cap =="

# The other bounds here bound ONE run. This one bounds the loop, so every case below
# points SEVERAL runs at one state directory — which is why `case_run` cannot host
# them: it gives each case its own, deliberately, so that one exhausted budget cannot
# take the rest of the suite down with it.
#
# SEEN RED, 2026-09-01, one mutation of the wrapper per case, each on that case and no
# other unless noted — because a green test proves nothing until it has been watched to
# fail, and this suite has shipped four cases that could not:
#
#   the cap refuses with `exit 3`      -> the cap case, on the status
#   claim without `set -C`             -> the race case, at 6 reviews under ROUND_CAP=1
#   never claim a slot at all          -> the cap case AND the reset case (never counts)
#   keep the slot unconditionally      -> the killed-review case, at exit 4
#   delete the pre-launch write probe  -> the read-only-dir case, at exit 0
#   ROUND_RESET deletes nothing        -> the reset case, at exit 4
#   reset without the liveness check   -> the live-holder case, at exit 0
#   refuse EVERY reset                 -> the live-holder case, on `force`, AND the
#                                         plain reset case (see the overlap below)
#   release by path, not by token      -> the ownership case, slot 1 gone
#   drop VENDOR_ROUND_DIR from the
#     empty-value loop                 -> the second-default case, on the wording
#
# The corrupt-count mutation that used to sit in this list is gone with the counter it
# described: admission parses no number now, so there is no value a stray byte can
# corrupt. What replaced it is the stray-file case, which asks the question that
# survives the change — whether anything in that directory other than a claimed slot
# can be mistaken for state.
#
# One overlap stated rather than glossed: the file-as-state-dir case and the
# read-only-dir case both end in a refusal naming VENDOR_ROUND_DIR, so removing the
# `mkdir -p` refusal alone leaves the write probe to catch it and neither case goes
# red. They pin the two SENTENCES, not two independent mechanisms.
#
# A second overlap, measured rather than predicted: "refuse EVERY reset" is red on the
# live-holder case AND on the plain reset case, because a reset that never proceeds
# fails the one that expects it to. That is honest rather than untidy — refuse-all is
# the trivially-satisfying wrong fix for defect 18, and it is caught twice.
#
# `env "$@"` first so a case can add ROUND_CAP or ROUND_RESET without a second helper.
round_run() {
  local rounds="$1" bin="$2" logs="$3"; shift 3
  env "$@" PATH="$bin:$PATH" CR_LOG_DIR="$logs" VENDOR_ROUND_DIR="$rounds" \
    TOTAL_CAP=6 CONNECT_CAP=2 POLL=1 bash "$UNDER_TEST" --base main 2>&1
}

# THE CAP ITSELF. Three reviews, then a refusal — and the refusal must be exit 4 and
# not 3, because 3 means "the vendor or the session broke, retry later" and this means
# "another round is the wrong move, go and talk to someone". A caller that cannot tell
# them apart will retry the one thing it must not retry.
#
# The last assertion is the load-bearing one: `reviewing 3 of 3 changed file(s)` is a
# line only the FAKE emits, so its absence is the only evidence in reach that the
# fourth run never launched a reviewer. A cap that refuses after sending the diff has
# already spent the thing it exists to save.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
warmup_ok=1
for i in 1 2 3; do
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
  [ "$status" -eq 0 ] || { warmup_ok=0; break; }
  grep -qF "round $i of 3" <<<"$out" || { warmup_ok=0; break; }
done
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
label="4th review on one branch -> exit 4, nothing launched"
if [ "$warmup_ok" -ne 1 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a warmup round did not exit 0 and count itself"
elif [ "$status" -ne 4 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 4"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "ROUND_CAP=3" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without naming the cap it enforced"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "the reviewer ran anyway — the diff was sent"
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi
cap_reached_dir="$dir/rounds"

# A REFUSED RUN IS NOT A ROUND, and this is the case that stops the obvious wrong
# implementation. Counting at launch is one line shorter and lets a vendor outage
# spend a branch's entire budget on reviews it never received — the cap would then
# refuse a branch that has had NO review, which is this file's own oldest defect
# pointed at the new bound. ROUND_CAP=1 so a single miscount is enough to see.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_at_connect "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); first=$?
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); status=$?
label="a killed review does not spend a round"
if [ "$first" -ne 3 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "first run exited $first, wanted 3 (fixture)"
elif [ "$status" -ne 3 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "second run exited $status, wanted 3 — the outage was counted"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# ROUND_RESET is the escape hatch, and it must resume counting from 1 rather than
# merely stepping past the refusal once. A reset that left the count at 3 would give
# unlimited rounds to anyone who set it, which is an off switch by another name.
#
# Its own bin, pointed at the counter the cap case left exhausted. The first draft
# borrowed case 1's bin directory to save four lines and got case 1's HANG fake, so it
# failed at exit 3 on a case about exit 0 — a fixture reused for its path rather than
# its behaviour, which is the cheapest way to test something other than the subject.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$cap_reached_dir" "$dir/bin" "$dir/logs" ROUND_RESET=1); status=$?
label="ROUND_RESET=1 -> proceeds and counts from 1 again"
if [ "$status" -ne 0 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 0"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "reset to 0" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "reset silently; an unannounced reset reads like a cap"
elif ! grep -qF "round 1 of 3" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "did not resume counting at 1"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# AND THAT ESCAPE HATCH BREACHED THE CAP IT WAS CLEARING — defect 18, found by the
# vendor leg on the round that shipped defect 17's fix, inside that fix. A reset
# deleted slots without asking who held them, so: A holds 1 and is reviewing, a reset
# frees 1, B claims 1 and reviews, A finishes with no verdict and its release deletes
# what is now B's file, C claims 1 while B is still going. Three reviews under a cap
# of one, and the operator reached it by clearing a count.
#
# THE HOLDER IS THIS SUITE. `$$` is a pid that is definitely alive and definitely not
# a wrapper, which is the point: a fixture that backgrounded a real wrapper to hold
# the slot would make the case depend on that wrapper's timing, and a fixture whose
# liveness is a race can pass by arriving late. The slot is written by hand, in
# production's own format, after a real run has created the directory.
#
# The `force` half is asserted in the same case because an escape hatch nobody has
# opened is not an escape hatch — and because refuse-while-live is trivially
# satisfiable by refusing every reset, which this catches and the case above does not
# (that one resets a directory whose holders have all exited).
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="ROUND_RESET refuses while a live pid holds a round"
if [ "$status" -ne 0 ] || [ -z "$statedir" ] || [ ! -e "$statedir/1" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no claimed slot 1 (fixture)"
else
  printf 'pid %d token harness\n' "$$" >"$statedir/1"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=1); status=$?
  forced=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=force); fstatus=$?
  if [ "$status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2 — it cleared a live claim"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "still held" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused without saying a round was held"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "pid $$" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "did not name the holder, so nobody can check it"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused the reset and reviewed anyway"
  elif [ "$fstatus" -ne 0 ] || ! grep -qF "reset to 0" <<<"$forced"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "ROUND_RESET=force exit $fstatus — the door does not open"
    awk '{ print "       | " $0 }' <<<"$forced" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND A HOLDER WE MAY NOT SIGNAL IS STILL A HOLDER. The case above holds the slot with
# `$$`, which this suite owns, so `kill -0` answers it directly and the reset refuses.
# That left the reachable half untested: a pid owned by ANOTHER USER answers `kill -0`
# with EPERM, which is exit 1 — the same status as "no such process" — so the holder
# read as dead and the reset proceeded, breaching the cap it was clearing. The comment
# in the script named that case a round before the code handled it.
#
# THE HOLDER IS PID 1. Deterministic, present on every Unix, alive for the whole run,
# and owned by root while this suite is not — which is the entire condition under test
# and cannot be constructed from a process the suite owns. Measured 2026-09-02 on this
# machine: `kill -0 1` exits 1 with "operation not permitted", `ps -p 1` exits 0.
# Skipped rather than failed when the suite runs AS root, because there EPERM does not
# arise and a green result would be vacuous — the case would be asserting that a live
# pid reads as live, which the case above already covers.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="ROUND_RESET refuses for a holder it may not signal (EPERM)"
if kill -0 1 2>/dev/null; then
  # Reported as a SKIP and NOT counted as a pass, matching the read-only-state-dir case
  # below. Counting it was the plainer form of the same error this file keeps recording: a
  # check that did not run reading as one that ran and succeeded, and the suite's own total
  # is the number this repo's summary claims are green.
  printf 'SKIP %-56s %s\n' "$label" "running as root; EPERM is unreachable"
elif [ "$status" -ne 0 ] || [ -z "$statedir" ] || [ ! -e "$statedir/1" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no claimed slot 1 (fixture)"
else
  printf 'pid 1 token harness\n' >"$statedir/1"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=1); status=$?
  if [ "$status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2 — EPERM read as dead"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "pid 1" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused without naming pid 1 as the holder"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif grep -qF "reset to 0" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "said it refused and cleared the slots anyway"
  elif [ ! -e "$statedir/1" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "slot 1 was deleted despite the refusal"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND THE SCAN AND THE DELETE ARE NOT ONE OPERATION. The two cases above both hold a
# slot for the whole reset, so the scan sees the holder and refuses. Neither lands in the
# gap BETWEEN the scan and the delete, which is where a wrapper claims a slot the reset
# is about to remove — after which a third wrapper takes that same name while the second
# is still reviewing. The scan is honest, the delete is honest, and the gap is the defect.
#
# THE FIXTURE IS THE MARKER, NOT THE RACE. Landing a real wrapper inside a window this
# narrow is a coin flip, and a fixture whose liveness is a race passes by arriving late —
# the reason the case above holds its slot by hand rather than by timing. So this asserts
# the mechanism that closes the gap instead of trying to hit it: with `.resetting` present
# and owned by a live pid, a claim must be REFUSED (exit 2, nothing counted, no review),
# and with `.resetting` owned by a dead pid it must be taken over rather than obeyed —
# because a reset that dies mid-way would otherwise wedge every future run, which is the
# failure this branch is named after. Both directions, because refusing on sight satisfies
# the first assertion and is the trivially-wrong fix.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="a claim mid-reset is refused, and a dead marker is taken over"
if [ "$status" -ne 0 ] || [ -z "$statedir" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no state dir (fixture)"
else
  # Live marker: this suite is the holder, for the same reason as the case above.
  printf 'pid %d\n' "$$" >"$statedir/.resetting"
  live_out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); live_status=$?
  # Dead marker: a pid that cannot exist, so the takeover path is the only one left.
  printf 'pid 999999\n' >"$statedir/.resetting"
  dead_out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); dead_status=$?
  if [ "$live_status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $live_status, wanted 2 — claimed during a reset"
    awk '{ print "       | " $0 }' <<<"$live_out" | head -5
  elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$live_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused and reviewed anyway"
  elif ! grep -qF "ROUND_RESET is in progress" <<<"$live_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused without saying a reset was in flight"
    awk '{ print "       | " $0 }' <<<"$live_out" | head -5
  elif [ "$dead_status" -ne 0 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $dead_status on a DEAD marker — a wedge, not a gate"
    awk '{ print "       | " $0 }' <<<"$dead_out" | head -5
  elif ! grep -qF "stale reset marker" <<<"$dead_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "took the marker over without saying so"
    awk '{ print "       | " $0 }' <<<"$dead_out" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND THE RELEASE IS THE SAME BREACH FROM THE OTHER END. `rm -f "$round_claim"`
# deletes whatever is at that name at exit, which after a `ROUND_RESET=force` is
# another wrapper's live claim — so the refusal above closes the reset half and this
# closes the release half. One without the other leaves the hole reachable.
#
# The sequence is deterministic rather than raced: a hanging wrapper claims slot 1,
# the suite waits for the file to exist and then overwrites it with a foreign token,
# and the wrapper is killed at CONNECT_CAP with no verdict — which is exactly the
# path that releases. What survives the exit is the assertion.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_hang_at_connect "$dir/bin"
label="a release deletes its own slot, not whatever holds that name"
( round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 >"$dir/hang.log" 2>&1 ) &
hang_pid=$!
statedir=''
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
  [ -n "$statedir" ] && [ -e "$statedir/1" ] && break
  sleep 0.1
done
if [ -z "$statedir" ] || [ ! -e "$statedir/1" ]; then
  wait "$hang_pid" 2>/dev/null || true
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "the hanging wrapper never claimed a slot (fixture)"
else
  printf 'pid %d token intruder\n' "$$" >"$statedir/1"
  wait "$hang_pid" 2>/dev/null || true
  if [ ! -e "$statedir/1" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "deleted a slot it no longer owned"
  elif ! grep -qF 'token intruder' "$statedir/1"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the slot survived but its holder did not"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# ONLY `1` AND `force` MAY CLEAR A BRANCH'S SLOTS, AND THE VALUE THAT PROVES IT IS `0`.
# Until this round every non-empty ROUND_RESET was a reset request, so `ROUND_RESET=0` —
# which reads as "off" to whoever writes it, and is how every other switch on this machine
# spells "off" — deleted the branch's claims and let the cap start over. So did `=yes` and
# every typo. That is this file's own recurring defect once more, in the one place where
# guessing DELETES state rather than merely mis-reporting it.
#
# Three probes, because each of the two available wrong fixes passes a smaller case. The
# anchor is the SENTENCE and never the token (defect 13): the accepting version prints
# `ROUND_RESET set — round count ... reset to 0`, which contains `ROUND_RESET` as readily
# as the refusal does, so `is not a reset request` is what is greped and the surviving slot
# file is what is checked. And `ROUND_RESET=` must stay OFF rather than join the caps'
# set-but-empty refusal — an empty cap silently drops a bound the operator tried to set,
# while an empty reset does what the operator's `=` reads as. That asymmetry is argued in
# the script and was untested until now, so "refuse everything that is not 1 or force" is
# red here instead of green.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="ROUND_RESET=0 is refused, and an empty one is still off"
if [ "$status" -ne 0 ] || [ -z "$statedir" ] || [ ! -e "$statedir/1" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no claimed slot 1 (fixture)"
else
  zero_out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=0); zero_status=$?
  zero_kept=0; [ -e "$statedir/1" ] && zero_kept=1
  typo_out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=yes); typo_status=$?
  # ROUND_CAP=2 for the empty probe so there is a free slot to claim: slot 1 is still
  # held by the warmup's verdict, and reclaiming a dead holder's slot is exactly what
  # ROUND_RESET exists for, so a cap of 1 here would exit 4 for the right reason and
  # tell us nothing about the empty value.
  off_out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=2 ROUND_RESET=); off_status=$?
  if [ "$zero_status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "ROUND_RESET=0 exit $zero_status, wanted 2"
    awk '{ print "       | " $0 }' <<<"$zero_out" | head -5
  elif ! grep -qF "is not a reset request" <<<"$zero_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused without saying the value is not a reset"
    awk '{ print "       | " $0 }' <<<"$zero_out" | head -5
  elif grep -qF "reset to 0" <<<"$zero_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "said it refused and cleared the branch anyway"
  elif [ "$zero_kept" -ne 1 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "ROUND_RESET=0 deleted a claimed slot"
  elif [ "$typo_status" -ne 2 ] || ! grep -qF "is not a reset request" <<<"$typo_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "ROUND_RESET=yes exit $typo_status — a typo resets"
    awk '{ print "       | " $0 }' <<<"$typo_out" | head -5
  elif [ "$off_status" -ne 0 ] || ! grep -qF "round 2 of 2" <<<"$off_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "ROUND_RESET= exit $off_status — empty is not off"
    awk '{ print "       | " $0 }' <<<"$off_out" | head -5
  elif ! grep -qF "reviewing 3 of 3 changed file(s)" <<<"$off_out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "an empty reset was counted but never reviewed"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND TAKING OVER A STALE MARKER IS NOT AN OVERWRITE. The first repair of defect 20 wrote
# straight over a marker it had judged stale, so two resets that both judged it stale both
# proceeded — and then the first one's delete removed the second one's marker and left it
# scanning with the claim loop open, which is defect 20 reached through its own fix. The
# remove-and-re-create is exclusive, and the case is that the re-create can be LOST.
#
# Deterministic rather than raced: a no-op `rm` first on PATH makes the remove half do
# nothing, so the exclusive create must fail on a file that is still there — the same
# state a racing reset would leave, arrived at by arithmetic instead of by timing. The
# marker's pid cannot exist, so the takeover path is the only one reachable; `cannot be
# replaced` is greped rather than `stale`, because the SUCCESS note says "took over a
# stale reset marker" and would satisfy the looser anchor.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="a lost re-create of the reset marker refuses, not overwrites"
if [ "$status" -ne 0 ] || [ -z "$statedir" ] || [ ! -e "$statedir/1" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no claimed slot 1 (fixture)"
else
  printf 'pid 999999 token someone-else\n' >"$statedir/.resetting"
  printf '#!/bin/sh\nexit 0\n' >"$dir/bin/rm"
  chmod +x "$dir/bin/rm"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 ROUND_RESET=1); status=$?
  if [ "$status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2 — it overwrote the marker"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "cannot be replaced" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused without saying the marker could not be taken"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif grep -qF "reset to 0" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "said it refused and cleared the branch anyway"
  # NO SLOT-SURVIVAL ASSERTION HERE, and its absence is deliberate rather than an oversight.
  # The no-op `rm` above is first on PATH for the whole wrapper run, so `[ -e "$statedir/1" ]`
  # cannot go red whatever the script does — the fixture that makes this case deterministic
  # has also removed that assertion's ability to fail, which is precisely the vacuity shape
  # this suite hunts everywhere else. The reset block's own cases assert slot survival with a
  # real `rm` on PATH; the only honest observables here are the status, the wording, and the
  # absence of a review.
  elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused the reset and reviewed anyway"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND THE END OF A RESET DROPS ITS OWN MARKER, NOT WHATEVER HOLDS THAT NAME. This is the
# release case's ownership test one file over, and it is what makes the two syscalls
# between the create and the trap harmless rather than merely narrow: if a second reset
# does replace this marker, ITS marker is the one standing, so SOME marker exists for the
# union of both resets and the claim loop stays shut for as long as either runs. A path
# delete breaks that invariant; an ownership delete cannot.
#
# Entered deterministically rather than raced, by shimming the one command the reset runs
# between its create and its drop: `seq`, on the slot scan. The shim plants a marker owned
# by this suite — LIVE, so the claim loop below must refuse rather than tidy it away as
# stale, which is the observable that separates the two implementations.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="the reset drops its own marker, not a racing reset's"
if [ "$status" -ne 0 ] || [ -z "$statedir" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no state dir (fixture)"
else
  : >"$statedir/.resetting.armed"
  cat >"$dir/bin/seq" <<'EOF'
#!/bin/sh
# Fires once, on the reset's slot scan. `seq` is emulated rather than exec'd because this
# directory is first on PATH, so resolving the real one from here would find this file.
if [ -n "${HARNESS_GATE:-}" ] && [ -f "$HARNESS_GATE.armed" ]; then
  rm -f "$HARNESS_GATE.armed"
  printf 'pid %d token intruder\n' "$HARNESS_PID" >"$HARNESS_GATE"
fi
i=$1
while [ "$i" -le "$2" ]; do echo "$i"; i=$((i + 1)); done
EOF
  chmod +x "$dir/bin/seq"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3 ROUND_RESET=1 \
    HARNESS_GATE="$statedir/.resetting" HARNESS_PID=$$); status=$?
  if [ -f "$statedir/.resetting.armed" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the seq shim never fired, so no marker was planted (fixture)"
  elif ! grep -qF "reset to 0" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the reset itself did not run (fixture)"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif [ ! -e "$statedir/.resetting" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "deleted a marker it did not own"
  elif ! grep -qF 'token intruder' "$statedir/.resetting"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the marker survived but its owner did not"
  elif [ "$status" -ne 2 ] || ! grep -qF "ROUND_RESET is in progress" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status — claimed a round with a live marker up"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND THE CLAIM SIDE MUST NOT TOUCH THE MARKER AT ALL. The two cases above are the reset
# side of this argument; this is the side that READS the marker, and it kept a delete for
# two rounds after the reset side gave one up — first by path, then guarded by a re-read,
# which was narrower and not closed, because no gap between the last read and an `rm` can
# be made zero in POSIX shell. So the mechanism under test is no longer "delete the right
# one", it is "do not delete", and this case asserts the half that a verdict still rests
# on: a marker that changed hands between the liveness test and the re-read means a reset
# is live NOW, and the claim must be refused rather than made on an expired verdict.
#
# Deterministic rather than raced, by shimming the one command that runs in that gap: the
# stale pid sends `pid_is_live` past `kill -0` to `ps -p`, so the shim fires there, plants a
# marker owned by a LIVE pid, and then answers "gone" so the stale verdict still stands.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="a stale marker that changes hands before the re-read refuses"
if [ "$status" -ne 0 ] || [ -z "$statedir" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no state dir (fixture)"
else
  printf 'pid 999999 token stale-one\n' >"$statedir/.resetting"
  : >"$statedir/.resetting.armed"
  cat >"$dir/bin/ps" <<'EOF'
#!/bin/sh
# Fires once, inside pid_is_live's second opinion — i.e. after the marker has been read and
# before the verdict is acted on. Then answers 1, the only status that means "gone", so the
# wrapper's stale verdict is unchanged and the expiry of it is the only thing under test.
if [ -n "${HARNESS_GATE:-}" ] && [ -f "$HARNESS_GATE.armed" ]; then
  rm -f "$HARNESS_GATE.armed"
  printf 'pid %d token intruder\n' "$HARNESS_PID" >"$HARNESS_GATE"
  exit 1
fi
for real in /bin/ps /usr/bin/ps; do
  [ -x "$real" ] && exec "$real" "$@"
done
exit 1
EOF
  chmod +x "$dir/bin/ps"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3 \
    HARNESS_GATE="$statedir/.resetting" HARNESS_PID=$$); status=$?
  if [ -f "$statedir/.resetting.armed" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the ps shim never fired, so nothing changed hands (fixture)"
  elif [ ! -e "$statedir/.resetting" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "deleted a live reset's marker"
  elif ! grep -qF 'token intruder' "$statedir/.resetting"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the marker survived but its owner did not"
  elif [ "$status" -ne 2 ] || ! grep -qF "changed hands" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status — claimed on a verdict that had expired"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused and reviewed anyway"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND A MARKER THAT CHANGES HANDS AFTER THE LAST READ IS THE CASE THE OLD DESIGN COULD
# NOT SURVIVE. The case above lands in the gap the re-read closes; this one lands in the gap
# the re-read cannot close, because it opens the instant the re-read returns. Under a delete
# — by path or guarded by content, it makes no difference here, since the content the guard
# compares is the content that was there when it read — the wrapper unlinks a LIVE reset's
# marker and the claim loop is then open to every other wrapper for as long as that reset
# scans. Under no delete there is nothing left to be wrong: the intruder's marker stands, and
# this claim proceeds, which is the same thing as a claim made a moment earlier and is what
# the reset's own live-slot refusal is there to catch.
#
# So the assertion is the marker, not the exit. Deterministic by shimming the read itself:
# `cat` is external, the claim path reads the marker exactly twice, and the shim passes the
# first through and replaces the file immediately after serving the SECOND — which is the
# re-read — so the wrapper is past every look it will ever take when the file changes.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3); status=$?
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
label="a marker replaced after the final read survives the claim"
if [ "$status" -ne 0 ] || [ -z "$statedir" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "a clean run left no state dir (fixture)"
else
  printf 'pid 999999 token stale-one\n' >"$statedir/.resetting"
  cat >"$dir/bin/cat" <<'EOF'
#!/bin/sh
# Only the marker, and only its SECOND read. Serves what is there, then replaces it, so the
# wrapper's comparison passes on the content it was given and the file changes hands with
# every read already behind it. Everything else is the real cat, because the slot files and
# the reviewer's captures go through here too.
last=''
for a in "$@"; do last="$a"; done
case "$last" in
  *.resetting)
    n=0
    [ -f "$HARNESS_COUNT" ] && n="$(/bin/cat "$HARNESS_COUNT")"
    n=$((n + 1)); printf '%s\n' "$n" >"$HARNESS_COUNT"
    /bin/cat "$last" 2>/dev/null
    [ "$n" -eq 2 ] && printf 'pid %d token intruder\n' "$HARNESS_PID" >"$last"
    exit 0
    ;;
esac
for real in /bin/cat /usr/bin/cat; do
  [ -x "$real" ] && exec "$real" "$@"
done
exit 1
EOF
  chmod +x "$dir/bin/cat"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=3 \
    HARNESS_COUNT="$dir/reads" HARNESS_PID=$$); status=$?
  reads=0; [ -f "$dir/reads" ] && reads="$(cat "$dir/reads")"
  if [ "$reads" -lt 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "$reads read(s) of the marker — the re-read never happened (fixture)"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif [ ! -e "$statedir/.resetting" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "deleted a live reset's marker planted after the last read"
  elif ! grep -qF 'token intruder' "$statedir/.resetting"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the marker survived but its owner did not"
  elif [ "$status" -ne 0 ] || ! grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status — a stale marker must be ignored, not obeyed"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# A STRAY FILE IN THE STATE DIRECTORY CANNOT SWITCH THE CAP OFF. This case replaced
# "a corrupt count refuses rather than reading as 0" when admission stopped parsing a
# number: there is no count to corrupt now, only slots to claim, so the question
# changed from "does garbage fail closed" to "can garbage be mistaken for state at
# all". A file named `banana` is ignored and the cap still fires on the fourth run; a
# file named `2` would be a claimed slot and hence over-refusal, which is the
# direction this file always chooses.
#
# The state directory is found with a glob rather than recomputed, for the reason the
# old case gave and which still holds: rebuilding the cksum key here would be a second
# copy of production logic inside the test that verifies it, and a drifted copy would
# agree with itself and with nothing else.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
label="a stray file in the state dir is ignored, not read as state"
statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
if [ "$status" -ne 0 ] || [ -z "$statedir" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "no state dir was created by a clean run (fixture)"
else
  printf 'banana\n' >"$statedir/banana"
  round_ok=1
  for i in 2 3; do
    out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
    [ "$status" -eq 0 ] || { round_ok=0; break; }
  done
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
  if [ "$round_ok" -ne 1 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the stray file cost a legitimate round"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif [ "$status" -ne 4 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "4th run exit $status, wanted 4"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# TWO WRAPPERS, ONE ROUND, AND EXACTLY ONE OF THEM MAY HAVE IT. Admission used to be
# three steps with a vendor review in the middle — read the count, compare it, write it
# back afterwards — so N concurrent runs all read the same number, all passed the same
# test, and all sent a diff. The PR-side review on 2026-09-01 found it. The bound said
# three and the machine could do six, which is this file's signature defect in the very
# block written to stop the review loop.
#
# SIX AT ONCE AGAINST ROUND_CAP=1, not two, because a two-way race can be won by luck
# on a non-atomic implementation and read as a pass; six cannot. And concurrency is the
# ORDINARY case on this machine rather than a tail risk — defect 1 exists because two
# gates ran at once and it was measured — so this is the condition the cap operates
# under, not an exotic one.
#
# The assertion is a COUNT of statuses and not "the last one refused", because the
# failure being tested is several runs succeeding, and any assertion that looks at one
# run cannot see it.
#
# WHAT THIS CASE CAN AND CANNOT SEE, measured 2026-09-01 rather than assumed, because
# the first mutation written to prove it load-bearing came back GREEN. Replacing the
# O_EXCL claim with `[ ! -e ] && write` — a TOCTOU window a few instructions wide —
# does not fail here: six wrappers started from a `for` loop are milliseconds apart,
# so they never land inside it. What IS red is the admission this replaced: count the
# claimed slots, run the whole vendor review, write the slot afterwards. Six of six got
# a review under ROUND_CAP=1, because that window is the length of a review rather than
# of an instruction, and that is the defect the PR-side reviewer actually reported.
# So: this case discriminates a review-wide race and does NOT discriminate an
# instruction-wide one. Stated because a case whose reach is unmeasured reads as
# covering both, and the O_EXCL is kept on argument rather than on this evidence.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs" "$dir/out"
fake_clean "$dir/bin"
label="six wrappers racing for one round -> exactly one wins"
for i in 1 2 3 4 5 6; do
  ( round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=1 >"$dir/out/$i.log" 2>&1
    printf '%d\n' "$?" >"$dir/out/$i.status" ) &
done
wait
zeros=0; fours=0; others=''
for i in 1 2 3 4 5 6; do
  st="$(cat "$dir/out/$i.status" 2>/dev/null)"
  case "$st" in
    0) zeros=$((zeros + 1)) ;;
    4) fours=$((fours + 1)) ;;
    *) others="${others:+$others }$st" ;;
  esac
done
if [ -n "$others" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "unexpected status(es): $others"
  awk '{ print "       | " $0 }' "$dir/out/1.log" | head -5
elif [ "$zeros" -ne 1 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "$zeros of 6 got a review under ROUND_CAP=1"
elif [ "$fours" -ne 5 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "$fours refusals, wanted 5"
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# ROUND_CAP=0 is refused, and the WORDING is the assertion. The numeric loop for the
# caps says "a whole number of seconds", which is false about a count of reviews, and
# both messages contain the string `ROUND_CAP` — so greping for the variable name
# would score green on the wrong refusal. That is the anchor vacuity from the sibling
# guard's twelfth round and defect 13 here, and it is cheap to avoid: reject the token
# that only the wrong message can contain.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=0); status=$?
label="ROUND_CAP=0 -> exit 2, and not as a duration"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "seconds" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "called a review count a duration"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "greater than 0" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without saying what it wanted"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# THE TWO NEW VARIABLES TAKE `${VAR-default}` AND MUST REFUSE AN EMPTY VALUE LIKE THE
# FIVE THAT PRECEDED THEM. Defect 3 was `${VAR:-default}` handing the default to an
# explicitly empty value, so a bound the operator tried to set silently was not one —
# and its own fix was half-enumerated at first: five variables had the hole and the
# suite probed one. Adding two more variables in the same form without adding their two
# cases would be that same half-enumeration, one round later, which is why these exist
# rather than resting on "it uses the same loop".
#
# The anchor is the SENTENCE, not the variable name (defect 13, and the sibling guard's
# twelfth round): every one of these refusals prints `VENDOR_ROUND_DIR` somewhere,
# including the two that have nothing to do with an empty value, so a bare-name grep
# would score green on the wrong refusal.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs" ROUND_CAP=); status=$?
label="rejects ROUND_CAP=, and not as a duration"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "seconds" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "called a review count a duration"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "ROUND_CAP must be a whole number of reviews" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "did not name ROUND_CAP as what it rejected"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# `round_run` sets VENDOR_ROUND_DIR itself and `env` lets the LAST assignment win, so
# this case cannot go through the helper — passing an empty value as an extra argument
# would be silently overwritten and the case would assert nothing. That is the shared-knob
# vacuity (defect 11) turned inside out: a helper that fixes the variable under test.
#
# STATED PLAINLY, because the mutation showed it: this refusal is defence in depth and
# not the only barrier. Delete VENDOR_ROUND_DIR from the generic empty-value loop and an
# empty value still refuses at the write probe with exit 2 — it just blames writability
# instead of the empty value, which is defect 13's shape (a right status with a wrong
# diagnosis) rather than a pass. So the assertion is on the SENTENCE for a second reason:
# the status alone cannot tell the two apart.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
out=$(env VENDOR_ROUND_DIR= PATH="$dir/bin:$PATH" CR_LOG_DIR="$dir/logs" \
  TOTAL_CAP=6 CONNECT_CAP=2 POLL=1 bash "$UNDER_TEST" --base main 2>&1); status=$?
label="rejects VENDOR_ROUND_DIR=, naming it"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "VENDOR_ROUND_DIR is set but empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without naming the empty variable"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "launched the reviewer anyway"
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# A COUNTER THAT CANNOT BE WRITTEN REFUSES BEFORE THE LAUNCH, not after it. Proceeding
# uncounted is a bound switched off by a filesystem condition (defect 3's shape, where
# two concurrent logs disabled the connect kill); refusing AFTER the review would print
# a refusal over a review that happened (defect 9's shape). So the probe is early, and
# the assertion that pins it is again the fake's own line being absent. `$dir/rounds`
# is a regular FILE here, so `mkdir -p` cannot succeed.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
: >"$dir/rounds"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
label="unwritable counter -> exit 2 before any launch"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "VENDOR_ROUND_DIR" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without saying which variable fixes it"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "launched the reviewer and refused afterwards"
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# AN EMPTY ROUND-KEY HASH IS ONE BUCKET FOR EVERY BRANCH, NOT A DEGRADED KEY. The
# design note above the round cap enumerated `pwd -P` (a builtin, cannot fail) and
# `git rev-parse` (fails to `no-branch`, which over-refuses within ONE directory),
# and stopped there — while the line building the state directory ran a third
# external command whose failure merges every directory and branch into a single
# budget. A branch that has had no review then refuses with exit 4, "out of rounds",
# which is a wrong verdict rather than a late one: the write probe's own shape, two
# lines above the write probe. Half-enumerated failure paths, in the block added to
# stop this file's list from growing.
#
# WHAT THE DOUBLE MODELS AND WHAT IT DOES NOT. A stub `cksum` that exits 127 with no
# stdout produces byte-for-byte what an absent `cksum` produces at this expansion —
# empty output — which is the condition under test. It does NOT model an absent
# `cksum` for anything else in the script, and nothing else uses it. Prepending the
# stub is the only way to do this from inside the harness at all: `$dir/bin` goes on
# the FRONT of PATH, so there is no subtracting a command from it here, and a shim
# farm like the template CI step's is a different fixture entirely. A restricted PATH
# would also drop `tr` and `cut` and refuse for a reason with nothing to do with the
# hash, which is the shim-floor defect this same round fixes in that workflow.
#
# The assertion is on the SENTENCE, and specifically on it naming `cksum`, because
# exit 2 alone cannot tell this refusal from the four other exit 2s within twenty
# lines of it, and a refusal that does not name the command sends the operator to
# VENDOR_ROUND_DIR, which is not the problem. Defect 13's shape.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs" "$dir/rounds"
fake_clean "$dir/bin"
printf '#!/bin/sh\nexit 127\n' >"$dir/bin/cksum"; chmod +x "$dir/bin/cksum"
out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
label="an empty round-key hash refuses, naming cksum"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "could not hash the round key" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused, but not on the hash"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "cksum" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "did not name the command that could not run"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif [ -d "$dir/rounds/.rounds" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "built the shared-bucket state dir anyway"
elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "launched the reviewer uncounted"
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

# A COLLIDING KEY HAS TO SURVIVE THE NEXT RUN, or the `key` file is a diagnostic that
# reads the same whether or not the thing it diagnoses happened. The write was a plain
# `>` until 2026-09-02, so the second key overwrote the first: an operator inspecting
# `key` after an unexplained exit 4 saw one key — their own — which is byte-for-byte
# what a non-colliding directory shows. The verdict was right and the artifact for
# checking it was silently the wrong artifact, which is defect 16's class.
#
# A REAL HASH COLLISION CANNOT BE CONSTRUCTED HERE, so the foreign key is PLANTED. That
# is a substitution and it is named rather than glossed: what this case cannot show is
# that two genuinely colliding keys reach the same directory (that is `cksum`'s
# business, not this script's), and what it does show is the only part this script
# decides — that an existing key is preserved, that ours joins it, that the operator is
# told the budget is shared, and that a third run does not append a duplicate. The last
# of those is why the check is membership and not "differs from the file": the obvious
# comparison appends on every run once two keys are present, and a file growing without
# bound is how this stops being readable a second time. The third run is what makes the
# membership form load-bearing rather than a style choice.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
key_ok=1
round_run "$dir/rounds" "$dir/bin" "$dir/logs" >/dev/null 2>&1 || key_ok=0
key_file=$(find "$dir/rounds" -maxdepth 2 -name key -type f 2>/dev/null | head -n1)
label="a colliding key survives, and is not re-appended"
if [ "$key_ok" -ne 1 ] || [ -z "$key_file" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "the warmup round did not leave a key file (fixture)"
else
  printf '%s\n' "/some/other/checkout@@other-branch" >>"$key_file"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
  before=$(grep -c '' "$key_file")
  out2=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status2=$?
  after=$(grep -c '' "$key_file")
  if [ "$status" -ne 0 ] || [ "$status2" -ne 0 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "runs exited $status/$status2, wanted 0 (fixture)"
  elif ! grep -qxF "/some/other/checkout@@other-branch" "$key_file"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "the foreign key was overwritten — a collision reads as its absence"
  elif [ "$before" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "key holds $before lines after the collision, wanted 2"
    awk '{ print "       | " $0 }' "$key_file" | head -5
  elif ! grep -qF "budget is SHARED" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "shared budget went unreported"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "budget is SHARED" <<<"$out2"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "reported once and then went quiet — the run that sees exit 4 is a later one"
  elif [ "$after" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "key grew to $after lines on a repeat run — not membership"
    awk '{ print "       | " $0 }' "$key_file" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# AND THE COUNT IS OVER DISTINCT KEYS, WHICH THE CASE ABOVE CANNOT SEE because every key
# it plants is a different one. The check-and-append is two steps and this script admits
# concurrent wrappers by design — the six-way race case above is one — so two arriving
# together both find the key absent and both append it. A LINE count then reports a
# shared budget over one key present twice: a false positive indistinguishable from the
# real reading, on the one artifact that exists to tell them apart.
#
# THE DUPLICATE IS PLANTED RATHER THAN RACED, and that substitution is the point rather
# than a shortcut. A race that must interleave two processes inside a two-line window is
# the flakiest possible fixture, and the state it produces — one key, twice — is
# reachable by `head -n1` in one line. What this cannot show is that the race happens;
# what it does show is that the state the race leaves behind is not read as a collision,
# which is the only harm the race had.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
fake_clean "$dir/bin"
dup_ok=1
round_run "$dir/rounds" "$dir/bin" "$dir/logs" >/dev/null 2>&1 || dup_ok=0
key_file=$(find "$dir/rounds" -maxdepth 2 -name key -type f 2>/dev/null | head -n1)
label="a duplicated key line is not read as a collision"
if [ "$dup_ok" -ne 1 ] || [ -z "$key_file" ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "the warmup round did not leave a key file (fixture)"
else
  head -n1 "$key_file" >>"$key_file.tmp" && cat "$key_file.tmp" >>"$key_file"
  rm -f "$key_file.tmp"
  out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
  lines=$(grep -c '' "$key_file")
  if [ "$status" -ne 0 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exited $status, wanted 0 (fixture)"
  elif [ "$lines" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "key holds $lines lines, wanted the 2 planted (fixture)"
  elif grep -qF "budget is SHARED" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "one key twice was reported as a shared budget"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# TWO REFUSALS, TWO SENTENCES, AND THE CASE ABOVE ONLY REACHES ONE OF THEM. Making
# `$dir/rounds` a file fails at `mkdir -p`; the per-branch state directory INSIDE it,
# existing and read-only, gets past mkdir and fails at the write probe, which is the
# line whose whole purpose is to move a discoverable-at-the-end failure to before the
# launch. Asserting the mkdir message and calling the probe covered would be a
# near-miss reading as coverage — defect 10's test hole, the most expensive kind here.
#
# THE PROBE IS LOAD-BEARING FOR A REASON THIS CASE NOW EXERCISES DIRECTLY. Admission
# is an O_EXCL create, and a failed `set -C` redirect cannot say WHY it failed: EEXIST
# means the slot is claimed and the cap is real, EACCES means nothing could be claimed
# and the cap has no idea. Without the probe every slot would fail to open and the
# refusal would be exit 4, "this branch is out of rounds", over a branch that has had
# none. So the first run below claims slot 1 legitimately; the directory is made
# read-only after it; and the second run must refuse on the WRITE, not on the cap.
#
# Skipped rather than faked when running as root, where chmod cannot make anything
# unwritable. A skip printed out loud is honest; a case that quietly cannot fail is
# not, and this suite has shipped four of those.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs" "$dir/rounds"
fake_clean "$dir/bin"
label="read-only state dir -> the write probe refuses, early"
if [ "$(id -u)" -eq 0 ]; then
  printf 'SKIP %-56s %s\n' "$label" "running as root; chmod cannot make it unwritable"
else
  round_run "$dir/rounds" "$dir/bin" "$dir/logs" >/dev/null 2>&1
  statedir="$(find "$dir/rounds" -name '*.rounds' -type d 2>/dev/null | head -n 1)"
  status=0
  out=''
  if [ -n "$statedir" ]; then
    chmod 500 "$statedir"
    out=$(round_run "$dir/rounds" "$dir/bin" "$dir/logs"); status=$?
    chmod 700 "$statedir"
  fi
  if [ -z "$statedir" ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "no state dir after a clean run (fixture)"
  elif [ "$status" -ne 2 ]; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif ! grep -qF "cannot write" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "refused, but not on the write probe"
    awk '{ print "       | " $0 }' <<<"$out" | head -5
  elif grep -qF "reviewing 3 of 3 changed file(s)" <<<"$out"; then
    failed=$((failed + 1))
    printf 'FAIL %-56s %s\n' "$label" "launched the reviewer and refused afterwards"
  else
    passed=$((passed + 1)); printf 'ok   %s\n' "$label"
  fi
fi

# THE SECOND HOME-DERIVED DEFAULT. `ROUND_DIR` was added on the same `${HOME:+...}`
# expansion as `LOG_DIR`, and with CR_LOG_DIR set explicitly it is the ONLY one an
# absent HOME can break — which is a state the existing HOME case cannot reach, since
# it leaves CR_LOG_DIR unset and refuses on that one first. Without this case a
# refusal blaming "VENDOR_ROUND_DIR is set but empty" would score green, and that
# sentence is false in cron twice over: it is not set, and unsetting it changes
# nothing. Exactly defect 13, one variable later.
n=$((passed + failed + 1)); dir="$TMP/case-$n"; mkdir -p "$dir/bin" "$dir/logs"
out=$(env -u HOME CR_BIN=true CR_LOG_DIR="$dir/logs" bash "$UNDER_TEST" 2>&1); status=$?
label="HOME unset + CR_LOG_DIR set -> blames VENDOR_ROUND_DIR"
if [ "$status" -ne 2 ]; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "exit $status, wanted 2"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "cannot build a default VENDOR_ROUND_DIR" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "did not name the default it could not build"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif ! grep -qF "HOME is unset or empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "refused without naming HOME as the cause"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
elif grep -qF "is set but empty" <<<"$out"; then
  failed=$((failed + 1))
  printf 'FAIL %-56s %s\n' "$label" "said it was set but empty; it is unset"
  awk '{ print "       | " $0 }' <<<"$out" | head -5
else
  passed=$((passed + 1)); printf 'ok   %s\n' "$label"
fi

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
