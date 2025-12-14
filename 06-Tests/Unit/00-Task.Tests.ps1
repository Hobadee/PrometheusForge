$modulePath = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\Lifecycle.Onboarding.psm1')
Import-Module $modulePath -Force
# Ensure classes are available in the test runspace (dot-source the loader)
$classLoader = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\00-Classes\00-ClassesLoader.ps1')
. $classLoader

Describe 'Task' {
    It 'IsReady returns true when no dependencies' {
        $t = New-Task -Id 'id1' -Name 'NoDeps'
        $t.IsReady(@()) | Should Be $true
    }

    It 'IsReady returns false when dependency missing' {
        $dep = [Dependency]::new(@{ id = 'other' })
        $t = New-Task -Id 'id1' -Name 'HasDep' -Dependencies @($dep)
        $t.IsReady(@()) | Should Be $false
    }
}
