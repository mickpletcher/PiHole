# Feature Specification: Ignore Generated Outputs And Local Artifacts

**Feature Branch**: `001-ignore-generated-outputs`  
**Created**: 2026-04-22  
**Status**: Draft  
**Input**: User description: "Prevent generated exports, logs, and local machine artifacts from being treated as source files in this Pi-hole repository"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clean Working Tree For Daily Use (Priority: P1)

As a maintainer running Pi-hole exports and cleanup scripts locally, I want generated outputs and machine-local files to stay out of normal source control status so I can immediately see real source changes without sorting through CSVs, logs, or secret helpers.

**Why this priority**: The repository already produces large generated outputs during normal operation. If those files keep appearing as untracked or modified content, the repo becomes noisy and it is harder to review, commit, or safely reason about actual source changes.

**Independent Test**: Can be fully tested by generating or updating the known local artifacts in the repo and confirming `git status --short` does not report them while still reporting real source edits.

**Acceptance Scenarios**:

1. **Given** the repository contains generated query CSV files, de-duplicated CSV files, and export logs created by the normal scripts, **When** the maintainer runs `git status`, **Then** those generated artifacts are not shown as changes to commit.
2. **Given** the repository contains local secret helper files and machine-specific workspace files, **When** the maintainer runs `git status`, **Then** those local-only artifacts are not shown as changes to commit.

---

### User Story 2 - Preserve Intentional Repository Content (Priority: P2)

As a maintainer, I want the ignore rules to be narrow enough that actual repository source files, documentation, and intentionally versioned configuration still show up in Git, so cleanup does not accidentally hide meaningful work.

**Why this priority**: Hiding too much is almost as risky as hiding too little. The repository needs a predictable boundary between generated/local artifacts and intentional project files.

**Independent Test**: Can be fully tested by editing tracked source files such as PowerShell scripts, README content, and intentionally versioned list files and confirming Git still reports those edits.

**Acceptance Scenarios**:

1. **Given** a maintainer edits a tracked script or documentation file, **When** they run `git status`, **Then** that source change still appears normally.
2. **Given** the repository contains ignore rules for generated outputs, **When** a maintainer creates a new tracked source file outside the ignored patterns, **Then** Git still reports the new file as untracked.

---

### User Story 3 - Understand What Is Local Versus Shared (Priority: P3)

As a future maintainer cloning the repo on a new machine, I want the repository documentation to clearly distinguish generated files and local-only helper files from shared source files, so I know what should remain local and what belongs in commits.

**Why this priority**: This repo is operator-focused. Clear documentation reduces accidental commits of secrets and avoids confusion about whether generated exports or logs are expected to live in Git.

**Independent Test**: Can be fully tested by reading the updated documentation and verifying it explains which files are local/generated, why they are ignored, and how to recreate them.

**Acceptance Scenarios**:

1. **Given** a new maintainer reads the repository guidance, **When** they review the local setup and export workflow sections, **Then** they can tell which files are intentionally local and excluded from commits.
2. **Given** the ignore behavior changes, **When** the documentation is updated with the feature, **Then** the maintainer can reproduce the local workflow without needing tribal knowledge.

---

### Edge Cases

- What happens when a maintainer intentionally wants to commit a generated sample artifact for documentation or troubleshooting? The feature must not make that impossible to do deliberately.
- How does the repository handle nested generated files, such as logs written into a dedicated folder or future export outputs written beside scripts?
- What happens when a local editor or tooling folder contains useful shared settings and some user-specific files? The feature must define the intended boundary explicitly.
- How does the ignore strategy behave if an existing generated file was previously tracked? The workflow must define how maintainers reconcile that state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST ignore generated DNS export CSV outputs produced by the local Pi-hole export workflow during normal use.
- **FR-002**: The repository MUST ignore generated log files and log directories produced by scheduled or manual export runs during normal use.
- **FR-003**: The repository MUST ignore local-only secret and credential helper files used for SSH, sudo, or machine-specific execution.
- **FR-004**: The repository MUST ignore machine-local workspace artifacts that are not required for shared project behavior.
- **FR-005**: The ignore configuration MUST remain narrow enough that tracked source files, documentation, curated list files, and intentionally versioned automation files continue to appear in Git status.
- **FR-006**: Repository documentation MUST describe which categories of files are intentionally local or generated and therefore excluded from normal commits.
- **FR-007**: The feature MUST define how maintainers can intentionally include an otherwise ignored artifact when there is a specific need to share it.
- **FR-008**: The feature MUST preserve the existing local operator workflow for running exports, deduplication, and scheduled tasks without requiring files to be moved outside the repository.

### Key Entities *(include if feature involves data)*

- **Generated Artifact**: Any file or directory produced by running repository automation rather than authored as project source, including query exports, deduplicated outputs, and export logs.
- **Local Secret Helper**: Any local-only file that stores credentials, host-specific settings, or environment bootstrap logic for the current machine.
- **Shared Source File**: A file intentionally maintained in Git as part of the project, such as scripts, curated lists, templates, and documentation.
- **Ignore Rule**: A repository rule that determines whether a file is treated as local/generated noise or as source content requiring Git visibility.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After running the normal export workflow, `git status` shows no generated CSV or log artifacts as pending changes.
- **SC-002**: After creating or updating supported local secret helper files, `git status` shows no secret-helper artifacts as pending changes.
- **SC-003**: After modifying a tracked script or documentation file, Git still reports that change immediately and clearly.
- **SC-004**: A maintainer unfamiliar with the repo can read the updated documentation and correctly identify which generated/local artifacts should stay uncommitted.

## Assumptions

- The repository will continue to generate CSV exports and logs inside the repo root or known subfolders as part of the current operator workflow.
- Maintainers prefer reducing Git noise inside the existing repository layout over relocating outputs to another external directory.
- Local credential helper files will continue to be recreated per machine and are not intended to be shared through Git.
- The first implementation can focus on ignore behavior and documentation clarity rather than introducing a larger artifact-management subsystem.
