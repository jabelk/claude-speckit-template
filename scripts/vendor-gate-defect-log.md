# Vendor-gate defect log — `bounded-vendor-review`

**This is the single copy.** Until 2026-09-01 this history lived in the comment header of
`scripts/bounded-vendor-review.sh`, whose header alone was 588 comment lines on the day before
the move — 951 in the whole file, against 229 executable ones — and was mirrored, in
prose (never verbatim, which is its own staleness surface), into four other
documents: `STATE.md`, `dotfiles/claude/CLAUDE.md`, `.claude/skills/review-plan-v2/SKILL.md`,
and the `internal-speckit-template` copies of the last two. Five copies meant five times the
staleness surface per defect added, and the arithmetic in those summaries went stale in three
places at once, twice — which cost two review rounds that found nothing else. Everything else
now points here.

**Read the text below as if you were reading the script.** It was moved verbatim rather than
rewritten, so "this header", "this file", and "below" refer to
`scripts/bounded-vendor-review.sh` and its enumeration, not to this document. Rewriting 440
lines of measured history to fix the pronouns is how a fresh false claim gets introduced into
a record whose whole subject is false claims.

**EVERY PATH BELOW IS RELATIVE TO `internal-claude-workflows`, AND THIS FILE IS BYTE-IDENTICAL IN
`internal-speckit-template`.** That is deliberate — `cmp -s` across the two repos is the only thing
keeping the account from forking — and it means a path in the entries below can be a dead reference
in the copy you are reading. The template has no `.github/workflows/tests.yml`; the job that runs
both guard suites, the shellcheck pass over all four scripts, and the reachable-command floor is
`.github/workflows/guard-suites.yml` there, and the two are not line-for-line equivalents (the
template's floor exists to hold up a deliberately restricted PATH, which is why `cksum`'s entry
below names that file rather than this repo's). `dotfiles/` exists only here; the template's
skills call `scripts/preflight-vendor-review.sh` and `scripts/bounded-vendor-review.sh` by
repo-relative path, because a bootstrapped repo has to work before anything is installed, while
this repo's call the installed `~/.local/bin` names. **One note here rather than a qualifier at
each call site**, because patching the call sites one at a time is the half-enumeration this file
records four separate instances of; resolve a path against this paragraph before calling it broken.

**The sibling guard's own history is not here.** `preflight-vendor-review` took twelve rounds
on one lesson, and that account lives in `dotfiles/claude/CLAUDE.md` under the pre-push gate
section, where the operational rules it produced are.

## The defects

THE DEFECTS FOUND BY USING IT, all fixed here, all kept in the header because each is a way
this file's own claims were false. Twenty-six of them. TWENTY are the same defect — AN
ADVERTISED BOUND, OR AN ADVERTISED VERDICT, THAT WAS NOT THE ONE ADVERTISED — and the other
six are their own classes, listed anyway because dropping them would make the pattern look
tidier than it is. Not one of the twenty-six was found by the author reasoning about the
code; the closest is defect 21, which a CI runner found by running a linter version this
machine does not have. EIGHTEEN of the twenty-six had a test that should have caught them
and could not — defects 3, 4, 7 through 16, 19 through 21, 23, 25 and 26 — and in every one of
those eighteen the vacuity was in the FIXTURE, THE HARNESS, THE INHERITED ENVIRONMENT, THE
UNRUN MODE, THE UNMODELLED READER, THE UNRUN LINTER VERSION, THE SHARED KNOB, THE UNENTERED
WINDOW, or THE ASSERTION'S ANCHOR rather than in the assertion's logic. Defects 17, 18, 22 and
24 are outside that eighteen for two plain reasons: for 17, 18 and 24 the block they lived in
was new, so there was no blind test — only no test; and 22 is a claim in four documents rather
than a line of code, and the checks that had read this file's own prose were deleted the day it
became a document.

The count is anchored to those defect IDs rather than asserted on its own, because it has
now been wrong in three different places at once: this line said SIX, all five docs said
SEVEN, and the entries below already numbered EIGHT distinct shapes (11 is labelled "a
seventh shape", so 12 is the eighth). A summary number with nothing anchoring it drifts one
round after it is written, which is the same reason the suite's launch count now states how
to derive itself instead of naming a figure.

THAT ANCHORING WAS A TEST FOR TWO DAYS, AND ITS FIRST REAL USE WAS CATCHING THIS PARAGRAPH.
`header's own counts match its enumeration` parsed the ordinals below and checked the totals
above against them; adding entry 13 turned it red — 13 entries against a total still written
as the previous number — before any human read the diff. Two rounds later the check ITSELF
was the next thing found wrong, which was the ugliest and most useful thing in the header:
it greped LINE BY LINE for a claim that is a sentence, so a count phrase wrapped across two
comment lines was invisible to it, and one was, sitting green through every run of the case
written to catch exactly that. A check whose failure is indistinguishable from its success
is not a check, and writing a check FOR that failure mode is not the same as being immune to
it. A fifth check in the same block then banned absolute suite totals, and was itself
anchor-vacuous the day it landed and half-enumerated the round after.

**BOTH CHECKS WERE DELETED ON 2026-09-01, when this header became this document.** Their
subject was the script's own commentary rather than its behaviour, and four of the rounds this
file cost were spent entirely inside that loop: a stale number, a check for stale numbers, a
defect in the check, a fix to the check. The enforcement that
replaced them is structural rather than mechanical — there is one copy of this history now
instead of five, so there are four fewer places for a number to drift, and the suite prints
its own case total at runtime rather than having one written down anywhere. State that as the
weaker guarantee it is: nothing now fails when a count in this file goes stale. Two habits
survive the deletion and are worth keeping by hand. Anchor a total to the entries rather
than asserting it on its own, because it has been wrong in three places at once. And DESCRIBE
a retired count rather than quoting it — that was a cost of the flattened-string fix, and it
outlives the check, because a quotation and a live claim read the same to any reader skimming
for the current number.

**THE ABSOLUTE ROUND TOTAL WAS RETIRED ON 2026-09-02, for the reason the deleted checks
existed.** Six sentences across three documents named how many review rounds this wrapper had
cost, the figure was written once and never derived, and by the time anyone re-read it two more
rounds had happened — so every copy was stale by two, including two sentences that quote the
figure and then say in the next clause that no figure is quoted here because they all go stale.
The ones that needed the scale now say **twenty-plus**, which is a floor and cannot rot in the
direction that matters; the ones where the total was incidental simply do not state it. **That
sweep was half-enumerated and the next round found the other half** — two more copies sitting in
the wrapper's own header, one of them in the paragraph explaining why counts in comments go
stale. Sixth instance of a fix applied to the call sites someone happened to think of, in a file
whose eighth defect is that shape; `grep -riE` for the number word, not for the sentence you
remember writing. The
defect total above stays, because it is anchored to the numbered entries beneath it and can be
checked in one pass. A number nothing can check is a claim, and this file is a list of those.

Eighteen of the twenty-six (9 through 26) were found only AFTER the other eight were fixed
and written up, by reviewers reading the fixed file — 11 was found in the round that fixed 9 and
10, 12 in the round that fixed 11, 13 in the round that fixed 12, 14 in the round that fixed
13, 15 in the round that fixed 14, 16 in the round that fixed 15 in a display the round that
fixed 14 had rewritten, 18 in the round that fixed 17, inside 17's own fix, 19 through 22 in
the round that shipped the fixes for 17 and 18 — three of those four by the vendor leg reading
the fixed file, the fourth by a CI runner — 23 and 24 in the round that shipped the fixes
for 19 and 20, both by the vendor leg, 24 INSIDE 20'S OWN FIX, 25 in the round that shipped
those two, on the one side of 24's own protocol that round did not touch, and 26 in the round
that shipped 25, INSIDE 25'S OWN FIX. The list is not converging on zero, and pretending
otherwise in this header would be the same category of false claim as the defects themselves.
Defects 17 through 20 and 23 through 26 are the sharpest evidence for that: all eight are in the
ROUND CAP — the mechanism added to stop this loop — all eight are the shape that most of the
entries above them already were, 19 and 20 arrived in the round that wrote 18 up at length as an
example of exactly that, one of them contradicting a sentence inside 18's own entry, 24 is 20
reached a second time through the repair written for it, 25 is 24 reached a third time on a call
site the argument for 24 never enumerated, and 26 is that same argument reached a FOURTH time
because 25's repair narrowed the window instead of removing the writer.

### Defect 1 — THE EARLY KILL WAS DEAD WHENEVER A SECOND CLI SESSION WAS RUNNING

The original `this_log()` demanded EXACTLY one log file new since launch and returned empty
otherwise, so that a concurrent session's log could not time our run against someone else's
progress. That is what it did, and the cost is the defect: running two gates at once on this
machine is the ORDINARY case, and whenever the second one's log appeared the count went to
2, the early kill switched off, and the advertised 120s bound silently became the 900s
TOTAL_CAP. Measured 2026-08-31 on a real branch: our log at 04:41:02Z, a second at 04:42:21Z
belonging to a `bounded-vendor-review` running in another repo (its wrapper pid was alive
and watching its own child, checked with `ps -eo pid,ppid,pgid,lstart`). Fail-closed, and
the 120s promise in this header was still not what happened. A bound that switches off when
a second copy of the gate runs is not a bound you have.

THE ATTRIBUTION WAS WRONG FIRST TIME, and the wrong version is worth recording because it is
the more alarming one and it was not true: this header said the CLI writes a second log from
a child process within one invocation. It does not. Two logs 79s apart is two chains offset
by the runtime of leg 1, and the same 79s appearing twice is what that offset looks like,
not a CLI behaviour. The fix below is unchanged by the correction — the condition is "more
than one new log", whatever wrote them.

So the connect test was widened to ALL logs new since launch: any one of them showing
progress past the marker counted as connected. That kept the fail-closed direction (a healthy
concurrent session makes us DECLINE to kill and defer to TOTAL_CAP) while still bounding the
case where every new log is stuck, which is what a vendor outage looks like from here.

SUPERSEDED BY DEFECT 4, which is why this reads in the past tense: the logs are no longer
part of the connect decision at all, because the CLI writes nothing to them after the marker
on a healthy run either. `new_logs` survives only to name files in a refusal, so this fix is
correct and no longer load-bearing, and the case that guards it now asserts the refusal cites
BOTH log files — sending the reader to one of two is how you conclude the wrong thing about
which session hung.

### Defect 2 — IT ORPHANED THE REVIEWER WHEN THE WRAPPER ITSELF WAS KILLED

The only trap was `trap 'rm -f "$out"' EXIT`, so an outer timeout or a Ctrl-C killed the
wrapper and left the CLI running: an unsupervised vendor process is an egress nothing is
bounding, and it contradicts this file's own stated goal that nothing survives. INT/TERM/HUP
are now trapped and kill the reviewer's whole tree before exiting 3.

PROVEN BY FIXTURE, NOT BY FIELD MEASUREMENT, and the difference matters because the field
observation that prompted it was misread. A live `coderabbit review` was seen at 5m51s
elapsed after a wrapper was killed, and its parent pid was recorded without checking whether
that parent was still alive — on the same machine, at the same time, a concurrent gate's
wrapper was alive and watching exactly such a child. So treat that sighting as NOT VERIFIED.
What is verified is the fixture: with no signal trap, a wrapper killed by SIGTERM leaves the
reviewer and its grandchild running, reproduced on demand in `test-bounded-vendor-review.sh`
and failing red two independent ways. The defect is real; the anecdote was not evidence of
it.

Killing the TREE, not the pid, is the point. Without `setsid` (macOS has none) the CLI
shares this shell's process group, so `kill -- -$pid` fails and a bare `kill $pid` leaves
the grandchildren holding the socket — which is precisely the orphan measured above. `pgrep
-P` walks the descendants. It is an external command, but it is in the KILL path, never the
decision, so its failure can delay a refusal and cannot manufacture a pass.

### Defect 3 — AN EXPLICITLY EMPTY OVERRIDE SILENTLY BECAME THE DEFAULT

so a bound the operator tried to set was not set and read exactly like one that was.
`${VAR:-default}` substitutes for an empty value as well as an unset one, so `POLL=` became
5 and `TOTAL_CAP=` became 900, and the validator's own `''` branch below was unreachable
dead code. Five variables had the hole and the suite probed one. Found by CI rather than
here, and this machine structurally could not have found it: the cases asserted the exit
STATUS and never the message, so any exit 2 scored green, and their `CR_BIN=/bin/true` does
not exist on macOS (it is `/usr/bin/true`) — the harmless-real-binary trick whose whole job
is to leave the bad value as the only remaining reason to exit 2 instead handed the script a
missing binary, and every case exited 2 down the PATH check. On Linux the same line worked
as designed and failed on the real bug within a day. Fix is `${VAR-default}` throughout, one
case per variable, each asserting the refusal NAMES what it rejected. Two things worth
keeping: `CR_BIN=` fell back to the real `coderabbit` and launched an actual vendor review
from inside the test suite, so a vacuous default is not only a wrong answer but an egress;
and a double does not have to be elaborate to be vacuous — this one only had to be ABSENT,
which is the cheapest way there is to remove the condition under test.

### Defect 4 — THE CONNECT DETECTOR READ THE WRONG STREAM, AND SO COULD NOT TELL A WORKING REVIEW FROM A HUNG ONE

It looked in the CLI's LOG FILE for any line after the WebSocket marker. The CLI writes
nothing to its log after that marker during a healthy review — every progress line goes to
stdout. Measured 2026-09-01: a review whose stdout had reached `Writing review comments...
1m 01s elapsed` had a log whose last line before our SIGTERM was the marker, written 118s
earlier. Identical evidence to an outage. So the detector was killing healthy reviews at
CONNECT_CAP while reporting the vendor as unreachable, and it had been doing so on every run
since it was written.

This is the file's own rule applied to the one check invented here rather than inherited
from the sibling guard: A CHECK WHOSE FAILURE IS INDISTINGUISHABLE FROM ITS SUCCESS IS NOT A
CHECK. Worth sitting with, given the header above it had already said that four times about
someone else's code. The fixtures could not catch it because the "connected then slow" fake
wrote a log line after the marker, manufacturing the signal the real CLI never emits — a
double that invents its own evidence proves only itself.

`connect_verdict` now reads "$out", the reviewer's own stdout, which was captured and
sitting unread the entire time. Consequence for defect 1 above: logs are no longer part of
the decision at all, so the multi-log fix is correct but no longer load-bearing. `new_logs`
survives only to name files in the failure message, where listing all of them is still
right.

### Defect 5 — THE POLL SLEPT PAST THE DEADLINE

so once again the advertised bound was not the bound. `sleep "$POLL"` ran unconditionally at
the top of the wait loop, before either cap was consulted, and `POLL` is validated as a
positive integer and never against the caps. `TOTAL_CAP=900 POLL=3600` therefore left a hung
reviewer alive for about an hour, and even the defaults overshot TOTAL_CAP by up to one poll
interval. Raised by the PR-side review rather than found here, which is worth recording: it
is the FIFTH instance in this one file of a bound that reads as enforced and is not, and the
previous four did not make the fifth visible. The nap is now the shortest of POLL and
whichever deadline is nearer — see the wait loop, including why the connect deadline stops
constraining it once passed.

### Defect 6 — A REVIEWER THAT NEVER REVIEWED READ AS A VERDICT

This is the first entry in this list that was a genuine SILENT PASS rather than a late
refusal, and it took two of them composed to get there. (Until 2026-09-01 this entry named a
total instead — six, which went stale five defects later and was invisible to the case that
checks these numbers, because the phrase wrapped across two comment lines and that check
read the file line by line. A count with no reason to be a count is a claim that will rot;
this is now a claim about the list.) The reviewer-returned path exited 0 unconditionally, on
the stated contract that this script's job is only that a verdict EXISTS and the CLI's
status is the caller's to read. But a CLI that died on a signal, or errored before reviewing
anything, also "returns" — and it produced no verdict at all. Meanwhile the git-location
refusal above tested `[ -n "${!v:-}" ]`, which is blind to an explicitly EMPTY value, the
same hole as 3 one file over. Compose them: `GIT_DIR='' <gate>` passes the refusal (empty is
not "set" to that test), and empty `GIT_DIR` does not redirect git to another repository, it
BREAKS git outright — measured 2026-09-01, `fatal: not a git repository: ''`, exit 128. The
reviewer then errors instead of reviewing, and the unconditional exit 0 reported a clean
vendor review that never happened.

Both halves fixed. The refusal is `[ -n "${!v+x}" ]`, which asks whether the variable is SET
rather than whether it has content. And the reviewer-returned path now has a verdict gate
with two fail-safe branches, both of which refuse: a status of 128 or above is a signal
death, unambiguous because the CLI never spends 128+ on findings; and any non-zero status
with no post-connect phase line on stdout means it errored before reviewing. Note what is
NOT done — the CLI's status is still not adopted, because findings exit 1 and adopting it
would turn every flagged review into a refusal. Read the output; the status is reported
beside it, not laundered through ours.

`GIT_INDEX_FILE=''` behaves differently from the other three and from what the sibling
guard's docs record: it does not error, and git reports every tracked file as `D` deleted.
Those docs measure `GIT_INDEX_FILE=/tmp/empty` as exit 128 `index file smaller than
expected`; the empty STRING is the quieter case, and both suites now cover the empty-value
form of all four.

### Defect 7 — THE WRAPPER'S OWN PROSE WENT OUT ON THE REVIEWER'S STDOUT

Not a bound this time, and listed anyway rather than dropped for spoiling the pattern — the
convention above is that every defect found in this file stays in the header, and quietly
omitting the one that does not fit the tidy sentence is its own version of the problem. One
documented chain invokes this script with `--agent` — see defect 15 for the measured scope,
which this entry overstated as "the skills" until 2026-09-01 — and in that mode the CLI's
stdout is a machine-readable stream; the summary line and its four continuation lines went
to that same stream, so a consumer parsing the vendor leg read records the vendor never
emitted. Every other message here was already on stderr, so this was inconsistency rather
than design. Caught by the PR-side review on the promotion branch, before any consumer
parsed it.

Its own test hole is the more interesting half: `case_run` captures `2>&1`, so all thirteen
fixtures were structurally blind to which stream anything went to. Same lesson as 3 and 4
from a third angle — the HARNESS removed the condition under test, and no amount of reading
the assertions would show it. The suite now has one case that captures the two streams
separately, and it is red on exactly one assertion against the pre-fix script.

### Defect 8 — THE KILL PASS RE-ENUMERATED A TREE THE TERM HAD ALREADY DISMANTLED

so a grandchild that ignored SIGTERM was never killed — defect 2's orphan holding the
socket, arriving one signal later. `kill_tree` walked `pgrep -P` on every call, and both
escalation sites called it twice. After the TERM the direct child is gone and its children
belong to init, so the second walk returns nothing and the KILL reaches only the corpse. The
tree is now enumerated once, before the first signal, and both passes escalate over that
same list.

The fixture is again where the vacuity lived, and this is its fourth distinct shape.
`fake_hang_with_grandchild` runs `exec sleep 600`, which DIES ON TERM — so the KILL pass was
never asked to find anything, and the case that exists specifically to catch orphans passes
against the buggy script. Not an invented signal (4), not an absent double (3), not a merged
stream (7): a double that COOPERATES with the thing under test. A companion fixture whose
grandchild does `trap '' TERM` and loops is red against the re-enumerating version, on that
one case and no other. Raised by the PR-side review on 2026-09-01, which named the fixture
as the reason the suite was blind to it and was right.

### Defect 9 — IT CALLED A COMPLETED REVIEW A CAP KILL

the first FALSE REFUSAL in the list rather than a false pass. Liveness was tested only at
the top of the wait loop, and the nap inside it is clamped (defect 5's fix) to end exactly
ON a deadline. So a reviewer that RETURNED during that final nap met `SECONDS >= TOTAL_CAP`
on wake, and the loop set `killed_reason="total"`, threw the reviewer's own exit status
away, and printed NO VENDOR REVIEW HAPPENED over a review that happened. Seventh instance of
an advertised verdict that was not the one advertised, running in the other direction.

The window is one nap wide, which is exactly why no case touched it: every other fixture
either hangs well past the cap or returns well inside a nap. A boundary needs a fixture that
lands ON it, and `fake_finishes_during_the_final_nap` under `TOTAL_CAP=3 POLL=5` is that in
the smallest form there is. Fix is one `kill -0` — a builtin, and the same test the loop
already runs as its `while` condition, so it adds no trust assumption. Red without it, on
that case and no other.

### Defect 10 — IT REPLAYED THE REVIEWER'S STDERR ON STDOUT

The CLI was launched with `>"$out" 2>&1` and `$out` was then `cat` to this script's stdout,
so any diagnostic the vendor wrote to stderr came back as a line on the stream a `--agent`
consumer parses as NDJSON. Its own class, and a galling one: defect 7 is "stdout belongs to
the reviewer, not to this script", fixed by moving this wrapper's prose to stderr — and the
merge one layer in, in the production launch line, survived that whole round. Now two temp
files, reviewer stdout to stdout and reviewer stderr to stderr, and `connect_verdict` reads
BOTH because which stream carries the progress lines has only ever been measured merged.

THE HARNESS, for the second time and the sixth blind test overall. `case_run` captures
`2>&1`, which is right for what those cases assert and is precisely what removed this
condition — and defect 7's own write-up says so, in this file, about this harness. The case
added for defect 7 pins where THIS SCRIPT's prose goes and says nothing about the reviewer's
two streams, which is the near-miss that reads as coverage. Red with the streams re-merged,
on the new case and no other.

### Defect 11 — IT SLEPT THROUGH THE SIGNAL THAT WAS SUPPOSED TO KILL THE REVIEWER

The wait loop's nap was a FOREGROUND `sleep "$nap"`, and bash does not run a trap while a
foreground command is executing — it waits for that command to finish. So `on_signal` was
deferred by up to a whole nap, and the clamp above it bounds the nap by TOTAL_CAP and never
by POLL: `POLL=900` left a killed wrapper's reviewer alive for about fifteen minutes,
holding the vendor socket over an unsupervised worktree. Defects 2 and 8 from a third
direction — a signal that does not reach the reviewer — and the eighth instance of an
advertised bound that was not the bound, since the traps advertise "killed the reviewer with
it" and that sentence was true up to POLL seconds later than it read.

MEASURED, not read out of the manual, 2026-09-01: a probe trapping TERM around a foreground
`sleep 10`, sent TERM at t=1s, printed `TRAP at 10s`; backgrounded and `wait`ed, the same
probe printed `TRAP at 1s`. `wait` is the interruptible one. The nap is now backgrounded,
`wait`ed with `|| true` (an interrupted `wait` returns 128+signal; this file runs `set -uo
pipefail` and deliberately NOT `-e`, so that `|| true` is defensive and declarative rather
than load-bearing — the first version of this entry said `-e` would abort the loop, which is
not true of this script and is corrected here rather than reworded away), and its pid is
reaped by `on_signal` — a trap that killed the reviewer and left a stray `sleep` would be
defect 8's orphan in miniature.

NO FIXTURE COULD HAVE CAUGHT IT AS THE SUITE WAS BUILT, which is a seventh shape of
blindness rather than a seventh excuse: every signal case ran at the short test POLL, where
a deferred trap is indistinguishable from a prompt one. The new case runs `POLL` LONGER THAN
THE WHOLE TEST TIMELINE, which is the only arrangement in which the deferral is visible at
all.

### Defect 12 — THE DEFAULT LOG PATH COULD MAKE THIS SCRIPT EXIT 1

the one status it promises never to use, produced by the line that builds a default.
`LOG_DIR` was `"${CR_LOG_DIR-$HOME/.coderabbit/logs}"`, and under `set -u` an UNSET HOME
aborts right there with `HOME: unbound variable`. Measured 2026-09-01: `env -u HOME` against
that form gives exactly that, at exit 1. The whole reason exit 3 exists is that the CLI
spends 1 on FINDINGS, on an unknown flag, and on "not a git repository" alike; a caller
reading 1 as "reviewed and flagged something" would be reading a script that never reached
the reviewer. Ninth instance of the advertised verdict that was not the one advertised, and
the second (after 6) to manufacture the appearance of a review rather than merely delay a
refusal.

NOT EXOTIC, which is the part worth arguing rather than asserting: HOME is absent from cron,
from systemd units, and from git hooks run by some daemons, and the gate documentation this
script belongs to suggests wiring it into a pre-push hook — the same environment that armed
defect 9 of the SIBLING guard, since git exports its location variables to every hook it
runs. Fix is `${HOME:+$HOME/...}`, which yields empty for unset AND for empty, so both reach
the validator below and are refused with exit 2. Empty is the correct answer for both: a log
root of `/` matches nothing, connect_verdict() degrades to `unknown` forever, and the early
kill is switched off again, which is defect 3's shape one layer out.

A test could have caught this one, and the reason none did is the plainest in the list: HOME
is set in every shell anybody runs a test from, so absence of the variable was never a state
any fixture constructed. `env -u HOME` is the whole case, and it is red at exit 1 against
the old form.

### Defect 13 — THE REFUSAL THAT FIXED 12 NAMED THE WRONG VARIABLE AND GAVE ADVICE THAT COULD NOT WORK

Defect 12's fix made an absent HOME yield an empty LOG_DIR, which reaches the generic empty-
value validator below — correct in status, and the message it prints is `CR_LOG_DIR is set
but empty. Unset it to take the default`. With HOME absent and CR_LOG_DIR never set, EVERY
CLAUSE OF THAT IS FALSE: CR_LOG_DIR is not set, unsetting it changes nothing, and there is
no default to take, because the thing that would have built one is the variable the message
does not mention. The operator who lands here is in cron, a systemd unit, or a git hook —
precisely where HOME goes missing and precisely where there is nobody to guess.

ITS OWN CLASS, and the reason it is not filed under the nine is that the exit status was
right: 2, refused, no review claimed. What was false was the DIAGNOSIS. That makes it the
sibling guard's eleventh round arriving here — that one told the caller to use `env -u`,
which covers a single leg of an `&&` chain, so following the guard's advice defeated the
guard. Advice that cannot resolve its own refusal is part of the defect and not cosmetics on
top of one. Fixed with an explicit branch above the generic loop, on `[ -z "${CR_LOG_DIR+x}"
] && [ -z "${HOME:-}" ]` — `+x` asks SET, not non-empty, which is what leaves a genuinely
set-but-empty CR_LOG_DIR in the generic branch where that message is true.

THERE WAS A CASE, IT WAS MINE, AND IT PINNED THE WRONG MESSAGE — a ninth shape of blindness,
and the only one so far where the vacuity is in the ANCHOR rather than in a fixture, a
harness, or the environment. Defect 12's case asserted exit 2 and the substring
`CR_LOG_DIR`, and the WRONG message contains that substring as readily as the right one, so
it scored green on advice that could not work. Written one day after the sibling guard's
twelfth round said, about nine of its own assertions: grep for the SENTENCE the check
produces, not for a token that appears in the wrong one too. Knowing the rule was not what
caught it; a reviewer was. The case now also requires the refusal to name HOME and to NOT
carry `is set but empty`, and a companion case pins the mirror image, since both refusals
name CR_LOG_DIR and the generic loop cannot tell them apart. Red one mutation per assertion:
`if false` gives "refused without naming HOME"; keeping the false sentence while adding HOME
gives "it is unset"; routing set-but-empty into the HOME branch reds both of those cases
while the generic loop's own `CR_LOG_DIR=` case stays GREEN, which is what makes the new one
load-bearing rather than duplicate.

### Defect 14 — A STALE LINE ON STDERR OUTRANKED A LIVE ONE ON STDOUT, AND REFUSED A REVIEW THAT HAD CONNECTED

`connect_verdict` read `cat "$out" "$err" | tail -n 1`, and `cat` orders BY FILE rather than
by time: a connect-phase `elapsed` line anywhere in $err beat every later phase line in
$out, the verdict was `stuck`, and the early kill reported the vendor unreachable at
CONNECT_CAP. Defect 4's outcome exactly — healthy reviews killed — reached by a different
route, and the FALSE-REFUSAL direction, which is defect 9's shape.

WHAT MAKES IT WORTH ITS OWN ENTRY IS THAT THE PREVIOUS ROUND KNEW AND FILED IT AS A LIMIT.
The comment above `connect_verdict` named this exact ordering, named the unsafe direction,
and said the only thing that resolves it is measuring which stream carries the progress
lines. That was wrong, and it is a tidier kind of wrong than a missed bug: reading $out
first and falling back to $err is correct whichever stream carries them, keeps `unknown`
when neither does, and needs no measurement at all. A limit that can be closed with no new
evidence was never a limit; it was a defect with a note on it, and the note made it read as
considered.

TENTH TEST HOLE, and it is defect 9's blindness at one remove: a STATE NO FIXTURE
CONSTRUCTED. Every fixture that wrote to stderr wrote one non-progress diagnostic (defect
10's), and every fixture with progress lines put them all on stdout, so no case ever made
the two streams competing sources of the same signal.
`fake_slow_with_connect_line_on_stderr` is `fake_healthy_but_slow` with one line moved, and
it is red against the merged read with `never got past its connect phase` — the outage
sentence printed over a working review.

### Defect 15 — THE DETECTOR READ THE PROSE STREAM ONLY

SO IT REFUSED EVERY FINDINGS RUN IN THE `--agent` MODE THE SKILLS DOCUMENT.
`_last_progress_line` greped for the literal `elapsed`, which the CLI emits in its human
progress redraws. Under `--agent` there is no prose stream at all: stdout is NDJSON and
carries no `elapsed` anywhere. So `connect_verdict` was permanently `unknown`, CONNECT_CAP
was switched off, and — the part that matters — a findings run exits 1, met branch 2's `!=
connected`, and printed NO VENDOR REVIEW HAPPENED over a review that had completed and
flagged something. Defect 4's outcome by a third route, in the false-refusal direction.

HOW OFTEN THAT MODE IS ACTUALLY USED, because the first write-up of this defect got it wrong
and propagated the wrong version into five documents. It said "both skills call the wrapper
with `--agent`, so on an old copy that is the ordinary path, not an edge case." Counted
2026-09-01 across the two repos: five documented invocations of this script exist and
exactly ONE passes `--agent` — the agent-mode chain in `review-plan-v2/SKILL.md`. (That
sentence is deliberately phrased around the count rather than with an `of the <number>`
construction, because the header-arithmetic check reads any such phrase above three as a
claim about the defect total and cannot parse English well enough to know better. Its own
comment predicted that cost and chose it; today is the first time it was actually paid, and
one reword is what it came to. Describing the retired phrasing rather than quoting it is the
same constraint one layer on — a quotation is a red too.) The primary gate command in every
skill omits it, because the operator reads that leg's output as prose. So the defect is real
and its blast radius was overstated: a pre-fix exit 3 is explained by this defect only when
the caller passed the flag. What is measured on the other side is that the CLI itself prints
`Notice: Detected claude environment. Use 'coderabbit review --agent' ...` on every run
inside an agent session, so the mode is recommended by the vendor to exactly the caller most
likely to be running this wrapper — which is why "one of five" is a scope and not a
dismissal.

Kept as a correction rather than a silent reword, on this file's own rule about design
comments that outlive the design. The generalisable part: the claim was about the CALLERS,
and every check in the suite is about this script, so nothing in the harness could have
contradicted it. A frequency claim needs a count, and the count was one `grep` away for the
whole round.

MEASURED, NOT INFERRED, because inferring what a stream carries is precisely how defect 4
happened. 2026-09-01 on 0.7.5, agent mode, 50s of a real run: stdout held
`{"type":"review_context",...}` then `{"type":"status","phase": "connecting",...}`,
`"phase":"setup"`, `"phase":"analyzing"`; zero lines matching `elapsed`; and stderr was
EMPTY — 0 bytes, which also means the $out-then-$err fallback of defect 14 has nothing to
fall back to in this mode.

The fix reads BOTH shapes and does not sniff the flag. Mode detection by argument parsing
would be a fourth thing to keep in sync with the vendor, and it is unnecessary: the CLI
names its own phase in both modes, more explicitly in NDJSON than in prose. `grep -E
'elapsed|"phase":'` takes the last line of either shape, and `stuck` now tests the connect
phase in both vocabularies. A mode emitting neither still lands on `unknown`, which is where
it was.

ELEVENTH TEST HOLE, and it is A MODE NO FIXTURE RAN — the closest sibling to defect 12's
inherited environment, in that the harness never chose it. Every fake in the suite emits
prose progress lines, including `fake_found_issues`, whose entire job is the findings path
this defect breaks; that case is green against the buggy script because it speaks the mode
the bug does not affect. `fake_agent_findings` and `fake_agent_hang` emit the NDJSON
measured above and nothing else.

### Defect 16 — THE REFUSAL'S OWN DISPLAY ORDERED BY FILE, SO IT COULD NOT ANSWER THE QUESTION ITS MESSAGE ASKED

Its own class, and the shortest way to say why it is not defect 14 again: 14 was a wrong
VERDICT, this was a correct verdict printed above a block the reader cannot use to check it.
The refusal ran `cat "$out" "$err" | tr '\r' '\n' | tail -n 15` — `cat` orders by file, so a
single stale connect-phase line in `$err` printed after every later-phase line in `$out`,
and the display's last line was not the run's last line. Directly beneath it the message
said "its last phase above was still the connect one", and both skills instruct the operator
to overrule an exit 3 by reading this block. So the one reader with no way around it was
handed the one arrangement that cannot settle the question, in the round after the same
ordering was removed from the verdict two hundred lines up.

Fixed with two labelled sections in the verdict's own order — stdout, then stderr — rather
than a merge with a sort, because there is no shared clock across two capture files and
inventing an interleaving would be defect 4's mistake (asserting what a stream carries)
relocated to the display layer. Discarding `$err` would also have "fixed" it and would lose
a diagnostic the vendor chose to emit, which is defect 10's rule.

TWELFTH TEST HOLE, and it is A READER NO ASSERTION MODELLED. Every case in the suite asserts
on the wrapper's MESSAGES — exit status, a sentence, which stream it went to — and the
reviewer-output block is the one part of the output whose whole purpose is to be interpreted
by a human rather than matched. Nothing was blind in the fixtures this time and nothing was
merged in the harness: the block was simply outside what the suite considered output. The
new case runs a fake whose stdout reaches a later phase while its stderr holds one connect-
phase line, and asserts the LAST line of the stdout section names the later phase; against
the concatenating version the sections do not exist and it is red on that case and no other.

### Defect 17 — THE ROUND CAP ADMITTED SIX REVIEWS UNDER A CAP OF ONE

The signature defect, in the block written to stop the review loop, found by the PR-side
review on 2026-09-01 in the round that added it. Admission was three steps with a vendor
review in the middle: read the count, compare it against `ROUND_CAP`, and write count+1 when
the review returned. Two wrappers on the same branch could therefore both read 2, both pass
the test, both send a diff, and both write 3. The bound said three rounds and the machine
could do six — an advertised bound that was not the one advertised, which is the thing
eleven of the sixteen above already are, written fresh by the author who had just finished
enumerating them.

Fixed with an atomic reservation rather than a lock. Each round is a file named `1`
..`ROUND_CAP` under the branch's state directory, created with `set -C` (O_EXCL) so exactly
one process wins a given name, and CLAIMING THE LOWEST FREE NAME **IS** ADMISSION — there is
no separate count to read, so there is no window to race in and no number a stray byte can
corrupt. The slot is released from the EXIT trap unless the verdict path sets `round_keep`,
which is what keeps a killed or refused run from spending a round. A lock held across the
review would also have been correct and was declined: it serialises concurrent gates for up
to `TOTAL_CAP`, and a gate that waits 900s for another gate is the hang this whole script
exists to prevent.

A separate write probe runs before the claim loop and is load-bearing for a reason worth
stating, because it looks like belt-and-braces. A failed `set -C` redirect cannot say WHY it
failed: EEXIST means the slot is taken and the cap is real, EACCES means nothing can be
claimed and the cap knows nothing. Without the probe an unwritable state directory would
fail every slot and refuse at exit 4 — "this branch is out of rounds" — over a branch that
has had none. Neutering the probe is red on exactly that case, at exit 4 instead of 2.

THE MUTATION THAT PROVED THE RACE CASE WAS THE SECOND ONE TRIED, AND THE FIRST CAME BACK
GREEN. Replacing the O_EXCL claim with `[ ! -e ] && write` — a TOCTOU window a few
instructions wide — does not fail: six wrappers launched from a shell loop start
milliseconds apart and never land inside it. What is red is the admission this replaced,
count-review-write, where the window is the length of a review: six of six got a review
under `ROUND_CAP=1`. So the case discriminates a review-wide race and NOT an
instruction-wide one, and that limit is written at the case rather than left implied,
because a case whose reach is unmeasured reads as covering both.

One residual, stated rather than engineered around: `kill -9` of the wrapper skips the EXIT
trap and leaks a held slot, so the branch refuses one round early. That is the safe
direction, and `ROUND_RESET=1` clears it.

**A suite flake came out of the same round, and it is the fixture-speed change rather than
the guard.** Making the fixtures fast — `TOTAL_CAP` 900 to 6, `CONNECT_CAP` 120 to 2 — left
`fake_hang_two_logs` writing its second log after `sleep 1` against a 2s cap, so under load
the refusal arrived before the second log existed and the case failed intermittently: twice
in six runs. The delay was never load-bearing, since `new_logs` is a set difference over a
pre-launch directory listing and not an mtime comparison. Both logs are now written before
the first sleep. An intermittent case is this file's own disease one layer out — a green run
that proves nothing — and no assertion in it looks wrong.

### Defect 18 — THE RESET BREACHED THE CAP IT WAS CLEARING

Found by the vendor leg on the round that shipped defect 17's fix, **in that fix**, and it is
the thirteenth instance of an advertised bound that was not the one advertised.

`ROUND_RESET=1` deleted the slot files `1..ROUND_CAP` and asked nothing about who held them.
So: wrapper A claims slot 1 and is reviewing. An operator runs a second gate with
`ROUND_RESET=1`; the loop deletes A's slot. B claims 1 and reviews. A finishes without a
verdict, and its release — `rm -f "$round_claim"` — deletes **what is now B's file**. C claims
1 while B is still going. Three reviews under a cap of one, reached not by a race the operator
could not see but by the documented escape hatch, and every step of it is the ordinary way this
machine is used: two gates at once is why defect 1 exists.

**Two halves, and one without the other leaves the hole reachable.** The reset now reads each
slot, extracts the pid it records, and refuses with exit 2 while any holder is alive, naming
the slot and the pid so the operator can check the claim rather than take it. And the release
is an **ownership test rather than a path test**: the slot carries a per-run token, and the
EXIT trap deletes the file only if it still contains that token. Fixing only the reset would
leave `ROUND_RESET=force` re-opening the same hole; fixing only the release would leave the
one-extra-admission A-frees-B window. The reset half is what makes the cap hold; the release
half is what makes the escape hatch safe to keep.

`kill -0` is the liveness test, and both of its ways of being wrong were checked before it was
chosen. A recycled pid makes a `kill -9`-leaked slot read as alive, which refuses a reset that
was safe. A slot owned by another user gives EPERM, which reads as dead and would permit a
reset that was not — so an unparseable or unreadable slot is treated as LIVE, and the door out
of a wrong refusal is `ROUND_RESET=force`. That ordering is deliberate: the default is the
over-refusal this file always chooses, and the permissive answer requires the operator to ask
for it by name.

**The three sentences above were false the day they were written, and defect 19 is the
correction.** "Both of its ways of being wrong were checked" describes a review that happened;
what shipped was a bare `kill -0`, and the EPERM answer given here — treat it as LIVE — was
protection the prose provided and the code did not. An EPERM pid is not an unparseable or
unreadable slot: it is a perfectly readable pid whose probe returns 1, which is the same status
a dead pid returns, so the clause meant to cover it could not reach it. Read as written it is
the worst kind of entry in this document: a defect described accurately, in the log whose
subject is claims that do not survive being checked, next to code that did the opposite.

**Why `force` is documented rather than removed.** The residual from defect 17 is that a
`kill -9` leaks a held slot, and the only way out of a leaked slot was `ROUND_RESET=1`. If the
reset now refuses while that slot reads as live, removing `force` would mean a recycled pid can
lock a branch out of reviews permanently — the escape hatch defeated by the guard added to
protect it, which is the sibling script's eleventh round exactly. So `force` exists, and the
token is what makes it cost nothing.

Both halves proved red by mutation, one per case, each on that case and no other:

| mutation | red at |
|---|---|
| drop the liveness check from the reset | the live-holder case, exit 0 |
| refuse **every** reset | the live-holder case on `force`, **and** the plain reset case |
| release by path (`rm -f "$round_claim"`) | the ownership case, slot 1 gone |

The middle row's second red is stated because it was measured rather than predicted: a reset
that never proceeds also fails the case that expects it to proceed. Refuse-all is the
trivially-satisfying wrong fix here — it makes the cap hold by making the escape hatch not
exist — so being caught twice is the right amount.

The live-holder fixture's holder is **the suite's own pid**, and that is a choice rather than a
shortcut: `$$` is definitely alive and definitely not a wrapper, so the case cannot pass by
arriving late. A fixture that backgrounded a real wrapper to hold the slot would make liveness
a race, and this file's whole subject is cases that pass for the wrong reason. The ownership
case does need a live wrapper — it is testing an exit path — so it polls for the slot file to
appear, overwrites it with a foreign token, and lets `CONNECT_CAP` kill the run; what survives
the exit is the assertion.

The generalisable part is not the pid check. It is that **defect 17's fix was reviewed, tested
four ways, written up at length, and shipped with a second instance of the same shape in the
same twenty lines** — and the write-up for 17 already said, in its own words, that a mechanism
added to stop this loop growing had grown it. That sentence was true again one round later. The
count in this file is the number found so far.

### Defect 19 — AN EPERM PID READ AS DEAD, SO A RESET WOULD CLEAR A CLAIM IT COULD NOT SIGNAL

Found by the vendor leg on the round that shipped defects 17 and 18, and it is the fourteenth
instance of an advertised bound that was not the one advertised. Defect 18's own entry is the
advertisement, three paragraphs up: it says both of `kill -0`'s ways of being wrong were checked
and that an unreadable slot is treated as LIVE. What shipped was `kill -0 "$pid" 2>/dev/null`.

MEASURED, 2026-09-02, as a non-root user on this machine: `kill -0 1` — root's launchd — exits
**1** and says `operation not permitted`; `kill -0 999999` exits **1** and says `no such
process`. **The two are indistinguishable by status**, and the status is all the code read. So a
slot held by another user's wrapper, or by a wrapper running under a different account on a
shared box, read as dead and `ROUND_RESET=1` deleted it — which is defect 18 exactly, through
the hole 18's entry said was closed. The stderr text distinguishes them and is not usable: it is
locale-dependent prose from an external command, which is the kind of decision every earlier
entry in this file argues against.

`ps -p` answers across users, so it is the second opinion: `ps -p 1` exits **0**, `ps -p 999999`
exits 1, `ps -p notanumber` exits 1. `pid_is_live()` tries the builtin first — so the ordinary
same-user path still runs no external command — and falls through to `ps -p`, calling the pid
DEAD only on exit **exactly 1**. Anything else, including a `ps` that could not run, is LIVE.
That is the over-refusal this file always chooses, and `ROUND_RESET=force` remains the door out.

**The test hole is the seventh shape again — a property every fixture shared — and it was chosen
deliberately, with the reasoning written down.** Defect 18's live-holder fixture uses `$$`, the
suite's own pid, precisely because it is definitely alive and definitely not a wrapper. It is
also, by construction, a pid the harness can always signal. Every holder in every case was
same-user, so no fixture could produce an EPERM, and the assertions were all correct. The new
case's holder is **pid 1**: root-owned, cross-user, and deterministic. It is skipped-as-pass when
the suite runs AS root, because EPERM cannot arise there and a green result would prove nothing —
that skip is shape 8, an inherited environment, handled on purpose for once instead of in
hindsight.

Mutation: `pid_is_live` back to a bare `kill -0`. Red on that case and no other, reporting
`exit 0, wanted 2 — EPERM read as dead`.

### Defect 20 — THE RESET SCANNED FOR LIVE HOLDERS, THEN DELETED, AND A WRAPPER COULD ARRIVE IN BETWEEN

Same round, same reviewer, and it is the fifteenth instance of the shape — this time reached by
timing rather than by omission. Defect 18's fix reads every slot, refuses if any holder is alive,
and then deletes. A wrapper that claims a slot **after** the scan and **before** the delete has a
live claim deleted, and everything 18 describes follows from there: a second wrapper takes the
freed slot, the first one's release finds a foreign token and correctly declines, and the cap has
admitted one more review than it advertises. Check-then-act on shared state, which is the
CWE-367 the vendor raised against the preflight's two calls, in the mechanism whose entire job is
to bound how many reviews go out.

**Fixed with the primitive already in the file rather than a new lock.** `ROUND_RESET` now creates
`$round_state/.resetting` under `set -C` *before* the scan, and the claim loop refuses while that
marker exists. The ordering argument is the whole correctness case and it is short: a wrapper that
got past the claim loop's check must have got past it before `.resetting` existed, so its slot file
already exists by the time the scan runs, so the scan sees it and the reset refuses. A wrapper
arriving after is turned away. There is no third case. **Both halves are load-bearing** — the
marker without the claim-loop check is a file nobody reads.

A stale marker is judged by `pid_is_live` and taken over, with a note on stderr. That is not
politeness: a reset killed between creating the marker and deleting it would otherwise refuse
every future run on that branch forever, which is the wedge this branch is named after, and it
would arrive as a permanent refusal produced by the guard against a transient one.

**The test hole is the tenth shape — a state no fixture constructed.** Every reset case in the
suite ran alone, so no fixture ever had a claim and a reset in flight at once. The new case
asserts the MECHANISM, not the race: it writes the marker by hand and runs a wrapper against it.
Landing a real wrapper inside a one-instruction window is a coin flip, and a fixture whose
liveness is a race passes by arriving late — which is the failure mode this whole document is
about. Both directions are asserted, because refusing on sight satisfies the first half and is
the trivially wrong fix: a LIVE marker must give exit 2 with no review, and a DEAD one must be
taken over and the run must proceed.

Mutations, one per direction, each red on that case and no other:

| mutation | red at |
|---|---|
| `if [ -e "$round_state/.resetting" ]` → `if false` | `exit 0, wanted 2 — claimed during a reset` |
| the takeover condition → `if true` | `exit 2 on a DEAD marker — a wedge, not a gate` |

### Defect 21 — THE LINT SUPPRESSION WAS HALF-ENUMERATED, AND ONLY CI COULD SEE IT

Its own class, and the sixth. `release_claim` is invoked from an EXIT trap string, which no
shellcheck version can see, so it needs a suppression — and it shipped with one code where two
were needed. **brew's 0.11.0, which is what runs on this laptop, reports SC2329 once on the
function definition. The CI runner's apt 0.9.0 reports SC2317 on every line of the body.** The
workflow runs shellcheck at its DEFAULT severity, so an info-tier code fails the job. The local
run that pronounced it clean used `-S warning`, which sees **neither** code. Local green
therefore could not predict CI green in either direction, and the `guards` job — added to this
repo one PR earlier — went red on a file this machine called clean.

The precedent was 100 lines further down, above `on_signal`, listing both codes with the reason
spelled out. Copying half of a two-item list is the entire defect. **A precedent in the same file
with the reasoning attached does not transfer itself.**

**Thirteenth blindness shape: A LINTER VERSION NO LOCAL RUN USED.** Not an absent double, not an
output mode of the tool under test that no fixture spoke — an unrun *version of the tool doing the
checking*, plus a severity threshold no local invocation used. Two knobs, either one sufficient to
hide it. `.github/workflows/tests.yml` now says so at the place someone reads when the step goes
red, including the command to reproduce its exact verdict locally (fetch 0.9.0's darwin.x86_64
asset; it runs under Rosetta on arm64), and states that the two versions are deliberately NOT
pinned to one: **two linters disagreeing is the coverage, and pinning would hide whichever code
the pin does not emit.**

Two smaller things from the same round, kept because both are the file's own subject. The first
draft of the comment explaining this began a line with the linter's own name, which shellcheck
parses as a directive rather than prose — SC1073/SC1072, errors rather than findings, which then
contaminated the next mutation run with a red that had nothing to do with the mutation. That trap
is documented nine lines above the line that fell into it — **and then it was hit A SECOND TIME,
two rounds later, in the replacement comment written to record the first, on a line beginning
`shellcheck version can see the trap call:`.** Both linters went red on that too. So the comment
now carries a sentence saying its own first draft did exactly what it forbids, which is the only
form of this note that has ever survived a round. And the paragraph above `on_signal`
used to end by saying the workflows repo stayed green because its CI did not lint these files at
all; that was true until the `guards` job landed, and the very next function added to the file
proved it false.

### Defect 22 — THE CAP'S DOCUMENTATION SAID A KILLED RUN RECORDS NOTHING, AND THE SCRIPT SAID OTHERWISE

Sixteenth instance of the same shape, in prose rather than in code, and the first where both
halves of the contradiction were already written down within a few sentences of each other. Four
documents said that a refused or killed run records nothing, so an outage cannot spend a branch's
budget on reviews it never received. A `kill -9` runs no trap, so it leaks its held slot — which
the SAME PARAGRAPH stated as a residual, one or two sentences later in two of those files. So
exit 4 advertised "`ROUND_CAP` reviews came back" and delivered "`ROUND_CAP` slots are gone", and
the operator who reads exit 4 as the signal to stop and report what is open was reading a number
that is short by however many wrappers had been SIGKILLed. `dotfiles/claude/CLAUDE.md` went
furthest and said exit 4 means "at least three local reviews on this branch", called it a floor on
the count, and was a floor on the *claims*.

Fixed in `.claude/skills/review-plan-v2/SKILL.md`, `STATE.md`, and `dotfiles/claude/CLAUDE.md` in
two places: a refused run records nothing, a run killed by a signal its trap can see drops its
slot on the way out, `kill -9` is the exception because no trap runs, and exit 4 means the slots
are gone. **No test caught it and none could**: the two checks that read this file's own prose
were deleted the day it became a document, which the header states as the weaker guarantee it is.

The same round deleted "roughly one defect per ten executable lines of that wrapper" from
`STATE.md`, three words to the left of the clause "no count is written here". A rate is a count
with a division in it — it needs both numbers to stay true — and it had replaced an absolute
count that went stale inside a day, on the round that deleted the same figure from four other
files. That is two rounds in a row spent on a number in a sentence forbidding numbers.

### Defect 23 — EVERY NON-EMPTY `ROUND_RESET` CLEARED THE BRANCH, INCLUDING THE ONE THAT SPELLS "OFF"

Seventeenth instance of the same shape, and the value that states it is `0`. Admission was gated
on `[ -n "${ROUND_RESET-}" ]`, so `ROUND_RESET=0` — which reads as "off" to whoever writes it, and
is how every other switch on this machine spells "off" — DELETED the branch's claimed slots and
let the cap start over from one. So did `ROUND_RESET=yes`, `=no`, `=false`, and every misspelling
of `force`. The cap advertises three rounds per branch; a `0` an operator wrote to mean "leave the
cap alone" gave unlimited rounds instead, silently, with a note saying the count had been reset.

Worse than the other sixteen in one specific way, which is why it is not filed as a nit: every
earlier instance of this shape produced a wrong ANSWER, and this one produced wrong STATE. A
refusal that arrives late can be re-run; a deleted claim cannot be un-deleted, and the wrapper
that was holding it is still reviewing. So the fix is a whitelist rather than a blacklist — only
`1` and `force` are reset requests, everything else is exit 2 naming the value it would not guess
at — for the reason the sibling guard's `path_filters` allowlist exists in `team-aibo`: a
blacklist of "values that do not mean reset" fails open on the next one somebody invents.

**AN EMPTY VALUE STAYS OFF, and that asymmetry is argued rather than inherited.** Every cap in
this script refuses a set-but-empty value, because an empty `TOTAL_CAP` silently drops a bound the
operator tried to set. `ROUND_RESET=` is the opposite: empty does exactly what the operator's
bare `=` reads as, and refusing it would turn a harmless keystroke into a gate that will not run.
Same family as `${VAR:-default}` versus `${VAR-default}`, decided in the other direction, on
purpose, with the reason written next to the `case`.

**Seventh test shape, recurring: A KNOB EVERY CASE SHARED.** Four reset cases existed and every
one of them passed `ROUND_RESET=1` or `ROUND_RESET=force` — the two values the code handles — so
the suite exercised the whole reset mechanism without ever asking what a THIRD value does. That
is defect 11's blindness exactly (`POLL=1` in both signal cases), and the round that fixed 19 and
20 wrote four new cases into that same block without noticing the parameter they all set the same
way. The new case runs three probes: `0` and `yes` must exit 2 with the slot file still on disk,
and `ROUND_RESET=` must review normally, because "refuse everything that is not 1 or force" is the
available wrong fix and it satisfies a two-probe case. Mutation-proved 2026-09-02, and the second
mutation is the more instructive: accepting every value is red on that case ALONE, while removing
`''` from the accepted set is red on THIRTY-SIX cases, because `ROUND_RESET` is unset in almost
every case in the suite and unset expands to empty. So the empty probe is a statement of the
documented asymmetry, not the only thing guarding it — and the 36-case red is the honest shape of
that fact rather than a tidier one.

### Defect 24 — THE STALE-MARKER TAKEOVER WAS AN OVERWRITE, SO TWO RESETS BOTH PROCEEDED

Eighteenth instance of the same shape, and it is DEFECT 20 REACHED THROUGH ITS OWN REPAIR, in the
round that shipped that repair. Defect 20's fix put a `.resetting` marker in the state directory
so a claim arriving mid-reset is refused instead of landing on a slot about to be deleted, and it
handled the marker a dead reset leaves behind by taking it over — with a plain `printf` over the
path. So two resets that both judged the same marker stale both wrote it, both proceeded, and the
first to finish deleted the marker by PATH while the second was still scanning slots. The claim
loop then opened mid-reset, which is precisely the hole defect 20 was written to close, so the
cap could be breached by exactly the sequence the fix advertised as closed.

Two changes, and the second is the one the correctness argument rests on. The takeover is now
`rm` plus an exclusive `set -C` create, so exactly one of two racing resets creates the file and
the loser refuses with exit 2 rather than proceeding. And the marker is dropped by an OWNERSHIP
test — the reset writes `pid <pid> token <token>` and deletes only a marker still carrying its own
token — which is the same discipline the slot release already used after defect 18, one file over
in the same script. That is what makes the residual harmless rather than merely narrow: in the two
syscalls between one reset's create and its trap, a racing reset can replace the marker, and then
ITS marker is the one standing, so SOME marker exists for the union of both resets and the claim
loop stays shut for as long as either runs. A path delete breaks that invariant. An ownership
delete cannot, so exclusivity is belt and the token is the mechanism.

**No blind test, for the same reason as 17 and 18: the block was three days old and had no case
that reached its takeover path at all.** Both new cases are deterministic rather than raced, which
matters more here than anywhere else in the suite — the failure is a window two syscalls wide and
a fixture that tries to hit it by timing would pass on a slow machine and prove nothing. A no-op
`rm` first on PATH makes the remove half do nothing, so the exclusive create must fail on a file
that is still there: the same state a racing reset leaves, arrived at by arithmetic. And a `seq`
shim fires once, on the reset's own slot scan, planting a marker owned by a LIVE pid — the one
command the reset runs between its create and its drop, so the window is entered by construction.
Mutation-proved 2026-09-02, one red case per mutation and no collateral: dropping `set -C` from
the re-create is red on the first, and making the drop a path delete is red on the second.

One detail worth keeping, because it is defect 13's lesson landing in my favour for once. Under
the non-exclusive mutation the run still exits **2**, for an unrelated reason — the no-op `rm`
also defeats the marker drop, so the wrapper's own live pid then shuts its own claim loop. A case
anchored on the status alone would have scored green on the bug. What caught it was the assertion
on the SENTENCE the refusal produces, and `cannot be replaced` is greped rather than `stale`
because the SUCCESS note says "took over a stale reset marker" and would satisfy the looser
anchor.

### Defect 25 — THE CLAIM SIDE CLEARED THE MARKER BY PATH, SO IT DELETED A LIVE RESET'S

Raised by the vendor leg on the round that shipped 23 and 24, in the block the round before that
one had written, and it is the same defect as 24 on the side of the protocol I did not touch. The
claim loop refuses while `.resetting` exists, and clears the marker when its pid is gone. It read
the marker, judged it stale, and then unlinked **whatever held that name**. Between those two
steps a new reset can take the same stale marker over — the takeover path removes and re-creates
it, which is 24's own fix — so this wrapper deleted a LIVE reset's marker and then walked straight
into the claim loop with the gate open. That is the one state the marker protocol exists to
prevent: a reset scanning slots while a wrapper claims one, which is defect 19 reached through the
mechanism added to close it. NINETEENTH instance of the shape, in the direction that breaches the
cap rather than the one that over-refuses.

**The argument against it was already written twenty lines up, by me, in the commit under review.**
Defect 24's entry says a path delete breaks the invariant and an ownership delete cannot, and the
round that wrote that sentence applied it to the reset's own drop and left the identical unlink on
the reader. Not a limit anyone stated, not a trade-off anyone weighed — a second call site nobody
enumerated, which is defect 8's shape (a fixed bug returning because the fix was only
half-enumerated) landing on the reasoning rather than on the code. The fix is symmetric with 24's:
re-read the marker immediately before the unlink and delete only the bytes that were judged. Any
other content means it changed hands, and the honest answer is the refusal the block already has
for a live holder rather than a guess — exit 2, nothing claimed, NO VENDOR REVIEW HAPPENED.

**THE TENTH TEST HOLE AGAIN — A STATE NO FIXTURE CONSTRUCTED, for the third time** (defects 14
and 20 were the other two; 19's hole was the seventh shape, a property every fixture shared, and
THIRTEENTH is defect 21's linter version. A recurrence keeps the original number, as 19, 20 and 23
each do; giving one a fresh ordinal is how the count of shapes drifts, which is this file's own
subject). A case *did* exercise this exact block — `a claim mid-reset is refused,
and a dead marker is taken over` — and it plants a dead marker that stays dead, so the read and the
delete see the same bytes and a path delete is indistinguishable from an ownership delete. Nothing
in the fixture was wrong; the state where the marker changes owner mid-clear simply was not among
the states any fixture built, and reading the assertions would never show it. The new case enters
that window by construction rather than by racing: a stale pid sends `pid_is_live` past `kill -0`
to its `ps -p` second opinion, which is the only external command that runs between the read and
the unlink, so a `ps` shim plants a marker owned by a LIVE pid there and then answers 1 — the only
status meaning "gone" — leaving the stale verdict intact and the delete as the only thing under
test. Mutation-proved 2026-09-02: reverting the content check to the bare `rm -f` is red on that
case alone, reporting `deleted a live reset's marker by path`, and the full matrix re-run in the
same session keeps one red case per mutation with no collateral.

Two smaller findings from the same round, both accepted, neither its own defect. The exit-4 rule in
`dotfiles/claude/CLAUDE.md` stated the cap's numbers as facts when they are the **default** — the
same docs offer `ROUND_CAP=6` — so it now names the variable and says which figure is the default.
And the EPERM case counted its root skip as a PASS while the read-only-state-dir case reported
`SKIP`; a check that did not run reading as one that ran and succeeded is this file's entire
subject, so it reports `SKIP` and bumps no counter. The suite's own total moves for that reason
as well as for the new case, which is the point of never writing the total down anywhere but the
run.

One thing this round did NOT fix, and it is the honest kind of residual rather than a stated limit
that could be closed for free. The suite's own deterministic fixture for 24 uses a no-op `rm` first
on PATH for the whole wrapper run, so a slot-survival assertion in that case cannot go red whatever
the script does. The vendor leg caught it; the assertion is deleted with a comment saying why,
because the alternative — scoping the shim to one call site — would make the case race the thing it
is meant to enter by arithmetic. What is lost is coverage that case never had; what is removed is
an assertion that read as coverage, which is worse than nothing.

### Defect 26 — 25'S OWN FIX NARROWED THE WINDOW AND CALLED IT CLOSED

Raised by the vendor leg on the round that shipped 25, against the fix in 25's entry, and it is the
plainest statement of what this file keeps getting wrong: **the re-read moved the gap, it did not
remove it.** Read the marker, compare it to what was judged, unlink it — and between the compare and
the unlink a new reset can take the same stale name over, exactly as it could between the judge and
the unlink one round earlier. The `rm` then removes a LIVE reset's marker and the claim loop is open
for every wrapper that arrives while that reset scans, which is the state the whole protocol exists
to prevent. TWENTIETH instance of the shape, in the direction that breaches the cap, and reached for
the fourth time through the repair written for the third.

**Why the fix was wrong is more useful than that it was wrong: POSIX shell has no unlink that can
check what it is unlinking.** `[ "$(cat …)" = … ] && rm` is two syscalls with a window between them
by construction, and no amount of tightening removes the window because the window IS the
construction. The obvious escape is `mv`, and it fails for a reason worth writing down: an atomic
rename moves whichever inode currently holds that name, so it steals a live marker just as readily,
and there is no un-racy way to put it back — `mv -f` onto `.resetting` would clobber whatever the
competing reset had just exclusively created. Every version of "delete the right one" has this
shape. **A window narrowed twice is a defect described twice.**

So the fix is not a better delete. It is ONE FEWER WRITER: marker mutation now belongs only to the
reset path, which already serialises it with `set -C` and an ownership token, and the claim path
**ignores** a stale marker instead of clearing it. Ignoring costs nothing, and the argument is one
line — the holder is dead, so nothing is scanning, so a claim made under that marker is a claim made
with the door shut against nobody. It is cleared by the next reset's takeover, which is the one
writer allowed to touch it. Two things are given up on purpose. A stale marker can outlive its owner
until someone runs a reset, so every run says so out loud rather than tidying it away silently. And a
claim can still be made moments before a reset's marker appears — which is not new, is exactly what
happens if the claim lands one instant earlier, and is what the reset's own live-slot refusal exists
to catch. Under `ROUND_RESET=force` that refusal is skipped, which is what `force` MEANS and is
documented where it is offered; the residual belongs to force, not to the marker.

The re-read survives the delete it was written to guard, because it turned out to be worth more than
that: a marker that changed hands between the liveness test and the re-read means a reset is live
NOW, and the honest answer is the block's existing refusal rather than a claim made on a verdict that
has expired. Same code, different job, and the case that pins it kept its assertions and lost its
name — it was `a stale marker that changes hands mid-clear is not deleted`, and there is no clear to
be mid-way through any more.

**FOURTEENTH TEST HOLE, AND IT IS THE REVIEWER'S OWN INSTRUCTION: A WINDOW NO FIXTURE ENTERED.** 25's
new case lands between the liveness test and the re-read, which is the gap the re-read closes; the
gap the re-read cannot close opens the instant it returns, and nothing landed there — so the fixture
proved the guard worked everywhere except where it did not exist. The reviewer said to extend the
fixture to replace the marker after the final content read, and that is the case: `cat` is external,
the claim path reads the marker exactly twice, so a `cat` shim serves the first read untouched,
serves the SECOND — the re-read — and replaces the file immediately after, leaving the wrapper past
every look it will ever take. The assertion is the marker, not the exit: it must still be there,
still owned by the intruder, and the run must proceed, because a stale marker is to be ignored rather
than obeyed. Mutation-proved 2026-09-02: adding a bare `rm` back after the re-read, with everything
else including the notes left intact, is red on that case ALONE — `deleted a live reset's marker
planted after the last read` — and deleting the re-read instead is red on the case above it plus that
same case's fixture guard, which reports `1 read(s) of the marker` rather than a false pass.
