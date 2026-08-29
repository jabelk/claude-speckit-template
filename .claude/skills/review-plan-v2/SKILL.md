---
name: review-plan-v2
description: Pre-push gate for the current branch's diff. Runs review-plan-v2's deterministic analyzers (gitleaks, markdownlint, actionlint, shellcheck, ruff, structural) with --static-only, then the CodeRabbit CLI for the actual review. No API keys, nothing billed to you, and no diff leaves the machine on the first leg. The tool's own AI reviewer legs were retired on 2026-08-28 — never run it without --static-only.
---

# /review-plan-v2

**Commit the change first.** Then run this, from the repo root. It is the whole gate,
and it is one block on purpose — see "One vendor path" below:

Paste these two definitions once per shell. **Every command block in this file
assumes them**, and each one begins with `preflight &&` — that is the only form in
which a vendor call appears here.

```bash
# Prerequisite: the change is COMMITTED. Leg 1 reads the committed diff.
BASE=main   # or `staging` on repos with a staging branch — set it once, here

# The guard, defined ONCE. The body is `( ... )` — a subshell — so `exit 2` ends the
# guard and returns 2 to the caller instead of killing an interactive shell.
preflight() (
  # Fail CLOSED: a worktree that cannot be inspected is not a clean one.
  if ! worktree=$(git status --porcelain --untracked-files=all); then
    echo "STOP: cannot inspect the worktree, so the vendor leg is not safe." >&2
    exit 2
  fi
  if printf '%s\n' "$worktree" | grep -q '^??'; then
    printf '%s\n' "$worktree" | grep '^??'
    echo "STOP: the vendor leg would send the untracked files listed above." >&2
    exit 2
  fi
)
```

Then the gate itself:

```bash
preflight \
  && review-plan-v2 --static-only --plain --base "$BASE" \
  && coderabbit review --base "$BASE" --include-untracked
# leg 1: deterministic only, nothing is billed, nothing leaves the machine
# leg 2: sends the diff to a vendor; plain text is its default, --plain is NOT a flag
```

**A named guard, because annotating the other blocks did not guard them.** Until
2026-08-29 this file opened with the two legs alone and put the untracked-file
check in a second block further down, next to the prose explaining it. A reader
who copied the first block — the obvious thing to copy, being first and
complete-looking — got the vendor leg with no guard at all, and the `gitleaks`
fallback near the bottom had the same hole. The first fix was to keep one guarded
block and mark the other two sites with comments saying the preflight above still
applied. CodeRabbit rejected that on the next round and was right to: a comment
telling a reader what they should have run is not a guard on what they did run,
and both of those blocks were still copyable, complete, and unguarded. Hence a
function. The check now exists in exactly one place *and* appears at every vendor
site, which is what the previous two attempts each got half of.

**The `( ... )` body is the fix for a second thing I had merely apologised for.**
The guard used to be a bare `if` with `exit 2`, which does the right thing in a
script and terminates the *user's shell* when pasted into an interactive one —
this file's answer to that was a note saying "interactively, read the STOP line",
which is documentation standing in for a defect. A subshell function body makes
`exit 2` mean "the guard failed", interactively and in a script alike. CodeRabbit
caught it.

**Fail closed, because the guard's clean answer and its broken answer looked the
same.** The earlier form was `if git status --porcelain -uall | grep '^??'`. When
`git status` itself fails, `grep` reads empty input and exits 1, so the `else`
branch runs and the vendor leg proceeds — the guard reports a clean worktree
precisely when it could not see the worktree. Verified on 2026-08-29 by running
the old form in a non-repository directory: it printed `fatal: not a git
repository` and then took the proceed branch. The form above captures the status
separately and treats a failed capture as its own `exit 2`. CodeRabbit caught this
one round after catching the missing `if`, which is the same lesson twice: a check
whose failure mode is indistinguishable from success is not a check.

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

So the untracked check happens **before** either leg, from git, not from CodeRabbit's file count — by the time the second leg reports an extra file it has already sent it. That is `preflight`, defined at the top of this file, and every command block here leads with it.

**The check is wrapped in an `if` rather than left as a bare pipeline because its clean result is a non-zero exit.** `grep '^??'` finding nothing exits **1**, so the outcome you want is the one that looks like failure: as a bare line above the gate under `set -e` the clean case aborts before either leg runs, and without `set -e` it is a line whose output nobody is obliged to read. Wrapping it makes the ordering structural instead of a thing the reader has to remember to honour. This is also why the two `if`s are separate rather than an `if`/`elif`: the first tests whether the worktree could be *read*, the second what it *contains*, and collapsing them invites the fail-open form below.

Between them these paragraphs record four consecutive rounds on one guard: CodeRabbit caught the missing `if`, then the fail-open pipeline capture, then the two unguarded copyable blocks, then the interactive-shell-killing `exit`. Four rounds on nine lines of shell is the argument for the guard being a function rather than a paragraph.

