Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'ForgeApi' {
    BeforeEach {
        [Variables]::Reset()
        [Steps]::Reset()
    }

    AfterAll {
        [Variables]::Reset()
        [Steps]::Reset()
    }

    It 'exposes each API category' {
        $api = [ForgeApi]::new()

        $api.Variables | Should -BeOfType ([ForgeVariableApi])
        $api.Configuration | Should -BeOfType ([ForgeConfigurationApi])
        $api.Template | Should -BeOfType ([ForgeTemplateApi])
    }

    It 'gives each instance its own configuration queues' {
        $first = [ForgeApi]::new()
        $second = [ForgeApi]::new()

        $first.Configuration.Insert(@{ slug = 'queued' })

        $first.Configuration.GetPendingInserts().Count | Should -Be 1
        $second.Configuration.GetPendingInserts().Count | Should -Be 0
    }
}

Describe 'ForgeVariableApi' {
    BeforeEach {
        [Variables]::Reset()
        $script:api = [ForgeVariableApi]::new()
    }

    AfterAll {
        [Variables]::Reset()
    }

    It 'reads values from the Variables singleton' {
        [Variables]::GetInstance().Set('fromEngine', 'engine value')

        $script:api.Get('fromEngine') | Should -Be 'engine value'
    }

    It 'writes values to the Variables singleton' {
        $script:api.Set('fromPlugin', 'plugin value')

        [Variables]::GetInstance().Get('fromPlugin') | Should -Be 'plugin value'
    }

    It 'reports whether a key exists' {
        $script:api.HasKey('present') | Should -BeFalse

        $script:api.Set('present', 1)

        $script:api.HasKey('present') | Should -BeTrue
    }

    It 'sets many values at once' {
        $script:api.SetMany(@{ one = 1; two = 2 })

        [Variables]::GetInstance().Get('one') | Should -Be 1
        [Variables]::GetInstance().Get('two') | Should -Be 2
    }
}

Describe 'ForgeTemplateApi' {
    BeforeEach {
        [Variables]::Reset()
        $script:api = [ForgeTemplateApi]::new()
    }

    AfterAll {
        [Variables]::Reset()
    }

    It 'expands templates against the Variables singleton' {
        [Variables]::GetInstance().Set('name', 'Ada')

        $script:api.ExpandString('Hello {{ name }}') | Should -Be 'Hello Ada'
    }

    It 'expands top-level values in a hashtable' {
        [Variables]::GetInstance().Set('name', 'Ada')

        $expanded = $script:api.ExpandTopLevelValues(@{ greeting = 'Hello {{ name }}'; count = 2 })

        $expanded.greeting | Should -Be 'Hello Ada'
        $expanded.count | Should -Be 2
    }
}

Describe 'ForgeConfigurationApi' {
    BeforeEach {
        $script:api = [ForgeConfigurationApi]::new()
    }

    Context 'Overrides' {
        It 'starts with no pending overrides' {
            $script:api.GetPendingOverrides().Count | Should -Be 0
        }

        It 'queues requested overrides in order' {
            $script:api.RequestOverride('first', @{ slug = 'first' })
            $script:api.RequestOverride('second', @{ slug = 'second' })

            $pending = $script:api.GetPendingOverrides()
            $pending.Count | Should -Be 2
            $pending[0].key | Should -Be 'first'
            $pending[0].value.slug | Should -Be 'first'
            $pending[1].key | Should -Be 'second'
        }

        It 'rejects an empty override key: <Description>' -ForEach @(
            @{ Description = 'null'; Key = $null }
            @{ Description = 'empty'; Key = '' }
            @{ Description = 'whitespace'; Key = '   ' }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:api.RequestOverride($Key, @{}) } | Should -Throw -ExceptionType $exceptionType
            $script:api.GetPendingOverrides().Count | Should -Be 0
        }

        It 'clears pending overrides' {
            $script:api.RequestOverride('first', @{ slug = 'first' })

            $script:api.ClearPendingOverrides()

            $script:api.GetPendingOverrides().Count | Should -Be 0
        }
    }

    Context 'Inserts' {
        It 'starts with no pending inserts' {
            $script:api.GetPendingInserts().Count | Should -Be 0
        }

        It 'queues inserted configs in call order' {
            $script:api.Insert(@{ slug = 'first' })
            $script:api.Insert(@{ slug = 'second' })

            $pending = $script:api.GetPendingInserts()
            $pending.Count | Should -Be 2
            $pending[0].slug | Should -Be 'first'
            $pending[1].slug | Should -Be 'second'
        }

        It 'rejects a null config' {
            $exceptionType = [System.ArgumentNullException]

            { $script:api.Insert($null) } | Should -Throw -ExceptionType $exceptionType
            $script:api.GetPendingInserts().Count | Should -Be 0
        }

        It 'clears pending inserts' {
            $script:api.Insert(@{ slug = 'first' })

            $script:api.ClearPendingInserts()

            $script:api.GetPendingInserts().Count | Should -Be 0
        }

        It 'keeps overrides and inserts in separate queues' {
            $script:api.Insert(@{ slug = 'inserted' })

            $script:api.GetPendingOverrides().Count | Should -Be 0
        }
    }
}
