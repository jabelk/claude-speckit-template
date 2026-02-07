<!--
  Sync Impact Report
  Version change: 0.0.0 → 0.0.0 (template — not yet ratified)
  Added principles: none (placeholders)
  Added sections: Core Principles, Scope, Development Workflow, Governance
  Templates requiring updates: none
  Follow-up TODOs: Run /speckit.constitution to fill in project-specific principles
-->

# [PROJECT_NAME] Constitution

## Core Principles

<!--
  Run /speckit.constitution to replace these placeholders with your project's
  non-negotiable principles. Each principle should be:
  - Declarative and testable
  - Written with MUST/SHOULD language
  - Accompanied by a brief rationale

  Example principles to consider:
  - Simplicity (YAGNI, minimal abstractions)
  - Testing philosophy (TDD, coverage, communication)
  - Idempotency / safety guarantees
  - Interface preferences (CLI, API, UI)
  - Output formats and determinism
-->

### I. [PRINCIPLE_1_NAME]

[PRINCIPLE_1_DESCRIPTION]

### II. [PRINCIPLE_2_NAME]

[PRINCIPLE_2_DESCRIPTION]

### III. [PRINCIPLE_3_NAME]

[PRINCIPLE_3_DESCRIPTION]

## Scope

[PROJECT_SCOPE_DESCRIPTION]

## Development Workflow

- All work happens on feature branches, merged to `main` via pull request.
- Follow the spec-kit workflow: specify → plan → tasks → implement.
- Commit after each logical unit of work with a descriptive message.
- Keep PRs focused — one feature or fix per PR.

## Governance

This constitution is the highest-priority reference for all implementation decisions. If a spec
or plan conflicts with a principle here, the constitution wins. Amendments require updating this
file, incrementing the version, and noting the change in the sync impact report comment above.

**Version**: 0.0.0 | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]