**The bar is no untracked files at all, not "none belonging to this change."** `--include-untracked` sends every non-ignored untracked file in the worktree, so scratch notes, a pasted credential, a downloaded export, or a colleague's data sample sitting in the tree unrelated to the branch all go to the vendor with it. Deciding which ones "belong to the change" is a judgement made after the send. If a file should be reviewed, commit it and re-run the static leg; if it should not leave the machine, `.gitignore` it or move it out of the tree; if it is genuinely scratch, that is what `.gitignore` is for.

Keep `--include-untracked` anyway, as the backstop that should then find nothing: if it reports files the `reviewing N of M` line did not, that is a scan you skipped, not a bonus. Files matched by `.gitignore` stay excluded either way. If you need a secret scan over the working tree including untracked files, gitleaks does it directly and locally: `gitleaks dir .` (verified on 8.30.1).

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
preflight \
  && review-plan-v2 --static-only --agent --base "$BASE" | jq 'select(.type == "finding")' \
  && coderabbit review --agent --base "$BASE" --include-untracked
```

**`set -o pipefail` is part of the example, not decoration.** Without it the pipeline reports `jq`'s status, so an analyzer exiting 1 or 2 reads as 0 — a gate that found something, or failed to run at all, reported as clean by the one number a caller checks.

**And the two mechanisms are one mechanism here.** Until 2026-08-29 this block listed the legs on separate lines, so a gitleaks hit in the first was followed by the diff going to the vendor anyway — the identical defect the `&&` paragraph above spends a paragraph on, sitting in this file's own example, which is a fair measure of how well prose protects an invariant. Chained now. Note that the `&&` and the `pipefail` depend on each other in a way the plain-text form does not: `&&` reads the *pipeline's* status, and without `pipefail` that status is `jq`'s, which is 0 whether the analyzers found a credential or never ran. Dropping `set -o pipefail` from this block therefore leaves a chain that looks like a gate and gates nothing. CodeRabbit caught the missing `&&`.

The `--agent` summary record reports `static_only`, so a consumer can tell an exit 1 from the deterministic half apart from an exit 1 from a full review.

## Required env

**None.** No provider key is needed in static-only mode; a run with every key unset behaves identically. `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY` all enable nothing here now.

System deps: `brew install python@3.12 jq yq gitleaks markdownlint-cli actionlint shellcheck`. CR CLI: `brew install --cask coderabbit` then `coderabbit auth login --agent`. The docs write it as `brew install coderabbit`, which works only because no formula of that name exists and `brew install` falls back to searching casks — observed on 2026-08-28, where the bare form printed `Would install 1 cask: coderabbit` and installed 0.7.5. Prefer the explicit `--cask` anyway, so the command does not depend on a formula of that name never appearing.

The `review-plan-v2` binary is a symlink at `~/.local/bin/review-plan-v2` → the workflows repo's `scripts/review-plan-v2.sh`. The target is machine-specific; check it with `ls -l ~/.local/bin/review-plan-v2`.

**If the binary is absent, do not fall through to the vendor leg alone.** That was the previous advice here and it was wrong: it sends the diff off the machine with no secret scan in front of it, which is the one sequence this skill exists to preserve. gitleaks is an independent binary and does not need `review-plan-v2`, so it can stand in for leg 1:

```bash
# gitleaks substitutes for leg 1 ONLY. `preflight` is still the first thing that runs.
preflight \
  && gitleaks git --log-opts="$BASE..HEAD" \
  && coderabbit review --base "$BASE" --include-untracked
```

**Chained with `&&`, not listed on separate lines.** A leak exits non-zero, and on separate lines the next command runs anyway — sending to the vendor the exact diff the scan just objected to. Use `gitleaks dir .` in place of the `git` form when untracked files are in play; it scans the working tree, which the `git` form does not. Both forms verified on gitleaks 8.30.1.

If gitleaks is not installed either, stop and say the gate cannot run. The remaining lint analyzers are worth having but they are not what stands between a credential and a third party.

## Coexistence with /review-plan v1

`/review-plan` (v1) reviews **specs and plans pre-implementation** via OpenAI plus Gemini, and is unaffected by any of this — it still uses your own keys. This skill gates **diffs pre-push**. Different points in the workflow, no shared code, both stay installed.

## Out of scope

- Does not post to GitHub PRs. The PR-side CodeRabbit review is a second look by the same reviewer with more context (cross-document consistency, spec-versus-code drift, the full PR diff), so it is not a formality — but it is a separate step, and a local pass is not a substitute for waiting on it.
- Does not review specs or plans. Use `/review-plan` v1.
- Does not judge correctness, security, or test coverage on its own. The static half cannot, and saying otherwise from a clean `--static-only` run is the specific mistake the `STATIC ONLY` banner exists to prevent.
