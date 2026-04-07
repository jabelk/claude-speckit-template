#!/usr/bin/env bash
# review-plan.sh — Send speckit plan + spec to external AI models for peer review
# Usage: ./scripts/review-plan.sh [feature-dir]
# Example: ./scripts/review-plan.sh specs/003-auth-flow
#
# Reads DEEPSEEK_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY from .env
# Calls models in parallel, outputs critiques with GREEN/YELLOW/RED ratings.

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load .env (disable nounset — .env values may contain unquoted $vars)
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  source "$REPO_ROOT/.env" 2>/dev/null || true
  set +a
fi

# Find feature directory
if [[ -n "${1:-}" ]]; then
  FEATURE_DIR="$REPO_ROOT/$1"
else
  # Auto-detect: find the most recently modified specs/*/plan.md
  if stat --version >/dev/null 2>&1; then
    # GNU stat (Linux)
    FEATURE_DIR=$(find "$REPO_ROOT/specs" -name "plan.md" -exec stat -c "%Y %n" {} + 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2- | xargs dirname)
  else
    # BSD stat (macOS)
    FEATURE_DIR=$(find "$REPO_ROOT/specs" -name "plan.md" -exec stat -f "%m %N" {} + 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2- | xargs dirname)
  fi
  if [[ -z "$FEATURE_DIR" ]]; then
    echo "ERROR: No feature directory found. Pass one explicitly: ./scripts/review-plan.sh specs/003-foo"
    exit 1
  fi
fi

echo "Reviewing: $FEATURE_DIR"

# Collect context
PLAN=""
SPEC=""
CONSTITUTION=""
CLAUDE_MD=""

[[ -f "$FEATURE_DIR/plan.md" ]] && PLAN=$(cat "$FEATURE_DIR/plan.md")
[[ -f "$FEATURE_DIR/spec.md" ]] && SPEC=$(cat "$FEATURE_DIR/spec.md")
[[ -f "$REPO_ROOT/.specify/memory/constitution.md" ]] && CONSTITUTION=$(cat "$REPO_ROOT/.specify/memory/constitution.md")
# Truncate CLAUDE.md — strip "Active Technologies" and "Recent Changes" sections
# which are session-specific and bloat the payload without adding review value
if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
  CLAUDE_MD=$(sed '/^## Active Technologies/,$d' "$REPO_ROOT/CLAUDE.md")
fi

if [[ -z "$PLAN" || -z "$SPEC" ]]; then
  echo "ERROR: Missing required files in $FEATURE_DIR"
  [[ -z "$PLAN" ]] && echo " - missing: plan.md"
  [[ -z "$SPEC" ]] && echo " - missing: spec.md"
  exit 1
fi

# Also grab tasks and data model if they exist
TASKS=""
DATA_MODEL=""
RESEARCH=""
[[ -f "$FEATURE_DIR/tasks.md" ]] && TASKS=$(cat "$FEATURE_DIR/tasks.md")
[[ -f "$FEATURE_DIR/data-model.md" ]] && DATA_MODEL=$(cat "$FEATURE_DIR/data-model.md")
[[ -f "$FEATURE_DIR/research.md" ]] && RESEARCH=$(cat "$FEATURE_DIR/research.md")

# Build the review prompt
# NOTE: Customize the FRAMEWORK GOTCHAS line below for your project's stack.
# Examples:
#   - SvelteKit: "$derived tracking, rune file restrictions, env var timing"
#   - React Native/Expo: "native module linking, EAS build config, Supabase RLS policies"
#   - Python/FastAPI: "async lifecycle, Pydantic v2 migration, dependency injection scope"
SYSTEM_PROMPT="You are a senior software architect reviewing an implementation plan before coding begins. Your job is to find problems BEFORE they become bugs. Be direct and specific — no praise, no filler. Focus on:

1. LOGICAL GAPS: Missing error handling, race conditions, unhandled edge cases
2. SCOPE CREEP: Unnecessary complexity, features that aren't needed yet (YAGNI)
3. SCHEMA RISKS: Database migration issues, missing defaults, breaking changes
4. SECURITY: Auth bypasses, injection risks, exposed secrets
5. INTEGRATION RISKS: Cross-file dependencies that could break, missing test coverage
6. FRAMEWORK GOTCHAS: Project-specific issues based on the tech stack described in CLAUDE.md

