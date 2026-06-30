# Lifecycle.Onboarding

PowerShell 7+ module: onboarding/offboarding checklist engine following Module-Builder layout.

Usage (quick):

```powershell
Import-Module .\Lifecycle.Onboarding.psm1
Invoke-Onboarding -ConfigPath .\examples\sample-master.yml -RunPath .\examples\sample-run.yml
```

Precedence: Base Config → Client-level Config → Run (instance-level) overrides.

See `Invoke-Lifecycle` help for options.

Defaults and behavior:

- Default run mode is **non-interactive (Abort on error)**.
- Tasks run **serially** in dependency order (no parallel execution).
- Current plugin MVP: `TextOutputPlugin` (prints Task name and ID).

# Requirements
This project required the `powershell-yaml` module from [github.com/cloudbase/powershell-yaml](https://github.com/cloudbase/powershell-yaml)

```
Install-Module powershell-yaml
```
