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
# case count the run was measured against, because the suite has grown three
# times and a count quoted as current when it is not is the same defect the block
# at the bottom of this file is about:
#
#   restore the log-reading detector     -> 20 passed, 1 FAILED (of 21,
#     (`git show HEAD~:...`)                2026-09-01) — the healthy-but-slow
#                                           case, refused with "never got past
#                                           its connect phase". That red run IS
#                                           the fourth defect stated out loud
#   replace `tr '\r' '\n'` with `cat`    -> 20 passed, 1 FAILED (of 21,
#     in the connect detector               2026-09-01) — the same case. The CLI
#                                           redraws progress in place, so without
#                                           the split "the last progress line" is
#                                           the whole stream and means nothing
#   `${VAR:-default}` back on the caps   -> 16 passed, 5 FAILED (of 21,
#                                           2026-09-01) — one per variable whose
#                                           empty value silently took a default
#   the whole pre-verdict-gate script    -> 22 passed, 7 FAILED (of 29,
#     (`git show HEAD:...`, defect 6)       2026-09-01) — the three verdict-gate
#                                           cases and the four empty-git-variable
#                                           cases. Every OTHER case stayed green,
#                                           which is how the reworked fakes were
#                                           shown not to have moved the old ground
#   make the 128+ branch unreachable     -> 28 passed, 1 FAILED (of 29,
#                                           2026-09-01) — the signal case alone,
#                                           which is the point of it being a
#                                           separate branch: it holds when the
#                                           output parse does not
#   make the failed-before-reviewing     -> 27 passed, 2 FAILED (of 29,
#     branch `if false`                     2026-09-01) — both non-review cases,
#                                           and NEITHER findings case, so the two
#                                           halves are independent
#   drop the phase test from that        -> 27 passed, 2 FAILED (of 29,
#     branch, i.e. adopt the CLI's         2026-09-01) — both FINDINGS cases, the
#     status after all                     opposite pair. The gate is pinned from
#                                           both sides: too narrow loses the
#                                           non-review, too broad loses the review
#   revert `fake_found_issues` to its    -> 27 passed, 2 FAILED (of 29,
#     pre-2026-09-01 phaseless form        2026-09-01) — both findings cases, on a
#     (a FIXTURE mutation, not a           CORRECT script. That is the shape of a
#     script one)                          vacuous double caught from the other
#                                           direction: the fake made right code
#                                           look wrong, and one written the other
#                                           way round makes wrong code look right
#   delete the early connect kill        -> the connect case AND the two-log
#                                           case fail (2 of 17, 2026-08-31)
#   make a kill `exit 0` instead of 3    -> all four hang cases fail (4 of 14,
#                                           2026-08-31)
#   adopt the CLI's exit status as ours  -> both findings cases fail (2 of 14,
#                                           2026-08-31)
#   the whole pre-fix script             -> the two-log case and the orphan case
#                                           fail (2 of 17, 2026-08-31), which is
#                                           how both defects were confirmed
#                                           rather than argued
#   remove the INT/TERM/HUP traps        -> the orphan case fails (1 of 17,
#                                           2026-08-31), reporting both
#                                           surviving pids
#   kill the pid but not its descendants -> the orphan case fails (1 of 17,
#                                           2026-08-31), reporting exactly ONE
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
# they exit at the guard, or name an absent `CR_BIN`). The suite has since gained
# four `case_run` cases and the stream-separation case, so it makes 16 launches, and
# the five added after 2026-08-31 were never put in front of the shim. Count the
# `case_run` calls with `grep -c '\bcase_run "'` rather than `^case_run`: one of them
# carries a `POLL_OVERRIDE=` prefix, and anchoring at the line start undercounts by
# one — which it did on 2026-09-01, in the very act of correcting this number.
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
# defaults, where TOTAL_CAP is 900s — the same 900s as `timeout-minutes: 15` on the
# CI job. A case that ever stopped exiting promptly would be reported as a job
# timeout with no case output at all, instead of as the failed assertion it is.
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

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
