<#
.SYNOPSIS
Base entity with Id and Name.
#>
class BaseEntity {
    [string] $Id
    [string] $Name

    BaseEntity([string] $Id, [string] $Name = $null) {
        if (-not $Id) { throw [System.ArgumentNullException]::new('Id') }
        $this.Id = $Id
        $this.Name = $Name
    }

    [object] ToPSObject() {
        return [pscustomobject]@{ Id = $this.Id; Name = $this.Name }
    }

    [bool] Equals([object] $other) {
        if ($null -eq $other) { return $false }
        if ($other -isnot [BaseEntity]) { return $false }
        return $this.Id -eq $other.Id
    }
}
