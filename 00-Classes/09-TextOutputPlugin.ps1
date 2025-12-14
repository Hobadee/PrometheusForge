<#
.SYNOPSIS
TextOutputPlugin - MVP plugin that prints task info to console.
#>
class TextOutputPlugin : TaskPlugin {
    [string] $OutputFormat = 'Console'
    [string] $Destination = 'stdout'

    TextOutputPlugin([hashtable] $settings = $null) : base($settings) {
        if ($null -ne $settings) {
            if ($settings.ContainsKey('outputFormat')) { $this.OutputFormat = $settings['outputFormat'] }
            if ($settings.ContainsKey('destination')) { $this.Destination = $settings['destination'] }
        }
    }

    [void] Initialize([hashtable] $context) {
        # noop for now
    }

    [object] Execute([Task] $task, [hashtable] $context) {
        $msg = "[TextOutput] Task: $($task.Name) (Id=$($task.Id))"
        if ($this.OutputFormat -ieq 'Json') { $msg = $task.ToPSObject() | ConvertTo-Json -Depth 3 }
        if ($this.Destination -ieq 'stdout') { Write-Host $msg }
        else { Out-File -FilePath $this.Destination -InputObject $msg -Append }
        return [pscustomobject]@{ Status = 'Success'; Message = $msg }
    }

    [void] Finalize([hashtable] $context) { }
}
