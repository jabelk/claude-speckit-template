---
name: review-plan-v2
description: Pre-push gate for the current branch's diff. Runs review-plan-v2's deterministic analyzers (gitleaks, markdownlint, actionlint, shellcheck, ruff, structural) with --static-only, then the CodeRabbit CLI for the actual review. No API keys, nothing billed to you, and no diff leaves the machine on the first leg. The tool's own AI reviewer legs were retired on 2026-08-28 — never run it without --static-only.
---

# /review-plan-v2

Gate the current branch before pushing. Two commands, in this order, from the repo root:

```bash
review-plan-v2 --static-only --plain --base main   # deterministic only; nothing is billed
coderabbit review --base main                     # plain text is its default; --plain is NOT a flag
```

Use `--base staging` on repos with a staging branch. Both share exit-code semantics: `0` clean, `1` actionable, `2` tool error. Address what either surfaces before pushing.

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
- **`coderabbit review --plain` is not a flag.** It exits **1** with `error: unknown option '--plain'`, and exit 1 is also "found actionable issues" — so a caller gating on the status reads a reviewer that never ran as one that flagged something. Plain text is already the default. It also reviews **tracked** changes only, so `git add` a new file or pass `--include-untracked`.
- **`--static-only --no-static-analyzers` is exit 2**, not a clean run, because together they check nothing.
- **`coderabbit auth status`, not `which coderabbit`.** An installed-but-signed-out CLI is a binary that cannot review. `coderabbit auth login` needs a TTY that Claude Code's shell does not provide; use `coderabbit auth login --agent`, which prints an `authUrl` and waits on a `127.0.0.1` callback. That callback URL carries a live access token, so treat it as a secret: never paste it into a chat, a log, or a commit.

## Structured output

```bash
review-plan-v2 --static-only --agent --base main | jq 'select(.type == "finding")'
coderabbit review --agent --base main
```

The `--agent` summary record reports `static_only`, so a consumer can tell an exit 1 from the deterministic half apart from an exit 1 from a full review.

## Required env

**None.** No provider key is needed in static-only mode; a run with every key unset behaves identically. `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY` all enable nothing here now.

System deps: `brew install python@3.12 jq yq gitleaks markdownlint-cli actionlint shellcheck`. CR CLI: `brew install --cask coderabbit` then `coderabbit auth login --agent`. (The docs write it as `brew install coderabbit`, which works only because no formula of that name exists and brew falls back to the cask.)

The `review-plan-v2` binary is a symlink at `~/.local/bin/review-plan-v2` → the workflows repo's `scripts/review-plan-v2.sh`. The target is machine-specific; check it with `ls -l ~/.local/bin/review-plan-v2`. If the binary is absent, the deterministic half of the gate is simply not available — run `coderabbit review --base main` alone and say that is what happened.

## Coexistence with /review-plan v1

`/review-plan` (v1) reviews **specs and plans pre-implementation** via OpenAI plus Gemini, and is unaffected by any of this — it still uses your own keys. This skill gates **diffs pre-push**. Different points in the workflow, no shared code, both stay installed.

## Out of scope

- Does not post to GitHub PRs. The PR-side CodeRabbit review is a second look by the same reviewer with more context (cross-document consistency, spec-versus-code drift, the full PR diff), so it is not a formality — but it is a separate step, and a local pass is not a substitute for waiting on it.
- Does not review specs or plans. Use `/review-plan` v1.
- Does not judge correctness, security, or test coverage on its own. The static half cannot, and saying otherwise from a clean `--static-only` run is the specific mistake the `STATIC ONLY` banner exists to prevent.
