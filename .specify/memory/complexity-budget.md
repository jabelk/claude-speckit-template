# Complexity Budget

Guardrails to keep the project simple. Delete this file if not needed for your project.

## LOC Thresholds

| Threshold | Action Required |
|-----------|-----------------|
| Any single file ≥ 500 LOC | Document why in a comment at the top of the file |
| Any single file ≥ 1000 LOC | ADR recommended — record the decision and alternatives considered |
| Total project ≥ 10,000 LOC | Review architecture for decomposition opportunities |

## New Dependencies

Before adding a new dependency:

1. **Document its purpose** — what does it do that we can't do ourselves in < 50 LOC?
2. **List alternatives considered** — why this one over others?
3. **Check maintenance status** — last release date, open issues, bus factor.
4. **Note the license** — must be compatible with this project's license.

Record the decision in the Key Decisions table in `constitution.md` if the dependency is significant (ORM, framework, cloud SDK, etc.).

## Abstraction Policy

- Don't create helpers, utilities, or abstractions for one-time operations.
- Three similar lines of code is better than a premature abstraction.
- If you find yourself building the same thing a third time, then extract it.
