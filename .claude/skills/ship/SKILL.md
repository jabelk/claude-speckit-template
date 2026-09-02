---
name: "ship"
description: "Ship the current change: CodeRabbit-style self-review, unpiped gates, PR, batched review round, merge, per-project promote/verify. The shipping half of /feature, usable standalone for small fixes."
argument-hint: "Optionally describe the change being shipped"
compatibility: "Git repo with a remote, a PR system (GitHub), and CI; promote/verify steps are read from the project's CLAUDE.md (stops at merge if none defined)"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
# The fleet default became `false` on 2026-08-28 — a skill Claude cannot reach is
# a skill Claude will not use when it should. /ship is the one declared
# exception, and stays slash-command-only: it merges PRs, pushes branches, and
# runs a project's promote/deploy steps. Those are externally visible and hard to
# reverse, which is the one category that must not fire on a model's judgement
# that the moment looked right. Enforced by scripts/assert-skill-invocation.sh
# (KEEP_DISABLED), which carries the same reason.
disable-model-invocation: true
---

# Ship

Drive the current change from working tree to merged — and promoted, where the project defines a pipeline. Two entry paths, identical steps:

- **Standalone** (`/ship`): small fixes and chores that don't need the spec ceremony.
- **From `/feature`**: Phase 6 delegates here. Shipping mechanics live in THIS skill only — if shipping behavior needs to change, change it here, not in `/feature`.

## Phase 0: Preflight

1. Never ship from `main`, `staging`, or any long-lived branch. If you're on one, create a `fix/` or `chore/` branch first.
2. Standalone bug fixes are TDD: write the FAILING test first, confirm it fails, then fix. Skip only for pure docs/config changes — and say you skipped it.

## Phase 1: Self-review the diff — CodeRabbit-style pass

Walk the diff against these patterns before opening the PR. Each PR-side review round costs real user attention — catch these yourself:

- **try/except scope**: covers *all* error-raising paths, including early-return branches (not just the happy path)
- **Leaked secrets/URLs in logs**: signed URLs, tokens, API keys, PII in debug/log statements
- **Vacuous tests**: tests that pass regardless of the code under test (e.g. `assert True`, assertions on empty response bodies); assert user-visible state, not just request shapes
- **Missing edge cases**: empty collections, None/null, timezone boundaries, idempotency on retry paths
- **Duplicated magic constants**: same value in two files → extract a helper
- **Shell pipeline safety**: `set -euo pipefail` in scripts, API keys in URLs, secrets/PII in external calls
- **Doc consistency**: README / CLAUDE.md / specs still match the code

## Phase 2: Gates — unpiped

1. Run the project's lint, format, and test commands as SEPARATE, UNPIPED commands. Pipes mask exit codes — a `cmd | tail` that "passed" has shipped red CI before. If piping is unavoidable, `set -o pipefail` or check `${PIPESTATUS[0]}`. Every gate must exit 0.
2. `git status --short` and `git diff HEAD --stat` — the plain `git diff` misses staged and untracked files; confirm no unintended changes anywhere in the tree.
3. **The local review gate is in Phase 3, after the commit — not here.** `review-plan-v2` defaults to `--type all`, and `all` is the **committed** diff (`$BASE...HEAD`), identical to `--type committed`; run at this point it reports `reviewing 0 of 0` and exits 0 on a change it never looked at. An earlier version of this skill asked for it here and then said to commit first, which is not satisfiable in this phase order. Its sibling leg sends the diff to a vendor and the secret scan lives in the leg that needs the commit, so splitting them across the commit would put the egress before the scan. This step said the tool "has no working-tree mode" until 2026-08-29, which was false — `--type uncommitted` is one. It does not rescue the phase order: measured on 2026-08-29, `uncommitted` maps to plain `git diff`, so it reads unstaged changes only and reviewed neither a staged addition nor an untracked file in the same tree.
4. **Web-UI changes get a browser walkthrough, unprompted.** If the change touches anything rendered in a browser, walk the affected flows as a user would (Claude in Chrome when available: navigate, click, fill forms, read the rendered result). API-level smoke tests verify the API, not the feature — they do not satisfy this gate.

