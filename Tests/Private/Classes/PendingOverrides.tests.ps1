Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
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

Describe 'PendingOverrides' {
    BeforeEach {
        [Log]::Reset()
        [PendingOverrides]::Reset()
    }

    AfterAll {
        [PendingOverrides]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same instance on repeated calls' {
            $first = [PendingOverrides]::GetInstance()
            $second = [PendingOverrides]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeTrue
        }

        It 'returns a fresh, empty instance after Reset()' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))

            [PendingOverrides]::Reset()

            [PendingOverrides]::GetInstance().Count() | Should -Be 0
        }
    }

    Context 'Request' {
        It 'starts with no pending overrides' {
            [PendingOverrides]::GetInstance().Count() | Should -Be 0
        }

        It 'queues an override by slug' {
            $override = New-TestStep 'step-a'

            [PendingOverrides]::GetInstance().Request('step-a', $override)

            [PendingOverrides]::GetInstance().HasOverride('step-a') | Should -BeTrue
            [PendingOverrides]::GetInstance().Count() | Should -Be 1
        }

        It 'rejects an empty slug: <Description>' -ForEach @(
            @{ Description = 'null'; Slug = $null }
            @{ Description = 'empty'; Slug = '' }
            @{ Description = 'whitespace'; Slug = '   ' }
        ) {
            $exceptionType = [System.ArgumentException]

            { [PendingOverrides]::GetInstance().Request($Slug, (New-TestStep 'step-a')) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'rejects a null override' {
            $exceptionType = [System.ArgumentNullException]

            { [PendingOverrides]::GetInstance().Request('step-a', $null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'overwrites an existing pending override for the same slug and logs a warning' {
            $first = New-TestStep 'step-a'
            $second = New-TestStep 'step-a'

            [PendingOverrides]::GetInstance().Request('step-a', $first)
            [PendingOverrides]::GetInstance().Request('step-a', $second)

            [PendingOverrides]::GetInstance().Count() | Should -Be 1
            [object]::ReferenceEquals([PendingOverrides]::GetInstance().Drain('step-a'), $second) | Should -BeTrue

            $warnings = [Logs]::GetInstance().Entries | Where-Object { $_.GetLevel() -eq [LogLevel]::Warning }
            $warnings.Count | Should -BeGreaterOrEqual 1
        }

        It 'does not warn when requesting overrides for different slugs' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverrides]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            $warnings = [Logs]::GetInstance().Entries | Where-Object { $_.GetLevel() -eq [LogLevel]::Warning }
            $warnings.Count | Should -Be 0
        }
    }

    Context 'HasOverride' {
        It 'returns false when no override is queued for the slug' {
            [PendingOverrides]::GetInstance().HasOverride('missing') | Should -BeFalse
        }

        It 'returns true once an override is queued for the slug' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))

            [PendingOverrides]::GetInstance().HasOverride('step-a') | Should -BeTrue
        }
    }

    Context 'Drain' {
        It 'returns null when no override is queued for the slug' {
            [PendingOverrides]::GetInstance().Drain('missing') | Should -BeNullOrEmpty
        }

        It 'removes and returns the queued override' {
            $override = New-TestStep 'step-a'
            [PendingOverrides]::GetInstance().Request('step-a', $override)

            $drained = [PendingOverrides]::GetInstance().Drain('step-a')

            [object]::ReferenceEquals($drained, $override) | Should -BeTrue
            [PendingOverrides]::GetInstance().HasOverride('step-a') | Should -BeFalse
            [PendingOverrides]::GetInstance().Count() | Should -Be 0
        }
    }

    Context 'Count' {
        It 'reflects the number of distinct queued slugs' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverrides]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            [PendingOverrides]::GetInstance().Count() | Should -Be 2
        }
    }

    Context 'GetPendingSlugs' {
        It 'returns an empty array when nothing is queued' {
            [PendingOverrides]::GetInstance().GetPendingSlugs() | Should -HaveCount 0
        }

        It 'returns every slug still queued' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverrides]::GetInstance().Request('step-b', (New-TestStep 'step-b'))

            [PendingOverrides]::GetInstance().GetPendingSlugs() | Should -Contain 'step-a'
            [PendingOverrides]::GetInstance().GetPendingSlugs() | Should -Contain 'step-b'
        }

        It 'omits a slug once it has been drained' {
            [PendingOverrides]::GetInstance().Request('step-a', (New-TestStep 'step-a'))
            [PendingOverrides]::GetInstance().Drain('step-a') | Out-Null

            [PendingOverrides]::GetInstance().GetPendingSlugs() | Should -Not -Contain 'step-a'
        }
    }

}
