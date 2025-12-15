<!-- .github/copilot-instructions.md - guidance for AI coding agents -->
# Quick context
- Repo: `Lifecycle` — a PowerShell 7+ module that implements a class-based onboarding/offboarding checklist engine driven by YAML configs.
- Key entry points: `Invoke-Lifecycle` (run a checklist), `Test-Config` (parse YAML).

# Where to look (fast path)
- Classes are stored in the `Classes` directory, and may be organized in subdirectories by functionality.
- Publicly exported functions once the module is built are located in the `Public` directory.
- Internal functions are in the `Private` directory.
- Pester Tests are in the `Tests` directory.
- Files may be prefixed with numbers to indicate load order (e.g., `01-Task.ps1` loads before `02-Config.ps1`).

# Architecture & behavior notes (important for edits)
- Plugin model: implement `taskPlugin` interface (see `Classes/Plugins/TaskPlugin.ps1`)

# Developer workflows (commands)
- Import and play interactively in PS7:
```powershell
Build-Module
Import-Module .\build\Lifecycle\Lifecycle.psd1 -Force
```
- Run unit tests (requires Pester):
```powershell
# from repo root
Build-Module
Import-Module .\build\Lifecycle\Lifecycle.psd1 -Force
Invoke-Pester
``` 
- YAML parsing requires the `powershell-yaml` module (see `Lifecycle.Onboarding.psd1` RequiredModules). If missing, install with `Install-Module powershell-yaml`.

# Project conventions to follow (do not invent new ones without discussion)
- Numbered prefixes on files indicate load/compile order (especially in `Classes/`) if classes are dependant on other classes.

# Typical PRs an AI agent can help with (concrete, test-focused)
- This project is under heavy active development. AI agents can help with:
  - Implementing new features (e.g., Retry, Override Merging)
  - Fixing bugs
  - Improving documentation
  - Enhancing unit tests

# Notes & limitations
- The codebase is intentionally small/MVP: some behaviors are stubs or minimal (e.g., override merging and retry semantics). Only document and modify what is discoverable from code and tests.
- The `powershell-yaml` module is required for YAML parsing. Ensure it is installed before running the module or tests.
- The `Build-Module` command is used to compile the module. Ensure it is available
- Always ensure `Build-Module; Import-Module .\build\Lifecycle\Lifecycle.psd1 -Force` is run before any testing to ensure the latest changes are loaded.
