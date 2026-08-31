---
name: review-plan-v2
description: Pre-push gate for the current branch's diff. Runs review-plan-v2's deterministic analyzers (gitleaks, markdownlint, actionlint, shellcheck, ruff, structural) with --static-only, then the CodeRabbit CLI for the actual review. No API keys, nothing billed to you, and no diff leaves the machine on the first leg. The tool's own AI reviewer legs were retired on 2026-08-28 — never run it without --static-only.
---

# /review-plan-v2

**Commit the change first.** Then run this, from the repo root. It is the whole gate,
and it is one block on purpose — see "One vendor path" below:

Set `BASE` once. **Every command block in this file takes it**, and each one begins
with `scripts/preflight-vendor-review.sh &&` — that is the only form in which a
vendor call appears here.

```bash
# Prerequisite: the change is COMMITTED. Leg 1 reads the committed diff.
BASE=main   # or `staging` on repos with a staging branch — set it once, here

scripts/preflight-vendor-review.sh \
  && review-plan-v2 --static-only --plain --base "$BASE" \
  && scripts/preflight-vendor-review.sh \
  && coderabbit review --base "$BASE" --include-untracked
# leg 1: deterministic only, nothing is billed, nothing leaves the machine.
#        `--plain` IS a review-plan-v2 flag: `[--plain | --agent]`, plain being
#        the default. Passed explicitly so the --agent form below is one edit away.
# leg 2: sends the diff to a vendor. `coderabbit` has NO --plain — plain text is
#        already its default and the flag is an `unknown option` at exit 1. The
#        two binaries differ here, so do not carry the flag across.
# preflight twice on purpose: once to fail fast, once immediately before the send
```

**The guard is a script because seven review rounds proved prose could not hold it,
and it has taken nine in total.** It lived here, as nine lines of shell in a fenced
block, from 2026-08-29 to 2026-08-31. In that window CodeRabbit caught, in order: the
missing `if` (its clean result is `grep` exiting 1, so the desired outcome looked like
failure); the fail-open pipeline capture (`if git status | grep '^??'` reports
*grep's* status, so a failing `git status` took the proceed branch — the guard called
the worktree clean exactly when it could not see the worktree); two copyable blocks
with no guard at all; the "fix" of marking those blocks with a comment saying the
guard still applied, which is a note about what you should have run rather than a
check on what you did; a bare `exit 2` that killed the *user's* shell when pasted
interactively; the `SIGPIPE` fail-open under `pipefail`, where `printf | grep -q`
reports 141 and the guard proceeds *because* it found too many untracked files to
finish listing them; the window between one check and the send; and last
`if untracked=$(grep '^??' <<<"$worktree")`, which collapsed grep's three outcomes
into an `if`'s two, so a `grep` that could not run read as a clean tree.

Every one of those fixes was correct and every one left the next hole. That stopped
being an argument about any individual fix: a shell fragment in a Markdown file has
no mechanism to be wrong out loud — nothing executes it, nothing tests it, and every
reader is free to paste half of it. So the guard is now
[`scripts/preflight-vendor-review.sh`](../../../scripts/preflight-vendor-review.sh),
which carries every round in its header, and
`scripts/test-preflight-vendor-review.sh`, which hands it a dirty worktree, an edited
tracked file, a directory that is not a repository, a path that does not exist, a
broken helper, an exported `GIT_DIR`, and 20,000 untracked files, and fails if any of
them passes. The bulk case asserts its own fixture still discriminates, because the
retired pipeline form only falls open above a byte threshold — the 64 KiB pipe buffer,
bisected 2026-08-31 at 61,893 bytes correct versus 70,893 fell open — so the same test
with a few thousand files would pass against the broken implementation and read as
proof. Run it in a repo that changes the script; it takes a few seconds.

