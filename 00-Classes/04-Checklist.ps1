<#
.SYNOPSIS
Checklist groups tasks.
#>
class Checklist : BaseEntity {
    [Task[]] $Items

    Checklist([string] $Id, [Task[]] $Items = @()) : base($Id) {
        $this.Items = $Items
    }

    [void] AddItem([Task] $task) { $this.Items += $task }
    [Task[]] GetPending([string[]] $completedIds) { return $this.Items | Where-Object { $completedIds -notcontains $_.Id }
    }
}