Rate the plan: GREEN (ship it), YELLOW (fix these issues first), RED (rethink the approach).

Keep your review under 500 words. Lead with the rating and top 3 issues."

USER_PROMPT="## Project Architecture & Conventions (CLAUDE.md)
$CLAUDE_MD

## Constitution (non-negotiable principles)
$CONSTITUTION

## Feature Spec
$SPEC

## Implementation Plan
$PLAN"

if [[ -n "$TASKS" ]]; then
  USER_PROMPT="$USER_PROMPT

## Task Breakdown
$TASKS"
fi

if [[ -n "$DATA_MODEL" ]]; then
  USER_PROMPT="$USER_PROMPT

## Data Model
$DATA_MODEL"
fi

if [[ -n "$RESEARCH" ]]; then
  USER_PROMPT="$USER_PROMPT

## Research
$RESEARCH"
fi

# Warn if payload is very large (rough estimate: 1 token ~ 4 chars)
PAYLOAD_CHARS=$(( ${#SYSTEM_PROMPT} + ${#USER_PROMPT} ))
ESTIMATED_TOKENS=$(( PAYLOAD_CHARS / 4 ))
if [[ $ESTIMATED_TOKENS -gt 40000 ]]; then
  echo "WARNING: Estimated payload ~${ESTIMATED_TOKENS} tokens (DeepSeek limit: 64K)."
  echo "  Consider trimming spec files if DeepSeek fails."
  echo ""
fi

# Temp files for parallel output
DEEPSEEK_OUT=$(mktemp)
OPENAI_OUT=$(mktemp)
GEMINI_OUT=$(mktemp)
trap "rm -f $DEEPSEEK_OUT $OPENAI_OUT $GEMINI_OUT $DEEPSEEK_OUT.log $OPENAI_OUT.log $GEMINI_OUT.log" EXIT

# Escape for JSON
json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

SYSTEM_JSON=$(json_escape "$SYSTEM_PROMPT")
USER_JSON=$(json_escape "$USER_PROMPT")

# Shared curl options for external model APIs
CURL_OPTS=(
  --silent
  --show-error
  --connect-timeout 10
  --max-time 120
)
# DeepSeek R1 needs longer timeout — reasoning models routinely take 3-5 min
CURL_OPTS_DEEPSEEK=(
  --silent
  --show-error
  --connect-timeout 10
  --max-time 300
)

# --- DeepSeek R1 ---
call_deepseek() {
  if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo "SKIPPED: No DEEPSEEK_API_KEY" > "$DEEPSEEK_OUT"
    return
  fi
  local attempt
  for attempt in 1 2; do
    curl "${CURL_OPTS_DEEPSEEK[@]}" https://api.deepseek.com/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
      -d "{
        \"model\": \"deepseek-reasoner\",
        \"messages\": [
          {\"role\": \"system\", \"content\": $SYSTEM_JSON},
          {\"role\": \"user\", \"content\": $USER_JSON}
        ],
        \"max_tokens\": 2048
      }" | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    content = r['choices'][0]['message']['content']
    if content and content.strip():
        print(content)
    else:
        print('__EMPTY__')
        print('Raw response:', json.dumps(r, indent=2), file=sys.stderr)
except Exception as e:
    print('__EMPTY__')
    print(f'DeepSeek parse error: {e}', file=sys.stderr)
    print(json.dumps(r, indent=2) if 'r' in dir() else 'No response body', file=sys.stderr)
" > "$DEEPSEEK_OUT" 2>>"$DEEPSEEK_OUT.log"
    # Retry once if response was empty
    if ! grep -q '^__EMPTY__$' "$DEEPSEEK_OUT" 2>/dev/null; then
      break
    fi
    if [[ $attempt -eq 1 ]]; then
      echo "  [DeepSeek] Empty response on attempt 1, retrying..." >&2
    else
      tmp=$(mktemp) && sed 's/^__EMPTY__$/DeepSeek R1 returned empty after 2 attempts. Check .log for raw response./' "$DEEPSEEK_OUT" > "$tmp" && mv "$tmp" "$DEEPSEEK_OUT"
    fi
  done
}

# --- OpenAI ---
call_openai() {
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "SKIPPED: No OPENAI_API_KEY" > "$OPENAI_OUT"
    return
  fi
  local attempt
  for attempt in 1 2; do
    curl "${CURL_OPTS[@]}" https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "{
        \"model\": \"o4-mini\",
        \"messages\": [
          {\"role\": \"developer\", \"content\": $SYSTEM_JSON},
          {\"role\": \"user\", \"content\": $USER_JSON}
        ],
        \"max_completion_tokens\": 2048
      }" | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    content = r['choices'][0]['message']['content']
    if content and content.strip():
        print(content)
    else:
        print('__EMPTY__')
        print('Raw response:', json.dumps(r, indent=2), file=sys.stderr)
except Exception as e:
    print('__EMPTY__')
    print(f'OpenAI parse error: {e}', file=sys.stderr)
    print(json.dumps(r, indent=2) if 'r' in dir() else 'No response body', file=sys.stderr)
" > "$OPENAI_OUT" 2>>"$OPENAI_OUT.log"
    if ! grep -q '^__EMPTY__$' "$OPENAI_OUT" 2>/dev/null; then
      break
    fi
    if [[ $attempt -eq 1 ]]; then
      echo "  [OpenAI] Empty response on attempt 1, retrying..." >&2
    else
      tmp=$(mktemp) && sed 's/^__EMPTY__$/OpenAI o4-mini returned empty after 2 attempts. Check .log for raw response./' "$OPENAI_OUT" > "$tmp" && mv "$tmp" "$OPENAI_OUT"
    fi
  done
}

# --- Gemini ---
call_gemini() {
  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "SKIPPED: No GEMINI_API_KEY" > "$GEMINI_OUT"
    return
  fi
  local attempt
  for attempt in 1 2; do
    curl "${CURL_OPTS[@]}" "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
      -H "Content-Type: application/json" \
      -H "x-goog-api-key: $GEMINI_API_KEY" \
      -d "{
        \"system_instruction\": {\"parts\": [{\"text\": $SYSTEM_JSON}]},
        \"contents\": [{\"parts\": [{\"text\": $USER_JSON}]}],
        \"generationConfig\": {\"maxOutputTokens\": 2048}
      }" | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    content = r['candidates'][0]['content']['parts'][0]['text']
    if content and content.strip():
        print(content)
    else:
        print('__EMPTY__')
        print('Raw response:', json.dumps(r, indent=2), file=sys.stderr)
except Exception as e:
    print('__EMPTY__')
    print(f'Gemini parse error: {e}', file=sys.stderr)
    print(json.dumps(r, indent=2) if 'r' in dir() else 'No response body', file=sys.stderr)
" > "$GEMINI_OUT" 2>>"$GEMINI_OUT.log"
    if ! grep -q '^__EMPTY__$' "$GEMINI_OUT" 2>/dev/null; then
      break
    fi
    if [[ $attempt -eq 1 ]]; then
      echo "  [Gemini] Empty response on attempt 1, retrying..." >&2
    else
      tmp=$(mktemp) && sed 's/^__EMPTY__$/Gemini 2.5 Flash returned empty after 2 attempts. Check .log for raw response./' "$GEMINI_OUT" > "$tmp" && mv "$tmp" "$GEMINI_OUT"
    fi
  done
}

echo ""
echo "Sending to DeepSeek R1, OpenAI o4-mini, and Gemini 2.5 Flash in parallel..."
echo ""

# Run all three in parallel
call_deepseek &
call_openai &
call_gemini &
wait

# Output results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DEEPSEEK R1 REVIEW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$DEEPSEEK_OUT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OPENAI o4-mini REVIEW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$OPENAI_OUT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GEMINI 2.5 FLASH REVIEW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$GEMINI_OUT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Review complete. Assess the critiques above and decide how to proceed."
