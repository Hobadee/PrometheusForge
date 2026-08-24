function Test-Steps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $Overlay = @()
    )

    $mainPlugin = [sourcePluginFactory]::GetPlugin('yamlSource', $FilePath)
    Write-Verbose "Loading configuration from '$($mainPlugin.URI.LocalPath)'."
    $cfg = $mainPlugin.Load()

    $configuration = [Variables]::GetInstance()
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

    $stepTree = [StepTree]::new($itemConfig)
    
    return $stepTree

#    $items.Process() | Out-Null

#    return $true
}
