<#
.SYNOPSIS
ConfigOverride selector-based overrides.
#>
class ConfigOverride {
    [hashtable] $Selector
    [hashtable] $Settings
    [int] $Priority

    ConfigOverride([hashtable] $selector, [hashtable] $settings, [int] $priority = 0) {
        $this.Selector = $selector
        $this.Settings = $settings
        $this.Priority = $priority
    }

    [bool] MatchesTask([Task] $task) {
        if ($null -eq $task) { return $false }
        if ($this.Selector.ContainsKey('ids')) {
            if ($this.Selector['ids'] -contains $task.Id) { return $true }
        }
        if ($this.Selector.ContainsKey('tags')) {
            foreach ($t in $this.Selector['tags']) { if ($task.Tags -contains $t) { return $true } }
        }
        if ($this.Selector.ContainsKey('section')) { if ($task.SectionId -and $task.SectionId -ieq $this.Selector['section']) { return $true } }
        return $false
    }
}
