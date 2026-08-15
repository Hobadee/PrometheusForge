function Invoke-Lifecycle {
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
    and each overlay's `variables` keys overwrite previously set values in Configuration.

    .OUTPUTS
    System.Boolean
    Returns $true when the workflow items complete successfully.

    .EXAMPLE
    Invoke-Lifecycle -FilePath ./Samples/SampleOnboard.yaml

    .EXAMPLE
    Invoke-Lifecycle -FilePath ./Samples/SampleOnboard.yaml -Overlay ./Samples/OverlayA.yaml, ./Samples/OverlayB.yaml

    .NOTES
    This function supports standard PowerShell common parameters such as -Verbose and -Debug.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $Overlay = @()
    )

    $mainPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $FilePath)
    Write-Verbose "Loading configuration from '$($mainPlugin.URI.LocalPath)'."
    $cfg = $mainPlugin.Load()

    $configuration = [Configuration]::GetInstance()
    $configuration.SetMany($cfg.variables)

    if ($null -ne $Overlay) {
        foreach ($overlayPath in $Overlay) {
            $overlayPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $overlayPath)
            Write-Verbose "Applying overlay '$($overlayPlugin.URI.LocalPath)'."
            $overlayCfg = $overlayPlugin.Load()
            $configuration.SetMany($overlayCfg.variables)
        }
    }

    if ($null -ne $cfg.root) {
        $itemConfig = $cfg.root
    }
    else {
        throw [System.ArgumentException]::new("The YAML configuration at '$FilePath' must contain a top-level 'root' property.", 'FilePath')
    }

    $items = [ItemFactory]::Create($itemConfig)

    $items.Process() | Out-Null

    return $true
}