## Phase 3: Commit + PR

1. Stage and commit the change (`git push` sends commits, not working-tree edits — standalone `/ship` starts from an uncommitted tree). Verify the tree is clean after committing.
2. **Now** run the local review gate, after the commit and before the push — the PR-side review is the safety net, not the first pass. Both legs, in this order:

   ```bash
   BASE=main   # the project's default branch; `staging` where it has one

   scripts/preflight-vendor-review.sh \
     && review-plan-v2 --static-only --plain --base "$BASE" \
     && scripts/preflight-vendor-review.sh \
     && scripts/bounded-vendor-review.sh --base "$BASE" --include-untracked
   # preflight twice on purpose: once to fail fast, once immediately before the send
   # `--plain` belongs to review-plan-v2 only (`[--plain | --agent]`). `coderabbit`
   # has no such flag; plain text is already its default. Do not carry it across.
   # bounded-vendor-review is `coderabbit review` with a clock on it — never the bare
   # CLI, which has no timeout of its own and can sit silent indefinitely.
   ```

   The order matters, and so does the `&&`. gitleaks runs in the first leg and nothing leaves the machine there; the second sends the diff to a vendor. A secret scan after the egress cannot prevent anything — and on two separate lines a failing scan does not stop the send either, which is the same hole with a shell prompt in the middle of it. Chained, any actionable static finding blocks the vendor leg until it is fixed; that is intended. **Never run `review-plan-v2` without `--static-only`** — its AI reviewer legs were retired on 2026-08-28. Set `BASE` once rather than typing the branch per command: the fallback below takes the same base, and a fallback that hardcodes `main` on a staging repo diffs the wrong range and still exits 0.

   Read the `reviewing N of M changed file(s)` line, not the exit code: `[NOTHING REVIEWED]` or `reviewing 0 of N` also exits **0**, and on an uncommitted tree or a wrong `--base` that is a clean-looking gate that checked nothing.

   **The two legs do not share exit-code semantics, so do not gate on the number for both.** `review-plan-v2` has three tiers (`0` clean, `1` actionable, `2` tool error); `coderabbit` has one non-zero code for everything. Verified on 0.7.5 on 2026-08-29: an unknown flag gives `error: unknown option` at exit **1** — and `--plain` is one of them **on `coderabbit`**, where plain text is already the default; it is a real flag on `review-plan-v2`, which is why the block above passes it to one binary and not the other, running outside a git repository gives `Error: Git repository not found.` at exit **1**, and "found actionable issues" is also exit **1**. Two of those three mean the reviewer never ran, so read the first line of its output. And `coderabbit auth status` has to show an account — an installed-but-signed-out CLI is a binary that cannot review.

   **The untracked check is a script rather than nine lines in this block, and it has taken twelve review rounds in total — seven in this file, five more after the move.** From 2026-08-29 to 2026-08-31 the guard lived here as shell inside the fence above. In that window CodeRabbit caught, in order: the missing `if` (its clean result is `grep` exiting 1, so the outcome you want looks like failure); the fail-open capture, where `if git status | grep '^??'` reports *grep's* status and a failing `git status` leaves grep reading empty input, exiting 1, and the proceed branch running — the guard reporting a clean worktree exactly when it could not see the worktree; two other copyable blocks with no guard at all; the attempted fix of annotating those blocks with a comment saying the guard still applied, which is a note about what you should have run rather than a check on what you did; a bare `exit 2` that killed the *user's* shell when pasted interactively; the `SIGPIPE` fail-open, where `printf | grep -q` under `pipefail` reports 141 and the guard proceeds *because* it found too many untracked files to finish listing them; and the window between one check and the send, which is the whole runtime of leg 1 — where an editor autosave, a build artifact, or a second agent session in the same worktree lands a file that `--include-untracked` then ships unscanned.

   Every one of those fixes was correct and every one left the next hole. A shell fragment in a Markdown file has no mechanism to be wrong out loud: nothing executes it, nothing tests it, and every reader is free to paste half of it. So the guard is `scripts/preflight-vendor-review.sh`, which carries every round in its header and fails closed on each of them, and `scripts/test-preflight-vendor-review.sh`, which hands it a dirty worktree, an edited tracked file, a directory that is not a repository, a path that does not exist, a broken helper, each of git's four location variables one at a time, and 20,000 untracked files, and fails if any of them passes. The bulk case asserts its own fixture still discriminates, because the retired form only falls open above a byte threshold — the 64 KiB pipe buffer, bisected 2026-08-31 at 61,893 bytes correct versus 70,893 fell open — so the same test at a few thousand files would pass against the broken implementation and read as proof. If a project does not carry the script, that is the gap to close before running the gate, not a line to paste back into this file.

   **Five rounds landed after the move, and none was a repeat** — the three below, then the eleventh and twelfth in their own paragraphs. This sentence said four until 2026-09-01, one round after the twelfth landed, which is the same stale-count class the bounded suite's header check exists for and a reminder that a summary line is a claim like any other. The eighth *widened* what the guard rejects: it checked `^??` alone until 2026-08-31, on the reasoning that a tracked file's edits are already reachable by gitleaks, and they are not — leg 1 diffs `$BASE...HEAD`, so a staged credential in a tracked file was read by no scan in the gate and the guard passed it without comment. It now refuses any dirty entry, which costs nothing where the commit prerequisite is honoured. The ninth was a fail-open from the environment: with `GIT_DIR`/`GIT_WORK_TREE` exported, `git status` inspected *that* repository regardless of the directory the script entered, while the success line still named the directory it was pointed at — reproduced 2026-08-31 as `clean worktree in .../dirty` at exit **0**, aimed at a tree holding an unscanned untracked file. Git exports those variables to every hook it runs, so wiring this gate into a pre-push hook would have armed it; The tenth round found that unsetting them, which is what round 9 did, protects that one process and nothing else: the gate is an `&&` chain, so `review-plan-v2` and `coderabbit review` run in the caller's shell and inherit the variables anyway, and the vendor leg can then enumerate a repository the guard never inspected. A child cannot unset a variable in its parent, so the script now **refuses** — exit 2 while any of `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, or `GIT_COMMON_DIR` is set, naming the offenders and pointing at `env -u ...` for a caller that needs them or at the `REPO_ROOT` argument for one that only wanted to aim the script somewhere. That round also gave `GIT_COMMON_DIR` its first test case (the docs had claimed all four were covered) and replaced a vacuous `GIT_INDEX_FILE` case that used an empty index file, which `git status` rejects at exit **128** as `index file smaller than expected`, so it had been passing through the fail-closed path for unreadable repositories rather than testing the variable. The suite reached 24 cases at that round, seen red on exactly the seven environment cases and nothing else.

   **An eleventh round fixed the refusal's own advice, which could defeat the refusal.** `env -u ...` applies to the command it prefixes and nothing else, so a caller told only to "use `env -u`" writes it on `preflight-vendor-review` and leaves the vendor leg inheriting the variables — the guard beaten by following its own instructions. Measured 2026-08-31 with `GIT_DIR` exported: the prefix on the first command of an `&&` chain gave `leg1 sees: unset` and then `leg2 sees: /tmp/other-probe-repo/.git`, while `env -u ... bash -c '<chain>'` gave `unset` for both. The refusal now leads with `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR` in the caller's own shell, shows the wrapping form second, and says outright that a prefix on one leg covers only that leg. A 25th test case asserts that wording, because advice which defeats the guard is part of the guard; seen red on that one case by replacing the wrapping form with a bare `env -u` mention.

   **A twelfth round: an explicitly EMPTY value walked through the refusal, and nine of its own assertions could not have caught it.** The test was `[ -n "${!v:-}" ]`, which is blind to a set-but-empty variable, and the note here said that case was covered by the `unset` below the refusal — round 10's mistake restated, since the unset fixes one process while the rest of the gate runs in the caller's shell. So `GIT_DIR= <the gate>` passed and the vendor leg inherited it. Empty is not equivalent to unset and it is not harmless: measured 2026-09-01, `GIT_DIR=''` gives `fatal: not a git repository: ''` at 128 and `GIT_WORK_TREE=''` gives `The empty string is not a valid path` at 128, so git *breaks* rather than reading elsewhere, while `GIT_INDEX_FILE=''` does not error at all and makes git report every tracked file as `D` deleted — which contradicts the `/tmp/empty` measurement above and is why the empty string needed its own case. Fix is `[ -n "${!v+x}" ]`: ask whether it is *set*. The test defect was the larger one. Nine assertions greped the output for the bare variable **name**, and the refusal prints `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR` as advice on *every* refusal, so the substring was there whichever variable was actually set. Proof rather than argument: strip `$poisoned` from the refusal's first line so it names nothing, and the bare-name form scores green with zero failures, while the tightened form matching `environment: $v` after the colon is red on nine, one per assertion. Grep for the *sentence* the check produces, not for a token that also appears in its advice. Suite reached 29 cases at that round.

   **The wrapper's operator rules, first, because the paragraph under them is history and
   this is what you need while a gate is running.** A long run of defects has been found in
   `bounded-vendor-review.sh`, and these are the ones that change what an operator does:

   - **Run the wrapper, never the bare `coderabbit review`.** The CLI has no timeout of its
     own: on 2026-08-31 it hung twenty minutes at the WebSocket connect and gave no warning.
   - **`CONNECT_CAP` defaults to 120s and `TOTAL_CAP` to 900s** — both are variables; raise
     `TOTAL_CAP` on a large diff. Set one, never blank it: an empty value is a refusal at
     exit 2, not the default.
   - **Exit 3 means NO REVIEW HAPPENED.** Not 1, which the CLI spends on unknown flags,
     non-repositories, and real findings alike.
   - **Exit 4 means the branch is out of vendor rounds** — `ROUND_CAP` (default 3) per
     directory and branch, claimed before each review rather than counted after it. It is
     not exit 3 because 3 is a vendor or session problem you retry, while 4 says another
     round is the wrong move and a human should look. Report what is still open and let the
     operator decide; raising the cap to get past it is the one response that defeats the
     point. `ROUND_RESET=1` is for a branch now doing different work, and it refuses while
     any slot is held by a live pid — a `kill -9`'d wrapper leaks its slot, which refuses a
     round early rather than admitting an extra one, and `ROUND_RESET=force` is the door out.
   - **Exit 1 from the wrapper means the wrapper broke, never "found something."** On any
     copy, treat a 1 as a bug in the wrapper.
   - **Read a refusal's wording as a claim to check, not as a diagnosis.** The exit status
     has been the reliable half throughout; the message has been wrong twice. An exit 3
     blaming the connect phase in particular: read the reviewer output the refusal prints,
     and if it shows a later phase, the vendor was working and the wrapper was wrong.
   - **Read the phase out of the labelled `reviewer stdout` section, not off the bottom of
     the block.** Until 2026-09-01 the refusal concatenated the two captures by file, so a
     stale connect-phase line from stderr sat below every later phase from stdout — under a
     sentence telling you the last phase was "above". On a copy predating that fix, the last
     line of that block is not the run's last phase.
   - **On a copy predating 2026-09-01, an exit 3 under `--agent` says nothing at all.** The
     detector read the prose progress stream, which that mode does not emit, so *every*
     findings run was refused as a review that never happened. Scoped by count on
     2026-09-01, because the first write-up of that defect overstated it: of the wrapper's
     five documented invocations across both repos, one passes `--agent` — the agent-mode
     chain in `review-plan-v2/SKILL.md`. The primary gate command in this file and in that
     one omits it. So this applies when you passed the flag, and the reason it is worth a
     bullet anyway is that the CLI itself prints
     `Notice: Detected claude environment. Use 'coderabbit review --agent' ...` on every
     run inside an agent session — it recommends the mode to exactly the caller most
     likely to be running this wrapper.
   - **If you parse the vendor leg, parse only its stdout.** The wrapper's own messages are
     all on stderr, and stdout carries the reviewer's stdout and nothing else.
   - **After killing a gate by hand, give it a moment, then run
     `pgrep -fl 'coderabbit review'`** and confirm the parent is dead before calling
     anything an orphan.

   Where each of those comes from: **`scripts/vendor-gate-defect-log.md`, beside the script.**
   Every bullet above is one entry in it, with the measurement behind it and the test hole
   that let it through. The account is written down once, there — it used to be restated in
   five places, and two whole review rounds went on stale summary counts in those copies
   contradicting the enumeration beneath them, so no count and no list of defect numbers is
   repeated here. Read it before changing the wrapper or its suite, and add to it rather than
   summarising it somewhere else. Two things from it generalise past this wrapper and are
   worth carrying into any gate you write: **a check whose failure is indistinguishable from
   its success is not a check**, and the vacuity that hid most of these was in the fixture,
   the harness, an inherited environment, an output mode no fixture ran, a reader no
   assertion modelled, or the assertion's anchor — never in the assertion's logic.

   **On exit 3 the branch has had no local vendor review, and the honest report names which review it did get.** The PR-side CodeRabbit review runs server-side between GitHub and the vendor, never touching this machine — verified 2026-08-31, when two PRs got full reviews while the local CLI hung on every invocation — and it sees more than the local leg (whole PR diff, cross-document context, earlier rounds). So push, let the PR-side review be the vendor review, and say in the PR that the local CLI leg did not run. "Gate clean" after an exit 3 is the one report that makes the wrapper pointless. An exit 3 dated before 2026-09-01 may also have been a *false* refusal, since the connect detector then read the CLI's log file rather than its stdout and killed healthy reviews; read the reviewer output the refusal prints rather than trusting the verdict.

   **Calling it twice narrows the check-to-send window and does not close it.** A concurrent writer can still land a file between the second call's exit and the moment the vendor process enumerates the worktree — CWE-367, raised by CodeRabbit on 2026-08-31 and real. This file previously called that window "one process spawn", which is NOT VERIFIED and probably false: the CLI's `Connecting to CodeRabbit...` phase has run past five minutes on this machine and whether it enumerates before or after connecting is unknown, so the honest bound is "unknown, possibly the whole connect phase." Dropping `--include-untracked` would close the race and is declined deliberately, because it makes a file you forgot to `git add` invisible to the review, so its omission reads exactly like a clean pass — the failure class the guard exists to remove, one layer out. The mitigation left is the caller's: do not write into the tree while the gate is running.

   The bar is not "nothing belonging to the change" — nothing at all. `--include-untracked` sends every non-ignored untracked file in the worktree, so scratch notes, a pasted credential, or an unrelated data export go to the vendor along with the diff, and deciding what "belonged" is a judgement made after the send. Commit what should be reviewed and `.gitignore` or move what should not. The flag stays as a backstop that should then find nothing; `gitleaks dir . --redact` scans the working tree locally if you need that answer before committing.

   **`--redact` on every gitleaks command you run, because a gate that prints the secret it found has published it.** Without it a finding's `Secret:` line carries the credential in full, into whatever holds that output: a CI log, a scrollback buffer, an agent transcript, a pasted-into-chat "here is what the scan said." It is `--redact uint[=100]`, defaults to 100%, and exists on both the `git` and `dir` subcommands (verified on 8.30.1). The detail only prints with `-v` at all — plain `gitleaks git` prints `leaks found: N` and nothing more — so the exposure arrives the moment someone adds `-v` to find out *which* file, which is also the moment they are most likely to paste the output somewhere.

   **If the static leg is unavailable, do not run the vendor leg on its own** — that ships the diff with no secret scan in front of it. Chain them so a leak actually stops the send, and lead with the same guard, because gitleaks substitutes for leg 1 and not for the preflight: `scripts/preflight-vendor-review.sh && gitleaks git --log-opts="$BASE..HEAD" --redact && scripts/preflight-vendor-review.sh && scripts/bounded-vendor-review.sh --base "$BASE" --include-untracked`, using the same `BASE` set above. Writing it as a comment saying "the preflight above still applies" was the earlier fix here and CodeRabbit rejected it — a note telling a reader what they should have run is not a guard on what they did run, and this line is copyable and complete on its own. On separate lines a non-zero gitleaks exit does not prevent the next command. If gitleaks is missing too, stop and say the gate cannot run.

