<#+
.SYNOPSIS
Import YAML config and convert to Config and Task objects.
#>
function Import-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $Path
    )
    $spec = ConvertFrom-FileYaml -Path $Path

    # Build Task objects
    $tasks = @()
    if ($spec.tasks) {
        foreach ($t in $spec.tasks) {
            $deps = @()
            if ($t.dependencies) {
                foreach ($d in $t.dependencies) { $deps += [Dependency]::new($d) }
            }
            $task = [Task]::new($t.id, $t.name, @($t.tags), $deps, @($t.after), $t.section, $t.config)
            $tasks += $task
        }
    }

    $cfg = [Config]::new($spec)
    $cfg.Tasks = $tasks
    return $cfg
}
