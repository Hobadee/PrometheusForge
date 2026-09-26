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


    $mainPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $FilePath)
    [Log]::Info("Loading configuration from '$($mainPlugin.URI.LocalPath)'.")
    $cfg = $mainPlugin.Load()

    $configuration.SetMany($cfg.variables)

    if ($null -ne $Overlay) {
        foreach ($overlayPath in $Overlay) {
            $overlayPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $overlayPath)
            [Log]::Info("Applying overlay '$($overlayPlugin.URI.LocalPath)'.")
            $overlayCfg = $overlayPlugin.Load()
            $configuration.SetMany($overlayCfg.variables)
        }
    }

    # Apply variables AFTER overlays - they have the highest precedence
    $configuration.SetMany($Variables)

    if ($null -ne $cfg.root) {
        $itemConfig = $cfg.root
    }
    else {
        throw [System.ArgumentException]::new("The YAML configuration at '$FilePath' must contain a top-level 'root' property.", 'FilePath')
    }

    [Log]::Info("Running with Include Tags: $($configuration.GetIncludeTags())")
    [Log]::Info("Running with Exclude Tags: $($configuration.GetExcludeTags())")

    $stepTree = [StepTree]::new($itemConfig)

    $stepTree.Process() | Out-Null

    if ($OutputLogs) {
        return [Log]::GetInstance()
    }
    
}
