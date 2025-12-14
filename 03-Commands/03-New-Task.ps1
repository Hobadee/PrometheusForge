<#+
.SYNOPSIS
Factory helper to create Task instances (works around PowerShell constructor overload limitations)
#>
function New-Task {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)] [string] $Id,
        [Parameter(Mandatory=$true, Position=1)] [string] $Name,
        [string[]] $Tags = @(),
        [object[]] $Dependencies = @(),
        [string[]] $After = @(),
        [string] $SectionId = $null,
        [hashtable] $Config = @{}
    )

    # Use reflection to construct the Task object with the full parameter set
    $deps = @()
    foreach ($d in $Dependencies) {
        if ($d -is [System.Array]) {
            foreach ($x in $d) {
                if ($x -is [hashtable]) { $deps += [Dependency]::new($x) }
                elseif ($x -is [Dependency]) { $deps += $x }
            }
        }
        else {
            if ($d -is [hashtable]) { $deps += [Dependency]::new($d) }
            elseif ($d -is [Dependency]) { $deps += $d }
        }
    }

    # If any optional parameter was provided, use the full constructor path
    $usedOptional = ($Dependencies.Count -gt 0) -or ($Tags.Count -gt 0) -or ($After.Count -gt 0) -or ($SectionId -ne $null) -or ($Config.Count -gt 0)
    if ($usedOptional) {
        # Normalize types for full constructor
        $tagsArray = [string[]]$Tags
        $depsArray = @()
        foreach ($d in $deps) { if ($d -is [Dependency]) { $depsArray += $d } }
        $depsArray = [Dependency[]]$depsArray
        $afterArray = [string[]]$After
        $configHash = [hashtable]$Config
        $ctorArgs = @($Id,$Name,$tagsArray,$depsArray,$afterArray,$SectionId,$configHash)
        return [Activator]::CreateInstance([Task], $ctorArgs)
    }
    else {
        return [Activator]::CreateInstance([Task], @($Id,$Name))
    }
}
