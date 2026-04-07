---
name: "review-plan"
description: "Multi-model peer review — sends spec + plan to external AI models for independent critique before implementation."
argument-hint: "Optionally pass a specific feature dir (e.g., specs/003-auth-flow)"
compatibility: "Requires spec-kit project structure, .env with API keys (OPENAI_API_KEY, GEMINI_API_KEY)"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
disable-model-invocation: true
---

# Review Plan — Multi-Model Peer Review

Send the current feature's spec + plan to external AI models (OpenAI o4-mini, Gemini 2.5 Flash) for independent peer review before implementation begins.

## Data Sensitivity Warning

Before running, consider whether the spec/plan contains sensitive data (PII, credentials, proprietary business logic). The review sends content to external API providers. If the project handles sensitive data, confirm with the user before proceeding.

## When to use

Run this AFTER `/speckit-plan` and `/speckit-tasks` complete, BEFORE `/speckit-implement`. This is the gate between planning and coding.

## How it works

1. Run `./scripts/review-plan.sh $ARGUMENTS` from the repo root
2. The script auto-detects the most recently modified `specs/*/plan.md` if no argument is given, or pass a specific feature dir (e.g., `specs/003-auth-flow`)
3. It sends the spec, plan, tasks, data model, and constitution to all three models in parallel
4. Each model rates the plan GREEN/YELLOW/RED and lists top issues

## After the review

Present all three reviews to the user with a summary:
- If all GREEN: "All reviewers approve. Safe to implement."
- If any YELLOW: "Issues flagged — review the concerns below and decide whether to fix before implementing."
- If any RED: "At least one reviewer recommends rethinking the approach. Address the RED concerns before proceeding."

If the user wants to proceed despite warnings, that's their call. The review is advisory, not blocking.
