<#
.SYNOPSIS
Abstract base class for Task plugins.
#>
class TaskPlugin {
    [string] $Name
    [hashtable] $Settings

    TaskPlugin([hashtable] $settings = $null) {
        $this.Name = $this.GetType().Name
        $this.Settings = $settings
    }

    [void] Initialize([hashtable] $context) { }
    [object] Execute([Task] $task, [hashtable] $context) { throw [System.NotImplementedException]::new() }
    [object] OnError([System.Exception] $ex, [Task] $task, [hashtable] $context) { throw $ex }
    [void] Finalize([hashtable] $context) { }
}
