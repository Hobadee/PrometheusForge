<#
.SYNOPSIS
Dependency selector: by Id, tag, or section. Supports negation (Not).
#>
class Dependency {
    [string] $Id
    [string] $Tag
    [string] $SectionId
    [bool] $Not = $false

    Dependency([hashtable] $spec) {
        if ($null -eq $spec) { throw [System.ArgumentNullException]::new('spec') }
        if ($spec.ContainsKey('id')) { $this.Id = [string]$spec['id'] }
        if ($spec.ContainsKey('tag')) { $this.Tag = [string]$spec['tag'] }
        if ($spec.ContainsKey('section')) { $this.SectionId = [string]$spec['section'] }
        if ($spec.ContainsKey('not')) { $this.Not = [bool]$spec['not'] }
    }

    [bool] MatchesTask([object] $task) {
        if ($null -eq $task) { return $false }
        if ($this.Id -and $task.Id -and ($this.Id -ieq $task.Id)) { return ($this.Not -eq $false) }
        if ($this.Tag -and $task.Tags -and ($task.Tags -contains $this.Tag)) { return ($this.Not -eq $false) }
        if ($this.SectionId -and $task.SectionId -and ($this.SectionId -ieq $task.SectionId)) { return ($this.Not -eq $false) }
        return $this.Not -eq $true
    }

    [object[]] ResolveCandidates([object[]] $allTasks) {
        # Expand to concrete tasks based on Id/Tag/Section. Returns array of matching tasks.
        $matches = @()
        foreach ($t in $allTasks) {
            if ($this.MatchesTask($t)) { $matches += $t }
        }
        return $matches
    }
}
