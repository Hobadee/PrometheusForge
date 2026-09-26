Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../../Helpers/ConsoleCapture.ps1')

    # Overlay handling logs warnings through [System.Console]::Out, which Pester does not capture; discard it
    # so expected warnings from these tests don't clutter the test output.
    $script:capture = Start-ConsoleCapture

    # Other test files reset the plugin registry singleton; make sure the plugin these tests rely on exists.
    [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])

    function New-TestStep {
        param([string] $Slug = 'step-a')
        return [Step]::new(@{
                type       = 'step'
                name       = "Step $Slug"
                slug       = $Slug
                plugin     = 'TextOutput'
                parameters = @{ message = 'hello'; method = 'Trace' }
            })
    }
}

AfterAll {
    [void] (Stop-ConsoleCapture $script:capture)
}

Describe 'PendingOverlays' {
    BeforeEach {
        [Log]::Reset()
        [PendingOverlays]::Reset()
    }

    AfterAll {
        [PendingOverlays]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same instance on repeated calls' {
            $first = [PendingOverlays]::GetInstance()
            $second = [PendingOverlays]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeTrue
        }

        It 'returns a fresh, empty instance after Reset()' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))

            [PendingOverlays]::Reset()

            [PendingOverlays]::GetInstance().Count() | Should -Be 0
        }
    }

    Context 'Request' {
        It 'starts with no pending overlays' {
            [PendingOverlays]::GetInstance().Count() | Should -Be 0
        }

        It 'queues an overlay by slug' {
            $overlay = New-TestStep 'step-a'

            [PendingOverlays]::GetInstance().Request('step-a', $overlay)

            [PendingOverlays]::GetInstance().HasOverlay('step-a') | Should -BeTrue
            [PendingOverlays]::GetInstance().Count() | Should -Be 1
        }

        It 'rejects an empty slug: <Description>' -ForEach @(
            @{ Description = 'null'; Slug = $null }
            @{ Description = 'empty'; Slug = '' }
            @{ Description = 'whitespace'; Slug = '   ' }
        ) {
            $exceptionType = [System.ArgumentException]

            { [PendingOverlays]::GetInstance().Request($Slug, (New-TestStep 'step-a')) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'rejects a null overlay' {
            $exceptionType = [System.ArgumentNullException]

            { [PendingOverlays]::GetInstance().Request('step-a', $null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'overwrites an existing pending overlay for the same slug and logs a warning' {
            $first = New-TestStep 'step-a'
            $second = New-TestStep 'step-a'

            [PendingOverlays]::GetInstance().Request('step-a', $first)
            [PendingOverlays]::GetInstance().Request('step-a', $second)

            [PendingOverlays]::GetInstance().Count() | Should -Be 1
            [object]::ReferenceEquals([PendingOverlays]::GetInstance().Drain('step-a'), $second) | Should -BeTrue

            $warnings = [Log]::GetInstance().Entries | Where-Object { $_.GetLevel() -eq [LogLevel]::Warning }
            $warnings.Count | Should -BeGreaterOrEqual 1
        }

        It 'does not warn when requesting overlays for different slugs' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverlays]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            $warnings = [Log]::GetInstance().Entries | Where-Object { $_.GetLevel() -eq [LogLevel]::Warning }
            $warnings.Count | Should -Be 0
        }
    }

    Context 'HasOverlay' {
        It 'returns false when no overlay is queued for the slug' {
            [PendingOverlays]::GetInstance().HasOverlay('missing') | Should -BeFalse
        }

        It 'returns true once an overlay is queued for the slug' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))

            [PendingOverlays]::GetInstance().HasOverlay('step-a') | Should -BeTrue
        }
    }

    Context 'Drain' {
        It 'returns null when no overlay is queued for the slug' {
            [PendingOverlays]::GetInstance().Drain('missing') | Should -BeNullOrEmpty
        }

        It 'removes and returns the queued overlay' {
            $overlay = New-TestStep 'step-a'
            [PendingOverlays]::GetInstance().Request('step-a', $overlay)

            $drained = [PendingOverlays]::GetInstance().Drain('step-a')

            [object]::ReferenceEquals($drained, $overlay) | Should -BeTrue
            [PendingOverlays]::GetInstance().HasOverlay('step-a') | Should -BeFalse
            [PendingOverlays]::GetInstance().Count() | Should -Be 0
        }
    }

    Context 'Count' {
        It 'reflects the number of distinct queued slugs' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverlays]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            [PendingOverlays]::GetInstance().Count() | Should -Be 2
        }
    }

    Context 'GetPendingSlugs' {
        It 'returns an empty array when nothing is queued' {
            [PendingOverlays]::GetInstance().GetPendingSlugs() | Should -HaveCount 0
        }

        It 'returns every slug still queued' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverlays]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            [PendingOverlays]::GetInstance().GetPendingSlugs() | Should -Contain 'step-a'
            [PendingOverlays]::GetInstance().GetPendingSlugs() | Should -Contain 'step-b'
        }

        It 'omits a slug once it has been drained' {
            [PendingOverlays]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverlays]::GetInstance().Drain('step-a') | Out-Null

            [PendingOverlays]::GetInstance().GetPendingSlugs() | Should -Not -Contain 'step-a'
        }
    }

}
