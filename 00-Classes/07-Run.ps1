<#
.SYNOPSIS
Run instance-level overrides and variables.
#>
class Run : BaseEntity {
    [hashtable] $Variables
    [Config] $Config
    [Task[]] $Tasks
    [datetime] $CreatedAt

    Run([string] $Id, [hashtable] $variables, [Config] $config, [Task[]] $tasks = @()) : base($Id) {
        $this.Variables = $variables
        $this.Config = $config
        $this.Tasks = $tasks
        $this.CreatedAt = [datetime]::UtcNow
    }

    [void] Validate() {
        if (-not $this.Config) { throw [System.ArgumentNullException]::new('Config') }
    }

    [object[]] ResolveDependencies([object] $resolver) {
        return $resolver.Resolve($this.Tasks)
    }

    [object] Execute([object] $engine) {
        return $engine.ExecuteRun($this)
    }
}
