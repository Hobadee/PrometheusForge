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

    function Read-LifecycleYamlFile {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Path,

            [Parameter(Mandatory = $true)]
            [string] $ParameterName
        )

        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw [System.ArgumentException]::new("$ParameterName cannot be null or empty.", $ParameterName)
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]::new("File '$Path' was not found.", $resolvedPath)
        }

        try {
            $yaml = Get-Content -LiteralPath $resolvedPath -Raw
        }
        catch {
            throw [System.UnauthorizedAccessException]::new("File '$Path' is not readable.", $_.Exception)
        }

        Write-Debug "Parsed YAML content from '$resolvedPath'."
        $cfg = ConvertFrom-Yaml $yaml

        if ($null -eq $cfg) {
            throw [System.InvalidOperationException]::new("The YAML file '$Path' did not produce a configuration object.")
        }

        return @{
            ResolvedPath = $resolvedPath
            Config = $cfg
        }
    }

    function Set-VariablesFromDocument {
        param(
            [Parameter(Mandatory = $true)]
            [object] $Document,

            [Parameter(Mandatory = $true)]
            [Configuration] $Configuration
        )

        if ($null -eq $Document.variables) {
            return
        }

        if ($Document.variables -is [System.Collections.IDictionary]) {
            foreach ($key in $Document.variables.Keys) {
                $Configuration.Set($key, $Document.variables[$key])
            }
            return
        }

        if ($Document.variables -is [pscustomobject]) {
            foreach ($property in $Document.variables.PSObject.Properties) {
                $Configuration.Set($property.Name, $property.Value)
            }
            return
        }

        throw [System.ArgumentException]::new("The 'variables' property must be an object/map in YAML.", 'variables')
    }

    $mainDocument = Read-LifecycleYamlFile -Path $FilePath -ParameterName 'FilePath'
    $resolvedPath = $mainDocument.ResolvedPath
    $cfg = $mainDocument.Config

    Write-Verbose "Loading configuration from '$resolvedPath'."

    $configuration = [Configuration]::GetInstance()
    Set-VariablesFromDocument -Document $cfg -Configuration $configuration

    if ($null -ne $Overlay) {
        foreach ($overlayPath in $Overlay) {
            $overlayDocument = Read-LifecycleYamlFile -Path $overlayPath -ParameterName 'Overlay'
            Write-Verbose "Applying overlay '$($overlayDocument.ResolvedPath)'."
            Set-VariablesFromDocument -Document $overlayDocument.Config -Configuration $configuration
        }
    }

    if ($null -ne $cfg.root) {
        $itemConfig = $cfg.root
    }
    else {
        throw [System.ArgumentException]::new("The YAML configuration at '$FilePath' must contain a top-level 'root' property.", 'FilePath')
    }

    $items = [ItemFactory]::Create($itemConfig)

    $items.DoItem() | Out-Null

    return $true
}
