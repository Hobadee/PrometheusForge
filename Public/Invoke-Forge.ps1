function Invoke-Forge {
    <#
    .SYNOPSIS
    Loads and executes a lifecycle checklist from a YAML file.

    .DESCRIPTION
    Reads the specified YAML configuration, validates that the file exists and is readable,
    parses the workflow definition, creates item objects from the configuration, and executes
    each loaded item in order.

    .PARAMETER FilePath
    The path to the YAML lifecycle definition to load and run.

    .PARAMETER Overlay
    One or more overlay YAML files. Overlay files are processed in the order provided,
    and each overlay's `variables` keys overwrite previously set values in Variables.
    An overlay may also define a top-level `root` - in the same shape as the main YAML's
    `root` (a single step/section config, or a list of them) - to queue step/section
    overlays instead of/in addition to `variables`; an overlay's `root` never runs as its
    own tree. Each entry is queued as a ForgeConfigurationApi overlay targeting its own
    `slug`, and is applied the next time a StepTree node with that slug is processed - the
    same mechanism plugins use via Api.Configuration.RequestOverlay(). A later overlay file's
    entry wins when two target the same slug.

    .PARAMETER Variables
    A hashtable of variable names and values to set in the configuration. These variables overwrite any previously set values from the main YAML file or overlays.

    .OUTPUTS
    System.Boolean
    Returns $true when the workflow items complete successfully.

    .EXAMPLE
    Invoke-Forge -FilePath ./Samples/SampleOnboard.yaml

    .EXAMPLE
    Invoke-Forge -FilePath ./Samples/SampleOnboard.yaml -Overlay ./Samples/OverlayA.yaml, ./Samples/OverlayB.yaml

    .EXAMPLE
    Invoke-Forge -FilePath ./Samples/SampleOnboard.yaml -Variables @{ environment = 'production'; region = 'east' }

    .NOTES
    This function supports standard PowerShell common parameters such as -Verbose and -Debug.

    Passing Verbose on it's own sets the log level to Info.
    Passing Debug on it's own sets the log level to Debug.
    Passing both Verbose and Debug sets the log level to Trace.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $Overlay = @(),
        [hashtable] $Variables = @{},

        [switch] $OutputLogs
    )

    Reset-ForgeState


    $configuration = [Variables]::GetInstance()


    # With [CmdletBinding()], use $PSCmdlet to get preference variables from caller scope
    $verboseEnabled = $PSBoundParameters['Verbose'] -eq $true
    $debugEnabled = $PSBoundParameters['Debug'] -eq $true

    # Verbose = Info
    # Debug = Debug
    # Verbose & Debug = Trace
    if ($verboseEnabled -and $debugEnabled) {
        $configuration.Set('logTerminalLevel', 'Trace')
    }
    elseif ($verboseEnabled) {
        $configuration.Set('logTerminalLevel', 'Info')
    }
    elseif ($debugEnabled) {
        $configuration.Set('logTerminalLevel', 'Debug')
    }


    # Load the main configuration file
    $mainPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $FilePath)
    [Log]::Info("Loading configuration from '$($mainPlugin.URI.LocalPath)'.")
    $cfg = $mainPlugin.Load()
    $configuration.SetMany($cfg.variables)

    $pendingOverlays = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $Overlay) {
        foreach ($overlayPath in $Overlay) {
            $overlayPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $overlayPath)
            [Log]::Info("Applying overlay '$($overlayPlugin.URI.LocalPath)'.")
            $overlayCfg = $overlayPlugin.Load()
            $configuration.SetMany($overlayCfg.variables)

            # An overlay's `root` is never processed as its own tree - each entry (a single
            # config, or a list of them, same as the main YAML's `root`) is queued as an
            # overlay targeting its own slug instead. @(...) normalizes both shapes into a
            # flat collection without unrolling a single hashtable's own keys.
            if ($null -ne $overlayCfg.root) {
                $pendingOverlays.AddRange([object[]] @($overlayCfg.root))
            }
        }
    }

    # Apply CLI variables AFTER overlays - they have the highest precedence
    $configuration.SetMany($Variables)

    if ($null -ne $cfg.root) {
        $itemConfig = $cfg.root
    }
    else {
        throw [System.ArgumentException]::new("The YAML configuration at '$FilePath' must contain a top-level 'root' property.", 'FilePath')
    }

    [Log]::Debug("Running with Include Tags: $($configuration.GetIncludeTags())")
    [Log]::Debug("Running with Exclude Tags: $($configuration.GetExcludeTags())")

    $stepTree = [StepTree]::new($itemConfig)

    # Queue overlay-requested step/section overlays now that the root StepTree exists (so
    # their target slugs are registered) but before Process() starts walking it, so every
    # overlay is pending from the very first node visited.
    if ($pendingOverlays.Count -gt 0) {
        $configurationApi = [ForgeConfigurationApi]::new()
        foreach ($overlayConfig in $pendingOverlays) {
            [Log]::Info("Queuing overlay for slug '$($overlayConfig.slug)'.")
            $configurationApi.RequestOverlay($overlayConfig.slug, $overlayConfig)
        }
    }

    $stepTree.Process() | Out-Null

    # Surface any overlay that was requested but never had a matching slug to apply to
    # (typo'd target, or a target that was skipped by conditionals).
    foreach ($slug in [PendingOverlays]::GetInstance().GetPendingSlugs()) {
        [Log]::Warning("An overlay was requested for slug '$slug' but was never applied; no step or section with that slug was processed during this run.")
    }
    

    if ($OutputLogs) {
        return [Logs]::GetInstance()
    }
    
}
