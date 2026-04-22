# Upgrades

This directory tracks completed repository upgrades that are part of the shared project history.

## Completed Upgrades

### 2026-04-22: Shared PowerShell Helpers For Export Workflows

This upgrade added a shared helper script, [PiHole.Common.ps1](../PiHole.Common.ps1), to centralize common PowerShell plumbing used by the query export workflow.

The upgrade included:

- shared SSH execution helpers for probing and running remote SQLite commands
- shared credential lookup and fallback handling for SSH and sudo passwords
- shared logging helpers for console and file-based scheduled export logs
- shared output-path and parent-directory handling
- shared CSV conversion and query export logic used by both allowed and blocked export scripts

The following scripts were refactored to use the shared helper instead of repeating the same plumbing:

- [Export-PiHoleAllowedQueries.ps1](../Export-PiHoleAllowedQueries.ps1)
- [Export-PiHoleBlockedQueries.ps1](../Export-PiHoleBlockedQueries.ps1)
- [Export-PiHoleQueries.ps1](../Export-PiHoleQueries.ps1)
- [Invoke-ScheduledExport.ps1](../Invoke-ScheduledExport.ps1)

Result: the export workflow now has one shared implementation path for SSH execution, credential resolution, logging, and error-handling behavior, which makes future upgrades easier and lowers the risk of drift between scripts.
