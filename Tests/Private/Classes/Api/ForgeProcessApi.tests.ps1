Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Helpers/ConsoleCapture.ps1')
    $script:capture = Start-ConsoleCapture

    # Other test files reset the plugin registry singleton; make sure the plugin these tests rely on exists.
    [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])

    function New-StepConfig {
        param([string] $Slug)
        return @{
            type       = 'step'
            name       = "Output $Slug"
            slug       = $Slug
            plugin     = 'TextOutput'
            parameters = @{ message = "message from $Slug"; level = 'Trace' }
        }
    }
}

AfterAll {
    [void] (Stop-ConsoleCapture $script:capture)
    [Variables]::Reset()
    [Steps]::Reset()
}

Describe 'ForgeProcessApi' {
    BeforeEach {
        [Log]::Reset()
        [Variables]::Reset()
        [Steps]::Reset()
        [Steps]::GetInstance().Add([Step]::new((New-StepConfig 'target')))
        $script:api = [ForgeProcessApi]::new()
    }

    It 'is exposed on ForgeApi as Process' {
        [ForgeApi]::new().Process | Should -BeOfType ([ForgeProcessApi])
    }

    It 'has no start-at slug by default' {
        $script:api.HasStartAtSlug() | Should -BeFalse
        $script:api.GetStartAtSlug() | Should -BeNullOrEmpty
    }

    It 'sets the start-at slug for an existing step' {
        $script:api.SetStartAtSlug('target')

        $script:api.HasStartAtSlug() | Should -BeTrue
        $script:api.GetStartAtSlug() | Should -Be 'target'
        [Variables]::GetInstance().Get([ForgeProcessApi]::StartAtSlugKey) | Should -Be 'target'
    }

    It 'rejects an empty slug: <Description>' -ForEach @(
        @{ Description = 'null'; Slug = $null }
        @{ Description = 'empty'; Slug = '' }
        @{ Description = 'whitespace'; Slug = '   ' }
    ) {
        $exceptionType = [System.ArgumentException]

        { $script:api.SetStartAtSlug($Slug) } | Should -Throw -ExceptionType $exceptionType
        $script:api.HasStartAtSlug() | Should -BeFalse
    }

    It 'rejects a slug that does not match a registered step' {
        $exceptionType = [System.InvalidOperationException]

        { $script:api.SetStartAtSlug('missing') } | Should -Throw -ExceptionType $exceptionType
        $script:api.HasStartAtSlug() | Should -BeFalse
    }

    It 'warns but still sets the slug when the step was already processed' {
        [Steps]::GetInstance().Get('target').Process() | Out-Null

        $script:api.SetStartAtSlug('target')

        $script:api.HasStartAtSlug() | Should -BeTrue
        $warnings = [Log]::GetInstance().Entries | Where-Object { $_.GetLevel() -eq [LogLevel]::Warning }
        $warnings.Count | Should -BeGreaterOrEqual 1
    }

    It 'clears the start-at slug' {
        $script:api.SetStartAtSlug('target')

        $script:api.ClearStartAtSlug()

        $script:api.HasStartAtSlug() | Should -BeFalse
    }

    It 'does not throw when clearing with nothing set' {
        { $script:api.ClearStartAtSlug() } | Should -Not -Throw
    }

    It 'replaces a previously set start-at slug' {
        [Steps]::GetInstance().Add([Step]::new((New-StepConfig 'other')))
        $script:api.SetStartAtSlug('target')

        $script:api.SetStartAtSlug('other')

        $script:api.GetStartAtSlug() | Should -Be 'other'
    }
}
