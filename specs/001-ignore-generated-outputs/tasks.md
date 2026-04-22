# Tasks: Ignore Generated Outputs And Local Artifacts

**Input**: Design documents from `/specs/001-ignore-generated-outputs/`
**Prerequisites**: plan.md, spec.md

**Tests**: No separate automated test suite is required by the feature spec. Verification is performed through targeted `git status --short` checks and documentation review.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`US1`, `US2`, `US3`)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Capture the current repository-noise baseline and confirm the artifact paths this feature will manage.

- [x] T001 Review current ignore coverage and working-tree noise using `git status --short` from the repository root
- [x] T002 Inspect the current artifact locations and local-only files referenced by `.gitignore`, `README.md`, and the export workflow scripts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define the repository boundary between ignored local/generated artifacts and shared source files before changing behavior

**⚠️ CRITICAL**: No user story work should begin until this boundary is confirmed

- [x] T003 Define the exact ignore categories for this feature in `specs/001-ignore-generated-outputs/plan.md` and confirm they do not hide intentional repository content
- [x] T004 Identify any currently tracked artifacts that would need explicit untracking guidance if the repo later stops versioning them

**Checkpoint**: Repository artifact boundary is clear and user story work can proceed safely

---

## Phase 3: User Story 1 - Clean Working Tree For Daily Use (Priority: P1) 🎯 MVP

**Goal**: Keep generated exports, logs, and local machine artifacts out of normal Git status output

**Independent Test**: Generate or update known local artifacts, then confirm `git status --short` no longer reports them while real source edits still appear

### Implementation for User Story 1

- [x] T005 [US1] Update `.gitignore` to cover generated query export outputs and deduplicated CSV outputs used by the current workflow
- [x] T006 [US1] Update `.gitignore` to cover export log artifacts under `logs/` without hiding shared source files
- [x] T007 [US1] Update `.gitignore` to cover local-only machine artifacts such as workspace settings that are not part of shared project behavior
- [x] T008 [US1] Verify with `git status --short` that covered generated and local-only artifacts are no longer reported from the repository root

**Checkpoint**: User Story 1 should now deliver a cleaner working tree for normal daily use

---

## Phase 4: User Story 2 - Preserve Intentional Repository Content (Priority: P2)

**Goal**: Ensure the new ignore rules stay narrow and do not mask real source changes

**Independent Test**: Edit tracked source files and create a non-ignored source-like file, then confirm Git still reports them normally

### Implementation for User Story 2

- [x] T009 [US2] Review the updated `.gitignore` patterns and tighten any broad matches that could hide tracked scripts, documentation, curated lists, or intentional automation files
- [x] T010 [US2] Verify that edits to tracked source files such as `README.md` and repository `.ps1` files still appear in `git status --short`
- [x] T011 [US2] Verify that a new non-ignored source file still appears as untracked and document any adjustment needed to preserve that behavior

**Checkpoint**: User Stories 1 and 2 should now work together without trading Git noise for hidden source changes

---

## Phase 5: User Story 3 - Understand What Is Local Versus Shared (Priority: P3)

**Goal**: Document the boundary between local/generated artifacts and shared repository content for future maintainers

**Independent Test**: Read the updated documentation and confirm it clearly explains what stays local, what is ignored, and how to intentionally include an ignored artifact when needed

### Implementation for User Story 3

- [x] T012 [US3] Update `README.md` to explain which generated artifacts and local-only helper files are intentionally excluded from normal commits
- [x] T013 [US3] Document in `README.md` how maintainers can intentionally include an otherwise ignored artifact when there is a specific troubleshooting or sharing need
- [x] T014 [US3] Review the updated documentation against the current local setup/export workflow to ensure it matches the real operator experience

**Checkpoint**: All user stories should now be independently functional and understandable to a future maintainer

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup across the feature

- [x] T015 [P] Re-run `git status --short` and compare the result to the baseline captured in T001
- [x] T016 [P] Review `specs/001-ignore-generated-outputs/spec.md`, `plan.md`, and `tasks.md` for alignment with the implemented ignore/documentation changes
- [x] T017 Summarize any residual risk, especially around previously tracked generated artifacts that `.gitignore` alone will not remove from Git history or index tracking

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup completion and defines the safe ignore boundary
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on User Story 1 changes being present for review and verification
- **User Story 3 (Phase 5)**: Depends on the final intended ignore behavior being known
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: First deliverable and MVP for this feature
- **User Story 2 (P2)**: Builds on US1 by validating the safety and precision of the ignore rules
- **User Story 3 (P3)**: Documents the behavior established by US1 and refined by US2

### Parallel Opportunities

- T001 and T002 can be done in parallel
- T015 and T016 can be done in parallel
- Within implementation, documentation review can begin once the intended ignore-rule behavior is stable

---

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases
2. Complete User Story 1
3. Stop and verify that generated/local artifacts no longer pollute `git status --short`

### Incremental Delivery

1. Deliver US1 to clean the working tree
2. Deliver US2 to prove source visibility is preserved
3. Deliver US3 to make the behavior understandable and maintainable

### Notes

- Keep ignore patterns as narrow as practical
- Do not assume `.gitignore` alone removes already tracked files from Git
- Prefer verification from the repository root so results match normal operator usage
