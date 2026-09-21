Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'CurrentTime Plugin' {
    Context 'Constructor and PluginInfo' {
        It 'Should inherit from TaskPluginInterface' {
            $expectedType = [TaskPluginInterface]

            [CurrentTime]::new() | Should -BeOfType $expectedType
        }

        It 'Should report its name and version' {
            $info = [CurrentTime]::PluginInfo()

            $info['name'] | Should -Be 'CurrentTime'
            $info['version'] | Should -Be '1.0.0'
        }

        It 'Should be registered in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([CurrentTime])

            $registry.PluginRegistry.ContainsKey('CurrentTime') | Should -BeTrue
        }
    }

    Context 'ValidateParameters' {
        It 'Should accept any parameters: <Description>' -ForEach @(
            @{ Description = 'null'; Params = $null }
            @{ Description = 'empty'; Params = @{} }
            @{ Description = 'ignored values'; Params = @{ anything = 'goes' } }
        ) {
            $plugin = [CurrentTime]::new()

            { $plugin.ValidateParameters($Params) } | Should -Not -Throw
        }
    }

    Context 'Execute' {
        It 'Should return the current date and time' {
            $plugin = [CurrentTime]::new()
            $before = [datetime]::Now

            $result = $plugin.Execute()

            $after = [datetime]::Now
            $result | Should -BeOfType ([datetime])
            $result | Should -BeGreaterOrEqual $before
            $result | Should -BeLessOrEqual $after
        }

        It 'Should succeed through RunTask() without any parameters' {
            $plugin = [CurrentTime]::new()
            $plugin.SetParameters($null)

            $result = $plugin.RunTask()

            $result.success | Should -BeTrue
            $result.object | Should -BeOfType ([datetime])
        }
    }
}
