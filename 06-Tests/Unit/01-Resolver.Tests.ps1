$modulePath = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\Lifecycle.Onboarding.psm1')
Import-Module $modulePath -Force
# Ensure classes are available in the test runspace (dot-source the loader)
$classLoader = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\00-Classes\00-ClassesLoader.ps1')
. $classLoader

Describe 'DependencyResolver' {
    It 'Topologically sorts tasks by explicit dependencies' {
        $a = New-Task -Id 'a' -Name 'A'
        $b = New-Task -Id 'b' -Name 'B' -Dependencies @([Dependency]::new(@{ id='a' }))
        $list = Resolve-DependencyOrder -Tasks @($a,$b)
        ($list | ForEach-Object { $_.Id } | Where-Object { $_ -ne $null -and $_ -ne '' }) -join ',' | Should Be 'a,b'
    }

    It 'Detects simple cycle' {
        $a = New-Task -Id 'a' -Name 'A' -Dependencies @([Dependency]::new(@{ id='b' }))
        $b = New-Task -Id 'b' -Name 'B' -Dependencies @([Dependency]::new(@{ id='a' }))
        { Resolve-DependencyOrder -Tasks @($a,$b) } | Should Throw
    }
}
