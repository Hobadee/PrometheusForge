<#+
.SYNOPSIS
Invoke-Onboarding runs an onboarding/offboarding run using a base config, optional client override, and run file.
.PARAMETER ConfigPath
Path to the master YAML config (required).
.PARAMETER ClientOverridePath
Optional client-level override YAML.
.PARAMETER RunPath
Optional run YAML (instance-level overrides).
#>
function Invoke-Onboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $ConfigPath,
        [Parameter(Mandatory=$false)] [string] $ClientOverridePath,
        [Parameter(Mandatory=$false)] [string] $RunPath,
        [switch] $NoOp
    )

    $baseCfg = Import-Config -Path $ConfigPath
    if ($ClientOverridePath) { $clientSpec = ConvertFrom-FileYaml -Path $ClientOverridePath; $baseCfg = $baseCfg.ApplyOverrides($clientSpec.overrides) }

    $runSpec = $null
    if ($RunPath) { $runSpec = ConvertFrom-FileYaml -Path $RunPath }

    # Build tasks for run by applying include/exclude (simple logic)
    $tasks = $baseCfg.Tasks
    if ($runSpec) {
        if ($runSpec.include) { $tasks = $tasks | Where-Object { $runSpec.include -contains $_.Id } }
        if ($runSpec.excludeTags) { $tasks = $tasks | Where-Object { ($_.Tags | Where-Object { $runSpec.excludeTags -contains $_ }) -eq $null } }
    }

    # Build effective config
    $effectiveConfig = $baseCfg

    $run = [Run]::new(($runSpec.id -or ('run.' + [datetime]::UtcNow.ToString('yyyyMMddHHmmss'))), @{}, $effectiveConfig, $tasks)

    $plugins = New-Default-Plugins -PluginSettings $effectiveConfig.Plugins
    $engine = [ExecutionEngine]::new($plugins, @{ ErrorPolicy = 'Abort' })

    if ($NoOp) { Write-Host "NoOp: would run $($run.Id) with $($tasks.Count) tasks"; return }

    return $engine.ExecuteRun($run)
}
