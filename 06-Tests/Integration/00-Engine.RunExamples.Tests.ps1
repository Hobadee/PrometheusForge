$modulePath = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\Lifecycle.Onboarding.psm1')
Import-Module $modulePath -Force
if (-not (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    Write-Warning "powershell-yaml not found; skipping integration tests that require YAML parsing"
    $skipIntegration = $true
}
# Ensure classes are available in the test runspace (dot-source the loader)
$classLoader = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\00-Classes\00-ClassesLoader.ps1')
. $classLoader

Describe 'ExecutionEngine integration' {
    It 'Executes sample run using default TextOutputPlugin' -Skip:$skipIntegration {
        $cfg = Import-Config -Path (Join-Path $PSScriptRoot '../Data/sample-master.yml')
        $engine = [ExecutionEngine]::new((New-Default-Plugins -PluginSettings $cfg.Plugins), @{ ErrorPolicy = 'Abort' })
        $run = [Run]::new('test-run', @{}, $cfg, $cfg.Tasks)
        $res = $engine.ExecuteRun($run)
        $res.Completed.Count | Should -Be $cfg.Tasks.Count
    }
}
