<#
.SYNOPSIS
ExecutionEngine: executes tasks serially using configured plugins and honors error policy (default: non-interactive Abort).
#>
class ExecutionEngine {
    [hashtable] $Plugins
    [hashtable] $Settings

    ExecutionEngine([hashtable] $plugins = @{}, [hashtable] $settings = @{}) {
        $this.Plugins = $plugins
        $this.Settings = $settings
    }

    [object] ExecuteRun([Run] $run) {
        $run.Validate()
        $tasks = $run.Tasks
        $ordered = Resolve-DependencyOrder -Tasks $tasks
        $completed = @()
        $results = @()

        foreach ($t in $ordered) {
            try {
                $out = $null
                foreach ($p in $this.Plugins.Values) {
                    $out = $p.Execute($t, @{ Run = $run; Engine = $this })
                }
                $completed += $t.Id
                $results += [pscustomobject]@{ Task = $t.Id; Status = 'Success'; Message = if ($out -ne $null) { $out.Message } else { $null } }
            }
            catch {
                $policy = $run.Config.Defaults['errorPolicy']  # example: 'Abort'|'Skip'|'Retry'
                if (-not $policy) { $policy = 'Abort' }
                if ($policy -eq 'Abort') { throw "Execution aborted on task $($t.Id): $($_.Exception.Message)" }
                elseif ($policy -eq 'Skip') { $results += [pscustomobject]@{ Task = $t.Id; Status = 'Skipped'; Message = $_.Exception.Message }; continue }
                else { throw }
            }
        }

        return [pscustomobject]@{ RunId = $run.Id; Completed = $completed; Results = $results }
    }
}