**An eighth round widened what it rejects, and that one was not a fail-open.** It
checked `^??` alone until 2026-08-31, on the reasoning that `--include-untracked` is
what routes an unscanned file to the vendor while a tracked file's edits are already
reachable by gitleaks. The second half was false in this file's own measured numbers:
leg 1 diffs `$BASE...HEAD`, so an unstaged or staged edit is read by no scan in the
gate, and the guard passed a staged credential in a tracked file without comment. It
now refuses any dirty entry, which costs nothing in the intended workflow — the commit
prerequisite means the tree is clean by definition, and a dirty tree at gate time
means the prerequisite was skipped or the tree moved mid-gate. The same round removed
the last `grep` from the decision: it is `[ -n "$worktree" ]` on a variable already in
hand, with `awk` running only *below* the refusal to word it.

**A ninth round: git's own location variables outranked the script's `cd`.** With
`GIT_DIR`/`GIT_WORK_TREE` exported, `git status` inspected *that* repository
regardless of which directory the script entered — and the success line still named
the directory it was pointed at, because `pwd` was honest while `git` read somewhere
else. Reproduced 2026-08-31 against two scratch repos: aimed at a dirty tree holding
an unscanned untracked file, with the variables aimed at a clean one, it printed
`clean worktree in .../dirty` and exited **0**. Not exotic either — git exports these
to every hook it runs, so wiring the gate into a pre-push hook would have armed it.
`GIT_INDEX_FILE` is the same class one step in, since it redefines what "staged"
means. All four are unset at the top of the script now, with four cases pinning it,
the fourth checking the fix did not become a blanket refusal.

**Two calls narrow the check-to-send window; they do not close it.** A concurrent
writer can still land a file between the second call's exit and the moment the vendor
process enumerates the worktree. CodeRabbit raised it as CWE-367 on 2026-08-31 and the
race is real; what was wrong was the *width*, since this file said the second call cost
"one process spawn" and that is NOT VERIFIED and probably false — the CLI's
`Connecting to CodeRabbit...` phase has run past five minutes on this machine, and
whether it enumerates the worktree before or after connecting is unknown, so the
honest bound is "unknown, possibly the whole connect phase." The suggested remedy was
to drop `--include-untracked`, and that is declined deliberately: it closes the race
by making a file you forgot to `git add` invisible to the review, so its omission
reads exactly like a clean pass — the failure class this guard exists to remove,
reintroduced one layer out. Reviewing an immutable snapshot at HEAD costs the same
coverage. So the mitigation is the caller's, and it is the only one actually
available: do not write into the tree while the gate is running.

**One `BASE` variable, not the branch name typed four times.** Every command in this file — both legs, and the gitleaks fallback further down — takes the same base, and until 2026-08-29 the fallback hardcoded `main` while the primary said "use `--base staging` on repos with a staging branch." On a staging repo that fallback diffs against the wrong branch and still exits 0, which is a gate reporting clean over a range it was never asked about. CodeRabbit caught it.

**The exit codes are NOT shared between the two legs.** `review-plan-v2` has three tiers: `0` clean, `1` actionable, `2` tool error. `coderabbit` has one non-zero code for everything — verified on 0.7.5 on 2026-08-29: an unknown flag gives `error: unknown option` at exit **1**, running outside a git repository gives `Error: Git repository not found.` at exit **1**, and "found actionable issues" is also exit **1**. Three outcomes, one status, and two of them mean the reviewer never ran. So on the second leg, read the first line of output; the number cannot tell you which of the three happened. This skill claimed the tiers were shared by both until 2026-08-29.

**The `&&` is the point, not shell tidiness.** On two separate lines a non-zero first leg does not stop the second, so a gitleaks hit is followed by the diff being sent to a vendor anyway and the scan prevented nothing. This skill said exactly that about the missing-binary fallback while leaving the primary command unchained, which is the same defect one line higher up; CodeRabbit caught it. Accept the consequence the chain brings: any actionable static finding, lint included, now blocks the vendor leg until it is fixed. That is the intended order — the local half is free and the vendor half is not, and "address what either surfaces before pushing" is not a thing a caller should have to remember to do in sequence.

**The commit prerequisite is load-bearing, not tidiness.** Run the command above on uncommitted work and it prints `reviewing 0 of 0` and exits **0** — a clean-looking gate that ran no secret scan and no lint over the change. So if the `reviewing N of M changed file(s)` line reads zero while you have work in progress, that is the diagnosis; commit and re-run rather than reading it as a pass.