3. Address what the gate surfaced, and route it by KIND — the remedies are not interchangeable:
   - **A gitleaks hit is not a follow-up-commit fix.** A later commit that deletes the credential leaves it intact in the earlier commit, and `git push` sends the whole branch, so the secret reaches the remote regardless. Treat it as a live disclosure: **rotate or revoke the credential first**, on the assumption it is already compromised, then remove it from the unpushed history (`git commit --amend` if it is the tip, an interactive rebase or a fresh branch otherwise) and re-run the scan on the rewritten range before pushing anything. History rewriting is destructive and `CLAUDE.md` says to discuss it first, so raise it with the user and get explicit approval before rewriting anything, then confirm the branch is not shared and the work is recoverable — and if the commit was already pushed, rotation is the only remedy that still works. Rotating the credential does **not** need that approval and should not wait for it; it is the step that stops the disclosure, and the rewrite only tidies the history afterwards.
   - **Everything else** (lint, and CodeRabbit's findings) gets a normal follow-up commit on this branch before the push.

   **Then re-run step 2 against the new HEAD.** The gate reviewed the pre-fix commit, so a follow-up commit is unreviewed code by definition — and a fix commit is a normal place to add a file, paste a credential, or regress something the first pass cleared. Repeat until a run over the final HEAD is clean. That is also the honest answer to "the gate passed": it passed on the commit you are pushing, not on an earlier one.
4. Push the branch and open a PR against the project's **PR target**, which is not always the default branch: the base the project's CLAUDE.md (or its `/feature` skill) names for feature work — e.g. `staging` on repos where `staging → main` is a separate promotion — else the default branch. Standalone `/ship` runs follow the same rule; never target `main` just because it is the default. This is the same value as `BASE` in step 2, so a wrong answer here also means the gate diffed the wrong range and passed on it.
5. Wait for CI green. Poll on a paced loop; don't block synchronously.

## Phase 4: Review round — batched

1. Enumerate EVERY unresolved review comment (CodeRabbit and human) in a table first: comment | real bug? (yes/no, one-line why) | planned fix.
2. Fix all the real ones in ONE commit. Decline the rest with a brief stated reason (vendored content, intentional style, out of scope).
3. Before pushing the batch, re-run the tests covering behaviors fixed in EARLIER rounds of this PR — hardening passes have regressed prior fixes before.
4. Iterate only on genuinely new findings. Round 3+ is a signal something upstream is wrong (missing local review pass, config drift) — surface it instead of grinding.

## Phase 5: Merge, promote, prove

1. Merge when CI is green, no actionable threads remain, AND the repo's merge requirements are satisfied — check mergeable state, required human approvals, and branch-protection rules; green CI alone does not prove mergeability. Projects may define stricter merge gates of their own (e.g. autonomous runs leave the PR as a draft and merge only in interactive mode) — those gates take precedence over this step. Squash unless the repo prefers otherwise. NEVER delete branches — feature branches are preserved, and long-lived branches (`main`, `staging`) must never be deleted.
2. Read the project's CLAUDE.md for its promote/verify pipeline (e.g. staging promote → verify → prod promote → verify-production). The pipeline definition is a trust boundary: resolve it from the default branch, and if THIS PR modified the promote/verify instructions, get explicit human approval before executing them. If defined, execute the steps in order, stopping at any step the pipeline marks as user-gated (e.g. a staging → production promotion that requires explicit approval) — a gated step is proposed and waited on, never auto-executed. For web-UI changes, the staging/prod verify includes a browser walkthrough of the affected flows, not just API checks. If no pipeline is defined but the repo has an automatic deploy on merge (e.g. a workflow triggered by push to the base branch), wait for that workflow and report its result — the merge is not "shipped" while its deploy is red. If neither exists, stop at merge and say so — do not invent a deploy.
3. Close linked issues with evidence.
4. **Every "verified" claim cites the command run, its exit code, and its output — redacted.** Strip tokens, signed URLs, PII, and production data before quoting output; if output can't be safely redacted, cite the exit code and a one-line summary instead. Browser-walkthrough evidence names the environment, the flow exercised, and the observed result (screenshot/artifact reference where available). If a check wasn't actually run, write NOT VERIFIED — never infer.
