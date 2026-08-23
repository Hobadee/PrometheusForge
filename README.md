# Prometheus Forge

PowerShell 7+ module: onboarding/offboarding checklist engine following Module-Builder layout.

Usage (quick):

```powershell
Import-Module .\PrometheusForge.psd1
Invoke-Forge -FilePath .\Samples\SampleOnboard.yaml
```

Precedence: Base Config → Client-level Config → Run (instance-level) overrides.

See `Invoke-Forge` help for options.

Defaults and behavior:

- Default run mode is **non-interactive (Abort on error)**.
- Tasks run **serially** in dependency order (no parallel execution).
- Current plugin MVP: `TextOutputPlugin` (prints Task name and ID).

# Requirements
This project required the `powershell-yaml` module from [github.com/cloudbase/powershell-yaml](https://github.com/cloudbase/powershell-yaml)

```
Install-Module powershell-yaml
```

# Notes
We should allow unlimited overlays.  Overlays should simply overwrite anything previous at the various keys and values, or add new keys.`
Method of deleting keys/subkeys should be given by specifying parent key and giving a null plugin or something.  (Needs to be
an actual nullifyer so we can kill children and don't dive into them)

Okay - overlays may be harder than I thought.  An overlay that edits or deletes should be easier, but an overlay that adds is a problem.
Adding items makes the exact positioning abiguous.  It may be possible to do a specifiction such as "after: item A" or something, but
then we need to create a position solver.


# Potential Names
- NABIB (Not Ansible But Inspired By)

# TODO
- We need a way of backtracing an item hierarchy and printing it out to the user nicely
