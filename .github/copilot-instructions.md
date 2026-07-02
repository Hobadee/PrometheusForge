<!-- .github/copilot-instructions.md - guidance for AI coding agents -->
# Quick context
- Repo: `Lifecycle` — a PowerShell 7+ module that implements a class-based onboarding/offboarding checklist engine driven by YAML configs.
- Key entry points: `Invoke-Lifecycle` (run a checklist), `Test-Config` (parse YAML).
- Module is built from multiple independant files using the `Build-Module` command and follows the PoshCode conventions.

# Where to look (fast path)
- Classes are stored in the `Classes` directory, and may be organized in subdirectories by functionality.
- Publicly exported functions once the module is built are located in the `Public` directory.
- Internal functions are in the `Private` directory.
- Pester Tests are in the `Tests` directory.
- Files may be prefixed with numbers to indicate load order (e.g., `01-Task.ps1` loads before `02-Config.ps1`).

# Architecture & behavior notes (important for edits)
- Plugin model: implement `taskPluginInterface` interface (see `Classes/Plugins/TaskPluginInterface.ps1`)
- YAML parsing requires the `powershell-yaml` module (see `Lifecycle.Onboarding.psd1` RequiredModules). If missing, install with `Install-Module powershell-yaml`.

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
Invoke-Pester
``` 
- A makefile is provided to simplify common tasks like building the module and running tests. You can use commands like `make` and `make test` to perform these actions.
- `make shell` exists to open an interactive PowerShell session with the module imported so you can play with it.
- Automake may not be available on all systems; makesfiles are available to ease development on *NIX systems from a Bash environment.
  On Windows, you may need to install it separately or rely on other means to run the makefile commands.

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

# Testing
- Unit tests are written using Pester and are located in the `Tests` directory.
- Ensure the module is built and before running tests
- Module import in tests is done by adding the following line at the top of each test file:
  `Using Module "../../../build/Lifecycle/Lifecycle.psd1"`
  The number of "../" needs to be adjusted depending on the location of the test file relative to the module.
- The tests directory has 2 top level directories; Public and Private.  Tests for public functions go in the `Public` directory, and tests for internal/private functions or classes go in the `Private` directory.
  Tests inside the respective public or private directories should follow the directory structure of the code being tested.  For example, if testing `Classes/Plugins/TaskPluginInterface.ps1`,
  the test should be located at `Tests/Private/Classes/Plugins/TaskPluginInterface.Tests.ps1` (or `Public` if testing a public function).

```powershell
Build-Module
Invoke-Pester
```

# Pester Quirks & Known Issues
## Type Coercion in Parameter Validation
When validating string parameters with `$null`, PowerShell coerces `$null` to an empty string before the method executes. This breaks `$null` checks:
```powershell
[void] ValidateKey([string] $key) {
    if ($null -eq $key) { # NEVER TRUE - $key is "" not $null
        throw [System.ArgumentNullException]::new("key", "Key cannot be null")
    }
}
```
**Fix:** Use `[string]::IsNullOrEmpty()` to catch both null and empty strings:
```powershell
[void] ValidateKey([string] $key) {
    if ([string]::IsNullOrEmpty($key)) { # WORKS correctly
        throw [System.ArgumentNullException]::new("key", "Key cannot be null or empty")
    }
}
```
Furthermore, please alert the user of validation methods that accept coerced types instead of objects (ie `[string]` instead of `[object]`) as this coercion
may cause unexpected behavior in validation, since the parameter may have already been coerced to a type that bypasses intended checks. In such cases, accepting `[object]` allows the validation method to inspect the raw input before any coercion occurs.  DO NOT auto-correct these however!  There may be cases where coercion is desired, so do not blindly change concrete types to `[object]` without understanding the context.

## Generic Types with `-BeOfType` and `-ExceptionType`
When passing types directly in brackets to Pester assertions, PowerShell parses them as object arrays instead of single types:
```powershell
# FAILS: Type parsed as System.Object[]
$dict | Should -BeOfType [System.Collections.Generic.Dictionary[string, object]]
{ ... } | Should -Throw -ExceptionType ([System.ArgumentNullException])
```
**Fix:** Store the type in a variable first:
```powershell
# WORKS: Variable forces proper type resolution
$expectedType = [System.Collections.Generic.Dictionary[string, object]]
$dict | Should -BeOfType $expectedType

$exceptionType = [System.ArgumentNullException]
{ ... } | Should -Throw -ExceptionType $exceptionType
```
