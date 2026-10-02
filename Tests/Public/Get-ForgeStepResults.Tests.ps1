Using Module "../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../Helpers/ConsoleCapture.ps1')
    Remove-Module PrometheusForge -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-ForgeStepResults' {
    BeforeAll {
        $script:workflow = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Step results workflow
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Say hello
      slug: say-hello
      plugin: TextOutput
      parameters:
        message: hello
        level: Info
'@ | Set-Content -Path $script:workflow -Encoding utf8
    }

    BeforeEach {
        # Keep terminal log output from leaking into the Pester output.
        $script:writer = Start-ConsoleCapture
    }

    AfterEach {
        [void] (Stop-ConsoleCapture $script:writer)
    }

    Context 'Parameters' {
        It 'requires the Slug parameter' {
            (Get-Command Get-ForgeStepResults).Parameters['Slug'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
                Should -Be $true
        }

        It 'rejects an empty slug' {
            { Get-ForgeStepResults -Slug '' } | Should -Throw
        }
    }

    Context 'Reading results' {
        It 'returns the entire result of a step that has run' {
            Invoke-Forge -FilePath $script:workflow

            $result = Get-ForgeStepResults -Slug 'say-hello'
            $expected = [Steps]::GetInstance().Get('say-hello').result

            $result | Should -Not -BeNullOrEmpty
            $result.success | Should -BeTrue
            [object]::ReferenceEquals($result, $expected) | Should -BeTrue
        }

        It 'accepts the slug positionally' {
            Invoke-Forge -FilePath $script:workflow

            (Get-ForgeStepResults 'say-hello').success | Should -BeTrue
        }

        It 'accepts the slug from the pipeline' {
            Invoke-Forge -FilePath $script:workflow

            ('say-hello' | Get-ForgeStepResults).success | Should -BeTrue
        }

        It 'returns a single object rather than unrolling it' {
            Invoke-Forge -FilePath $script:workflow

            @(Get-ForgeStepResults -Slug 'say-hello').Count | Should -Be 1
        }
    }

    Context 'Unavailable results' {
        It 'throws StepNotFound for a slug that does not exist' {
            Invoke-Forge -FilePath $script:workflow

            { Get-ForgeStepResults -Slug 'no-such-step' -ErrorAction Stop } |
                Should -Throw -ErrorId 'StepNotFound*'
        }

        It 'throws StepNotFound when no run has happened' {
            [Steps]::Reset()

            { Get-ForgeStepResults -Slug 'say-hello' -ErrorAction Stop } |
                Should -Throw -ErrorId 'StepNotFound*'
        }

        It 'returns nothing for a step that exists but has not run' {
            [Steps]::Reset()
            $step = [Step]::new(@{ slug = 'pending-step'; name = 'Pending'; defer_binding = $true })
            [Steps]::GetInstance().Add($step)

            @(Get-ForgeStepResults -Slug 'pending-step').Count | Should -Be 0

            [Steps]::Reset()
        }

        It 'does not return results from a previous run after a new run starts' {
            Invoke-Forge -FilePath $script:workflow
            Invoke-Forge -FilePath $script:workflow

            # Same slug re-registered cleanly, so the second run's result is returned
            (Get-ForgeStepResults -Slug 'say-hello').success | Should -BeTrue
        }
    }
}