**This skill claimed `review-plan-v2` "has no working-tree mode" until 2026-08-29, and that was simply false.** `--type` takes `all`, `committed`, or `uncommitted`, and `uncommitted` is a working-tree mode. The correction matters less for what it adds than for what it does not: the mode exists, and it still does not cover the case the guard above exists for. Measured on 2026-08-29 in a scratch repo holding one unstaged modification, one staged addition, and one untracked file:

| `--type` | what it diffs | reviewed, in that scratch repo |
|---|---|---|
| `all` (**the default**) | `$BASE...HEAD` | nothing — `[NOTHING REVIEWED]`, exit 0 |
| `committed` | `$BASE...HEAD`, identical to `all` | nothing |
| `uncommitted` | plain `git diff` | the unstaged file only |

Two things follow. `all` is a misnomer — it is the committed diff, so the default flag set never reads the working tree, which is why the commit prerequisite stands. And `uncommitted` maps to plain `git diff`, which excludes the index, so the staged-but-uncommitted file was reviewed by **no scope at all** and neither was the untracked one. There is no `--type` that puts an untracked file in front of gitleaks; `gitleaks dir .` is the tool for that. CodeRabbit caught the false claim, and the staged-file gap turned up while checking it.

**The order is also load-bearing.** gitleaks runs in the first leg and nothing leaves the machine there. The second leg sends the diff to a vendor. Running the secret scan after the egress inverts the only sequence in which it can prevent anything.

**`--include-untracked` is a detector, not coverage, and it opens the hole the ordering above closes.** Without it `coderabbit review` reads **tracked changes only**, so a file you forgot to `git add` is invisible to the review and its omission looks identical to a clean pass. With it, that file is sent to the vendor — and no `--type` scope puts an untracked file in front of gitleaks, so gitleaks never scanned it. The flag therefore routes exactly the least-reviewed file in the change around the secret scan.

So the untracked check happens **before** either leg, from git, not from CodeRabbit's file count — by the time the second leg reports an extra file it has already sent it. That is `scripts/preflight-vendor-review.sh`, and every command block in this file leads with it, for the reasons recorded above.

**The bar is no untracked files at all, not "none belonging to this change."** `--include-untracked` sends every non-ignored untracked file in the worktree, so scratch notes, a pasted credential, a downloaded export, or a colleague's data sample sitting in the tree unrelated to the branch all go to the vendor with it. Deciding which ones "belong to the change" is a judgement made after the send. If a file should be reviewed, commit it and re-run the static leg; if it should not leave the machine, `.gitignore` it or move it out of the tree; if it is genuinely scratch, that is what `.gitignore` is for.

Keep `--include-untracked` anyway, as the backstop that should then find nothing: if it reports files the `reviewing N of M` line did not, that is a scan you skipped, not a bonus. Files matched by `.gitignore` stay excluded either way. If you need a secret scan over the working tree including untracked files, gitleaks does it directly and locally: `gitleaks dir . --redact` (verified on 8.30.1).

**`--redact` on every documented gitleaks command, because a gate that prints the secret it found has published it.** Without it a finding's `Secret:` line carries the credential in full, and that output lands wherever the gate ran: a CI log, a scrollback buffer, an agent transcript, a pasted-into-chat "here's what the scan said." `--redact` is `--redact uint[=100]` and defaults to 100% on both the `git` and `dir` subcommands, so the bare flag is the strongest form. Note the finding detail only prints with `-v` at all — plain `gitleaks git` prints `leaks found: N` and nothing else — which means the exposure arrives the moment someone adds `-v` to find out *which* file, at exactly the moment they are most likely to paste the output somewhere. Verified on 8.30.1.

## What changed on 2026-08-28, and why it matters to how you read this

**This skill used to describe a multi-reviewer AI pass over the diff using your own API keys. That is gone.** Whatever earlier versions said about DeepSeek, a Gemini broad pass, a `gpt-5.5` cascade on high-risk paths, `[DEAD-LEG]` provider refusals, `[STARVED]` reviewers, or an `[INCOMPLETE]` wall-clock budget described components that no longer run. Two reasons, and the second is why this was not merely a cost trim.

