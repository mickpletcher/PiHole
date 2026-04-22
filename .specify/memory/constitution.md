# PiHole Spec Constitution

## Core Principles

### I. PowerShell-First Operator Experience
All automation and examples MUST work in PowerShell on Windows without requiring WSL. New workflows SHOULD prefer native PowerShell scripts and conventions already used in this repository. If an additional Bash or Python path is proposed, the PowerShell operator path MUST remain first-class and documented.

### II. Safe-by-Default Pi-hole Operations
Changes MUST minimize risk to the live Pi-hole instance. Read-only collection and export flows are preferred by default. Any behavior that modifies Pi-hole configuration, gravity lists, allowlists, scheduled tasks, or remote system state MUST be explicit, reversible where practical, and clearly documented before use.

### III. Deterministic Data Handling
Exports and transforms MUST produce stable, documented outputs that are safe to process repeatedly. CSV schemas, filtering rules, de-duplication behavior, and time-window semantics MUST remain predictable across runs. Large query datasets SHOULD be streamed or processed incrementally when practical instead of assuming small in-memory inputs.

### IV. Secret Hygiene Is Non-Negotiable
Credentials, passwords, host-specific settings, and generated local artifacts MUST stay out of committed source by default. Features that touch authentication or remote execution MUST support secure local configuration patterns consistent with this repository, including ignored `.local.*` files, environment variables, and documented cleanup steps.

### V. Documentation Ships With Automation
Every operator-facing feature MUST include concise usage guidance in the repository docs or inline help. When behavior changes, examples, prerequisites, defaults, and safety caveats MUST be updated in the same change so a new maintainer can run the workflow without guesswork.

## Technical Constraints

- The primary implementation language is PowerShell (`.ps1`).
- The repo targets Pi-hole administration and DNS-query exports over SSH.
- Scripts SHOULD preserve compatibility with the existing repository structure and file naming patterns.
- Generated CSV and log artifacts SHOULD remain excluded from normal source control unless there is an explicit reason to version them.
- New dependencies SHOULD be justified and lightweight; built-in PowerShell capabilities are preferred when they keep the operator workflow simpler.

## Development Workflow

- Use Spec Kit for behavior-affecting work: create or update a spec before substantial new features, workflow changes, or remote-operation changes.
- During `/speckit.specify`, focus on operator outcomes and safety expectations before implementation details.
- During `/speckit.plan`, capture remote-command behavior, credential handling, expected outputs, rollback considerations, and test/verification steps.
- Validation for a completed change SHOULD include the safest available proof, such as syntax checks, dry-run modes, fixture-based tests, or documented manual verification commands when live Pi-hole access is required.
- Reviews MUST check for constitution compliance, especially around secret handling, destructive behavior, and documentation completeness.

## Governance

This constitution governs Spec Kit work in this repository and takes precedence over ad hoc prompts or undocumented habits. Amendments MUST be committed alongside a short rationale and any required README or workflow updates. Every spec, plan, and implementation review SHOULD verify compliance with these principles before code is merged.

**Version**: 1.0.0 | **Ratified**: 2026-04-22 | **Last Amended**: 2026-04-22
