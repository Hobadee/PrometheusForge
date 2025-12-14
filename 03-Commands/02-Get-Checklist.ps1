<#+
.SYNOPSIS
Get-Checklist returns task summaries from a config or run file.
#>
function Get-Checklist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $ConfigPath
    )
    $cfg = Import-Config -Path $ConfigPath
    return $cfg.Tasks | Select-Object Id, Name, @{Name='Tags';Expression={[string]::Join(', ',$_.Tags)}}, SectionId
}
