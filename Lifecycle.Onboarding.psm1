# Lifecycle.Onboarding.psm1 - module bootstrap (Module-Builder deterministic loader)

<#
.SYNOPSIS
    Module bootstrap loader.
.DESCRIPTION
    Deterministically dot-sources all .ps1 files under the module by sorted name to enforce load order.
#>

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# 1) Load classes via explicit loader (ensures base classes compile before derived)
if (Test-Path (Join-Path $ScriptRoot '00-Classes\00-ClassesLoader.ps1')) {
    . (Join-Path $ScriptRoot '00-Classes\00-ClassesLoader.ps1')
}

# 2) Dot-source remaining .ps1 files, excluding the 00-Classes folder (to avoid double-sourcing classes)
Get-ChildItem -Path $ScriptRoot -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\\00-Classes\\' -and $_.FullName -notmatch '\\06-Tests\\' } | Sort-Object FullName | ForEach-Object {
    try {
        . $_.FullName
    }
    catch {
        Write-Error "Failed to load file $($_.FullName): $_"
        throw
    }
}

# Export public functions
Export-ModuleMember -Function Invoke-Onboarding, Import-Config, Get-Checklist, New-Task, Resolve-DependencyOrder
