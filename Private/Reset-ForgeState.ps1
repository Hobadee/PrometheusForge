function Reset-ForgeState {
    <#
    .SYNOPSIS
    Resets run-scoped singleton state so each Invoke-Forge (or Test-*) call starts clean.

    .DESCRIPTION
    Several classes (Variables, Steps, PendingOverlays) use a singleton pattern to share state across a single
    workflow run. Because singletons are static, they otherwise persist across multiple calls
    within the same PowerShell session. This function clears those singletons back to an
    uninitialized state; the next GetInstance() call will construct a fresh instance.

    Plugin registries (sourcePluginRegistry, taskPluginRegistry) are intentionally NOT reset
    here, since plugin registration happens once at module load time and must persist across runs.

    .NOTES
    Add a call to the relevant class's static Reset() method here whenever a new run-scoped
    singleton is introduced.
    #>
    [CmdletBinding()]
    param ()

    [Log]::Reset()
    [Variables]::Reset()
    [Steps]::Reset()
    [PendingOverlays]::Reset()

    # Note: We actually DO NOT want to reset plugin singletons here.
    # Plugins should be completely independent of all other logic, including logic here.
    # Possibly allow a Forge API method to reset plugin singletons in the future, but not currently implemented.
    #[AsanaApiClient]::Reset()
}