- **Billed separately for weaker findings.** Those reviewers saw one file's diff hunk at a time — not the PR history, not earlier review rounds, not cross-document context. In practice they surfaced a subset of what the PR-side review found anyway. Same finding, two vendor bills, weaker one first.
- **They were the machine's memory ceiling.** A full run held per-file reviewer output for every changed file in a long-lived Python process at foreground priority, with **no cross-process concurrency guard** — nothing refused a second or third concurrent run. Three overlapping runs across two repos, one with a 177-file diff, saturated the compressor at 13.4 GB of 24 GB physical; Jetsam killed only low-priority daemons because the consumer outranked all of them, and the machine kernel-panicked on a watchdog timeout twice. NOT VERIFIED as the sole cause — re-running under measurement would bill real API keys — but the full test suite (peak 2.6 GB) and the mutation harness (peak 3.4 GB) were measured in the same repos and ruled out.

Consequence to accept rather than work around: PR-side review rounds may run longer than the one or two the two-reviewer setup targeted. One reviewer with full context beats two where the cheaper one is blind, and a review tool that can panic the machine it runs on is not a gate.

## What `--static-only` actually checks

gitleaks (sequential, first), markdownlint, actionlint, shellcheck, ruff, and the structural enumerator. Then it renders their findings and exits. No reviewer is constructed, no provider is called, no diff leaves the machine, no key is billed. It also does not take the auto-pause state lock, because a static run is not a review round.

Keep running it because it is the half CodeRabbit does not replace: a pre-push secret scan, and lint gates that read this repo's own `.markdownlint.json` and gate config. Free, fast, bounded in memory.

**A clean static run and a clean full review print the same `No findings` body.** The difference is the entire question of what was checked, so the run prints a `STATIC ONLY` banner on stderr saying so. If you are reporting a gate as clean, say which gate.

## Traps that have each cost real time

- **Exit 0 also covers "reviewed ZERO files."** An empty diff, or every file excluded by `path_filters`. Those runs print `[NOTHING REVIEWED]`. Read the `reviewing N of M changed file(s)` line rather than trusting the exit code, or pass `--require-changes` to make it exit 2. The usual cause is uncommitted changes or the wrong `--base`.
- **`path_filters` is read only from `.coderabbit.yaml`.** `.review-plan-v2.yaml` supplies `high_risk_paths`, the numeric tuning keys, `always_include_files`, and `import_aliases`, and **no path filter of any kind** — a `path_filters:` block written there is silently ignored, and an empty filter means review everything. One repo carried such a block for weeks believing it was filtered. Confirm a filter from the `reviewing N of M` line, never from a config file containing the word.
- **`high_risk_paths` in `.review-plan-v2.yaml` now drives nothing.** It selected files for the retired cascade. If a repo has review briefs worth keeping there, they belong in `.coderabbit.yaml` as `reviews.path_instructions`.
- **`coderabbit review --plain` is not a flag.** It exits **1** with `error: unknown option '--plain'`, which is the same 1 as "found actionable issues" — see the exit-code paragraph above. Plain text is already the default. It also reviews **tracked** changes only, so `git add` a new file or pass `--include-untracked`.
- **`--static-only --no-static-analyzers` is exit 2**, not a clean run, because together they check nothing.
- **`coderabbit auth status`, not `which coderabbit`.** An installed-but-signed-out CLI is a binary that cannot review. `coderabbit auth login` needs a TTY that Claude Code's shell does not provide; use `coderabbit auth login --agent`, which prints an `authUrl` and waits on a `127.0.0.1` callback. That callback URL carries a live access token, so treat it as a secret: never paste it into a chat, a log, or a commit.

## Structured output

```bash
set -o pipefail   # or check ${PIPESTATUS[0]} / ${pipestatus[1]} in zsh
scripts/preflight-vendor-review.sh \
  && review-plan-v2 --static-only --agent --base "$BASE" | jq 'select(.type == "finding" or .type == "summary")' \
  && scripts/preflight-vendor-review.sh \
  && coderabbit review --agent --base "$BASE" --include-untracked
```

**`set -o pipefail` is part of the example, not decoration.** Without it the pipeline reports `jq`'s status, so an analyzer exiting 1 or 2 reads as 0 — a gate that found something, or failed to run at all, reported as clean by the one number a caller checks.

