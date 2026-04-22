# Implementation Plan: Ignore Generated Outputs And Local Artifacts

**Branch**: `001-ignore-generated-outputs` | **Date**: 2026-04-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ignore-generated-outputs/spec.md`

## Summary

Reduce day-to-day Git noise in this Pi-hole repository by tightening local ignore rules for generated CSV exports, export logs, local secret helpers, and machine-specific workspace artifacts, while preserving visibility for real source files and documenting the intended boundary between local/generated files and shared project content.

## Technical Context

**Language/Version**: PowerShell 7-style repository scripts on Windows; git-based repo workflow  
**Primary Dependencies**: Git, PowerShell, existing repository scripts under repo root and `Lists/`  
**Storage**: File-based repository content, generated CSV outputs, local secret files, and log files  
**Testing**: Manual verification with `git status --short` and file creation/update scenarios  
**Target Platform**: Windows workstation managing a remote Pi-hole over SSH  
**Project Type**: Operator automation repository  
**Performance Goals**: Ignore behavior must keep normal `git status` output focused on real source changes  
**Constraints**: Must preserve current in-repo export workflow; must not hide tracked source files; must keep secrets local  
**Scale/Scope**: Repository-level ignore and documentation change affecting root files, generated outputs, and local workspace artifacts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **PowerShell-First Operator Experience**: Pass. The plan keeps the existing PowerShell workflow intact and does not require moving to Bash, Python, or external tooling.
- **Safe-by-Default Pi-hole Operations**: Pass. The feature changes repository hygiene only; it does not alter remote Pi-hole state.
- **Deterministic Data Handling**: Pass. Generated CSV outputs remain where scripts expect them; only Git visibility changes.
- **Secret Hygiene Is Non-Negotiable**: Pass. Local secret helpers remain excluded from commits and are further clarified in docs.
- **Documentation Ships With Automation**: Pass, contingent on updating README and/or related workflow docs in the same change.

No constitution violations are expected for this feature.

## Project Structure

### Documentation (this feature)

```text
specs/001-ignore-generated-outputs/
├── plan.md              # This file
└── spec.md              # Feature specification
```

### Source Code (repository root)

```text
.
├── .gitignore
├── README.md
├── .github/
├── .specify/
├── logs/
├── Lists/
├── Export-PiHoleAllowedQueries.ps1
├── Export-PiHoleBlockedQueries.ps1
├── Export-PiHoleQueries.ps1
├── Invoke-ScheduledExport.ps1
├── Setup-ExportSchedule.ps1
└── Remove-DuplicateCsvRows.ps1
```

**Structure Decision**: This is a repository-hygiene feature, so the implementation stays at the repo root. The primary changes are expected in `.gitignore` and `README.md`, with verification against the current generated artifact locations already used by the PowerShell scripts.

## Phase 0 Research

1. Inspect current `.gitignore` coverage and compare it with actual generated and local artifacts currently appearing in the repository.
2. Confirm which artifacts are intentional source files versus operator-local files:
   - Generated CSV exports and deduplicated outputs
   - `logs/` output
   - local secret helper files
   - machine-specific workspace files such as `.vscode/`
3. Identify edge cases where overly broad ignore rules could hide legitimate repository content.

## Phase 1 Design

1. Define the minimal ignore rule set needed to satisfy the spec without masking real source content.
2. Decide whether rules should be file-specific, folder-specific, or pattern-based based on the current repo layout.
3. Document the operational boundary clearly:
   - which files are generated
   - which files are local-only
   - how to intentionally include an ignored file when needed
4. Re-check the constitution after the ignore-rule design is complete.

## Implementation Strategy

### Step 1 - Refine Ignore Rules

- Update `.gitignore` to cover all known generated outputs and local artifacts currently treated as noise.
- Keep rules as specific as practical so intentionally versioned source and curated list files remain visible.

### Step 2 - Update Documentation

- Add or adjust guidance in `README.md` explaining:
  - which files are expected to remain local
  - which generated outputs are ignored
  - why those artifacts are excluded from normal commits
  - how to intentionally force-add an ignored file when there is a real need to share it

### Step 3 - Verify Behavior

- Confirm `git status --short` no longer reports covered generated/local artifacts.
- Confirm tracked files such as scripts and docs still appear when edited.
- Confirm a new non-ignored source file still appears as untracked.

## Verification Plan

- **VP-001**: Run `git status --short` before and after ignore-rule changes to confirm generated CSVs, logs, and local helper files stop appearing as noise.
- **VP-002**: Edit a tracked source file such as `README.md` or a `.ps1` script and confirm Git still reports the modification.
- **VP-003**: Create a temporary non-ignored file in a source-relevant path and confirm Git still reports it as untracked.
- **VP-004**: Review documentation text to confirm it clearly separates local/generated artifacts from shared source content.

## Risks And Mitigations

- **Risk**: Overly broad ignore patterns hide meaningful repository files.
  **Mitigation**: Prefer targeted patterns and verify tracked/editable files still appear in Git.

- **Risk**: Existing tracked generated artifacts do not disappear from Git status just because they are added to `.gitignore`.
  **Mitigation**: Document that previously tracked files require explicit untracking if the repo decides to stop versioning them.

- **Risk**: Future export scripts write to new paths not covered by the current rules.
  **Mitigation**: Keep documentation explicit about expected artifact locations and update ignore rules alongside workflow changes.

## Out Of Scope

- Moving generated outputs to a different directory outside the repository
- Building a separate artifact-retention or cleanup subsystem
- Changing remote Pi-hole query/export behavior beyond what is needed to document local artifact handling

## Complexity Tracking

No constitution exceptions or unusual complexity are expected for this feature.
