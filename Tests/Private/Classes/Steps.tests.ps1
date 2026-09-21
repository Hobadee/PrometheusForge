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

Describe 'Steps' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    AfterAll {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same instance on repeated calls' {
            $first = [Steps]::GetInstance()
            $second = [Steps]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeTrue
        }

        It 'returns a fresh, empty instance after Reset()' {
            $first = [Steps]::GetInstance()
            $first.Add((New-TestStep 'step-a'))

            [Steps]::Reset()
            $second = [Steps]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            $second.Exists('step-a') | Should -BeFalse
        }
    }

    Context 'Add' {
        It 'stores a step by slug' {
            $step = New-TestStep 'step-a'
            [Steps]::GetInstance().Add($step)

            [Steps]::GetInstance().Exists('step-a') | Should -BeTrue
            [Steps]::GetInstance().Get('step-a') | Should -Be $step
        }

        It 'throws when a step with the same slug already exists' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))

            $exceptionType = [System.ArgumentException]
            { $steps.Add((New-TestStep 'step-a')) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Remove' {
        It 'removes an existing step' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))

            $steps.Remove('step-a')

            $steps.Exists('step-a') | Should -BeFalse
        }

        It 'throws when the step does not exist' {
            $exceptionType = [System.ArgumentException]
            { [Steps]::GetInstance().Remove('missing') } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Update' {
        It 'replaces an existing step that has not run' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))
            $replacement = New-TestStep 'step-a'

            $steps.Update($replacement)

            $steps.Get('step-a') | Should -Be $replacement
        }

        It 'throws when the step does not exist' {
            $exceptionType = [System.ArgumentException]
            { [Steps]::GetInstance().Update((New-TestStep 'missing')) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when the existing step has already run' {
            $steps = [Steps]::GetInstance()
            $original = New-TestStep 'step-a'
            $steps.Add($original)
            $original.result = @{ success = $true }

            $exceptionType = [System.InvalidOperationException]
            { $steps.Update((New-TestStep 'step-a')) } | Should -Throw -ExceptionType $exceptionType
            $steps.Get('step-a') | Should -Be $original
        }
    }

    Context 'AddOrUpdate' {
        It 'adds the step when it does not exist' {
            $steps = [Steps]::GetInstance()
            $step = New-TestStep 'step-a'

            $steps.AddOrUpdate($step)

            $steps.Get('step-a') | Should -Be $step
        }

        It 'updates the step when it already exists' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))
            $replacement = New-TestStep 'step-a'

            $steps.AddOrUpdate($replacement)

            $steps.Get('step-a') | Should -Be $replacement
        }
    }

    Context 'Get / Exists' {
        It 'returns $null for an unknown slug' {
            [Steps]::GetInstance().Get('missing') | Should -BeNullOrEmpty
        }

        It 'reports whether a slug exists' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))

            $steps.Exists('step-a') | Should -BeTrue
            $steps.Exists('step-b') | Should -BeFalse
        }
    }

    Context 'IsProcessed / GetResult' {
        It 'reports an unrun step as not processed and has no result' {
            $steps = [Steps]::GetInstance()
            $steps.Add((New-TestStep 'step-a'))

            $steps.IsProcessed('step-a') | Should -BeFalse
            $steps.GetResult('step-a') | Should -BeNullOrEmpty
        }

        It 'reports an unknown step as not processed and has no result' {
            $steps = [Steps]::GetInstance()

            $steps.IsProcessed('missing') | Should -BeFalse
            $steps.GetResult('missing') | Should -BeNullOrEmpty
        }

        It 'returns the stored result once the step has run' {
            $steps = [Steps]::GetInstance()
            $step = New-TestStep 'step-a'
            $steps.Add($step)
            $step.Process() | Should -BeTrue

            $steps.IsProcessed('step-a') | Should -BeTrue
            $steps.GetResult('step-a').success | Should -BeTrue
        }
    }
}