**And the two mechanisms are one mechanism here.** Until 2026-08-29 this block listed the legs on separate lines, so a gitleaks hit in the first was followed by the diff going to the vendor anyway — the identical defect the `&&` paragraph above spends a paragraph on, sitting in this file's own example, which is a fair measure of how well prose protects an invariant. Chained now. Note that the `&&` and the `pipefail` depend on each other in a way the plain-text form does not: `&&` reads the *pipeline's* status, and without `pipefail` that status is `jq`'s, which is 0 whether the analyzers found a credential or never ran. Dropping `set -o pipefail` from this block therefore leaves a chain that looks like a gate and gates nothing. CodeRabbit caught the missing `&&`.

**The filter keeps the summary record, because the paragraph below is about a record the example used to discard.** It read `select(.type == "finding")` until 2026-08-29, which drops the only record that says which gate ran — so the next sentence advertised a capability the command above it destroyed, in the same file, five lines apart. The `--agent` summary record reports `static_only`, so a consumer can tell an exit 1 from the deterministic half apart from an exit 1 from a full review; verified on 2026-08-29 the stream carries exactly one non-finding record, `{"type":"summary","static_only":true,...}`. CodeRabbit caught it.

## Required env

**None.** No provider key is needed in static-only mode; a run with every key unset behaves identically. `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY` all enable nothing here now.

System deps: `brew install python@3.12 jq yq gitleaks markdownlint-cli actionlint shellcheck`. CR CLI: `brew install --cask coderabbit` then `coderabbit auth login --agent`. The docs write it as `brew install coderabbit`, which works only because no formula of that name exists and `brew install` falls back to searching casks — observed on 2026-08-28, where the bare form printed `Would install 1 cask: coderabbit` and installed 0.7.5. Prefer the explicit `--cask` anyway, so the command does not depend on a formula of that name never appearing.

The `review-plan-v2` binary is a symlink at `~/.local/bin/review-plan-v2` → the workflows repo's `scripts/review-plan-v2.sh`. The target is machine-specific; check it with `ls -l ~/.local/bin/review-plan-v2`.

**If the binary is absent, do not fall through to the vendor leg alone.** That was the previous advice here and it was wrong: it sends the diff off the machine with no secret scan in front of it, which is the one sequence this skill exists to preserve. gitleaks is an independent binary and does not need `review-plan-v2`, so it can stand in for leg 1:

```bash
# gitleaks substitutes for leg 1 ONLY. The preflight is still the first thing that
# runs, and runs again immediately before the send.
scripts/preflight-vendor-review.sh \
  && gitleaks git --log-opts="$BASE..HEAD" --redact \
  && scripts/preflight-vendor-review.sh \
  && coderabbit review --base "$BASE" --include-untracked
```

**Chained with `&&`, not listed on separate lines.** A leak exits non-zero, and on separate lines the next command runs anyway — sending to the vendor the exact diff the scan just objected to. Use `gitleaks dir . --redact` in place of the `git` form when untracked files are in play; it scans the working tree, which the `git` form does not. Both forms verified on gitleaks 8.30.1, `--redact` on both subcommands.

If gitleaks is not installed either, stop and say the gate cannot run. The remaining lint analyzers are worth having but they are not what stands between a credential and a third party.

## Coexistence with /review-plan v1

`/review-plan` (v1) reviews **specs and plans pre-implementation** via OpenAI plus Gemini, and is unaffected by any of this — it still uses your own keys. This skill gates **diffs pre-push**. Different points in the workflow, no shared code, both stay installed.

## Out of scope

- Does not post to GitHub PRs. The PR-side CodeRabbit review is a second look by the same reviewer with more context (cross-document consistency, spec-versus-code drift, the full PR diff), so it is not a formality — but it is a separate step, and a local pass is not a substitute for waiting on it.
- Does not review specs or plans. Use `/review-plan` v1.
- Does not judge correctness, security, or test coverage on its own. The static half cannot, and saying otherwise from a clean `--static-only` run is the specific mistake the `STATIC ONLY` banner exists to prevent.
