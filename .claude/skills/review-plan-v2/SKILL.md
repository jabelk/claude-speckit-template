---
name: review-plan-v2
description: Local pre-push code review across parallel specialized reviewers (security, correctness, tests, consistency) plus static analyzers — drop-in replacement for `coderabbit review --plain` without vendor rate limits. Uses your own LLM API keys (DeepSeek broad-pass + OpenAI/Gemini cascade on high-risk paths).
---

# /review-plan-v2

Run a parallel multi-agent review of the current branch's diff vs the base branch.

## When to invoke

- Pre-push: same point in the workflow where the global CLAUDE.md says to run `coderabbit review --plain --base main`. This skill is a drop-in.
- Specifically when:
  - You want findings without burning a CodeRabbit Pro rate-limit slot.
  - You want to gate the push on a clean `actionable` count (`exit 1` on actionable findings).
  - You want JSON output for downstream tooling (`--agent`).

## Outline

1. From repo root, run:

   ```bash
   review-plan-v2 --plain --base main
   ```

   The `review-plan-v2` binary is installed globally as a symlink at `~/.local/bin/review-plan-v2` → `~/dev/projects/claude-workflows/scripts/review-plan-v2.sh`. If the binary is missing on this machine, fall back to `coderabbit review --plain --base main` (CR CLI is a drop-in alternative with the same flag shape).

2. Read the output:
   - `[INCOMPLETE]` at the **top** means some reviewer tasks never ran — the review is PARTIAL and a "clean" result proves nothing. Treat it as a failed gate, not a pass. See below.
   - `[ACTIONABLE]` lines block the push — fix them, re-run.
   - `[NIT]` / `[INFO]` are informational — your call.
   - Footer summary states counts + any analyzer skips + any config warnings.

   Exit codes: `0` clean **and** fully covered · `1` actionable findings · `2` tool error **or incomplete coverage** · `3` cost cap · `5` strict-config.

   Never read `exit 0` as "reviewed and clean" without checking for `[INCOMPLETE]` — that distinction is the whole point of code 2.

3. If the run reports `[INCOMPLETE]`:

   The reviewer phase has a wall-clock budget that scales with queued work (`ceil(tasks / concurrency) × 45s`, floored at 180s, capped at 1800s). Tasks are submitted in reviewer order, so when the budget runs out the *later* reviewers starve first — you lose `consistency`, then `tests`, then `correctness`, while `security` still completes. That skew is why a partial run can look plausible.

   Options, cheapest first:
   - Re-run — provider latency varies and a marginal run often clears.
   - Raise `--max-concurrency` (fewer waves → less wall clock).
   - Narrow the diff (review in two passes).

   **Background:** this was a live incident on 2026-08-01 — 34 of 48 tasks were silently cancelled and the run still printed `No findings.` and exited 0. When the same diff was re-run after the fix, it surfaced **9 actionable findings**. If you see `[INCOMPLETE]`, assume findings are missing.

4. If you need structured output:

   ```bash
   review-plan-v2 --agent --base main | jq 'select(.type == "finding")'
   ```

## When v2 keeps re-flagging an issue you already mitigated

v2's reviewers see one file's diff hunk in isolation. When your mitigation lives in **another file** (a validator helper, a Pydantic model with `pattern=`, an auth dependency, an allowlist regex), the reviewer can't see it and will re-flag the same finding round after round. **Don't argue with the reviewer in commit messages** — that costs cycles and never converges. Instead, do one or more of the following at the **call site** that's actually in the diff:

1. **Belt-and-suspenders the validator at the call site**. If the chokepoint is `_is_safe_href()` in `helpers.py`, add a Jinja `|safe_url` filter / wrapper that calls it again at the template / render boundary. The validation is now visible *in the hunk being reviewed*. You also get genuine defense-in-depth for free.
2. **Add a `## Security model` (or `## Validation invariants`) section to the contract / data-model doc**. Enumerate the chokepoints, the file:function locations, and the regression tests that exercise them. Title it explicitly so automated reviewers will read it (`"Security model (load-bearing — automated reviewers please read first)"` works). Future review rounds will quote that section instead of re-deriving the concern.
3. **Trivial inline sanity check at the call site**, when the real validation upstream is non-obvious to a reviewer reading just the hunk. Strategies 1 and 2 are the preferred routes for real validation — strategy 3 is **only** for cheap, obviously-safe heuristics: substring or prefix checks (`'..' in ref`, `ref.startswith('/')`), null/empty guards, length caps. **Do not** duplicate complex regexes, multi-condition Pydantic patterns, or hard-coded constants — that's anti-DRY bloat that drifts from the source of truth. The point of the inline guard is documentation-as-code: it tells the reviewer "yes, we know about this class of input; the real validator lives at <file>:<func> per the security-model section."

These are not workarounds — they are the **correct response** to a per-file-isolated reviewer flagging a cross-file mitigation. The reviewer is doing its job; your job is to surface the chokepoint at the use site.

When NOT to do this: if the same finding is recurring round-over-round and **the actual code didn't change**, it's a v2 visibility limit, not a real bug. Don't bloat the codebase with redundant guards. Document the false-positive class in the spec doc, then merge.

Open enhancements tracking these limits: GH issues #18 (`always_include_files`), #19 (`--include-related-files` 1-hop importers), #20 (round-N memory to suppress repeat findings). When any of those land, this section gets shorter.

## Coexistence with /review-plan v1

`/review-plan` (v1) reviews **specs/plans pre-implementation** via OpenAI + Gemini. `/review-plan-v2` reviews **diffs pre-push** via a DeepSeek broad-pass + an optional OpenAI/Gemini cascade on high-risk paths. They share no code; they serve different points in the workflow. Both stay installed.

## Required env

- `DEEPSEEK_API_KEY` — required. Drives all four broad-pass reviewers (`deepseek-v4-pro`).
- `OPENAI_API_KEY` — optional, adds a `gpt-5.5` cascade pass on high-risk paths configured in `.review-plan-v2.yaml`.
- `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) — optional, adds a `gemini-3.1-pro-preview` cascade pass on the same paths.

`ANTHROPIC_API_KEY` is **not** used. The cascade deliberately dropped Anthropic: a Claude judge reviewing Claude-written code is self-grading. Each cascade provider is gated on its key being present, so a missing key silently drops that leg rather than failing the run — check the `providers_called` summary field if you expect a cascade and don't see one.

See `specs/001-review-plan-v2/quickstart.md` for full install + configuration docs.

## Out of scope

- This skill does NOT post to GitHub PRs (use the CodeRabbit PR-side bot for that — it's the safety net for what the local pass missed).
- This skill does NOT review specs/plans (use `/review-plan` v1 for that).
