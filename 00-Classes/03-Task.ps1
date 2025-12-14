<#
.SYNOPSIS
Task definition: Id, Name, Tags, Dependencies, After, SectionId
#>
class Task : BaseEntity {
    [string[]] $Tags
    [Dependency[]] $Dependencies
    [string[]] $After
    [string] $SectionId
    [hashtable] $Config

    Task([string] $Id, [string] $Name) : base($Id,$Name) {
        $this.Tags = @()
        $this.Dependencies = @()
        $this.After = @()
        $this.SectionId = $null
        $this.Config = @{}
    }

    Task([string] $Id, [string] $Name, [string[]] $Tags, [Dependency[]] $Dependencies, [string[]] $After, [string] $SectionId, [hashtable] $Config) : base($Id,$Name) {
        $this.Tags = $Tags
        $this.Dependencies = $Dependencies
        $this.After = $After
        $this.SectionId = $SectionId
        $this.Config = $Config
    }

    [void] Validate() {
        if (-not $this.Id) { throw [System.ArgumentException]::new('Task must have an Id') }
    }

    [bool] IsReady([string[]] $completedTaskIds) {
        if ($null -eq $this.Dependencies -or $this.Dependencies.Length -eq 0) { return $true }
        foreach ($d in $this.Dependencies) {
            $found = $false
            foreach ($c in $completedTaskIds) { if ($c -ieq $d.Id) { $found = $true; break } }
            if (-not $found) { return $false }
        }
        return $true
    }

    [psobject] ToPSObject() {
        return [pscustomobject]@{ Id = $this.Id; Name = $this.Name; Tags = $this.Tags; SectionId = $this.SectionId }
    }

    [object] Execute([object] $engineContext) {
        # Delegate to engine/plugins. Return a simple object with Status, Message.
        return [pscustomobject]@{ Status = 'NotImplemented'; Message = 'Task.Execute is implemented by ExecutionEngine' }
    }
}
