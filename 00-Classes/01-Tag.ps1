<#
.SYNOPSIS
Tag value for tasks.
#>
class Tag : BaseEntity {
    Tag([string] $Name) : base($Name) { }

    [bool] Matches([string] $candidate) {
        return [string]::IsNullOrEmpty($candidate) -eq $false -and $this.Id -ieq $candidate
    }
}
