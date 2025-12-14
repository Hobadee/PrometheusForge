<#
.SYNOPSIS
Apply overrides from ConfigOverride objects to a Config or a set of Tasks.
#>
function Apply-ConfigOverrides {
    param(
        [hashtable] $BaseConfig,
        [object[]] $Overrides
    )
    # Very small merge strategy for MVP: iterate overrides and merge settings into base config.
    $effective = $BaseConfig.Clone()
    foreach ($ov in $Overrides) {
        if ($ov -is [hashtable]) {
            foreach ($k in $ov.Keys) { $effective[$k] = $ov[$k] }
        }
    }
    return $effective
}
