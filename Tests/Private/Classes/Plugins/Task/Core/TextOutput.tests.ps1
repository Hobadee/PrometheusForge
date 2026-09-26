Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"
BeforeAll {
    . (Join-Path $PSScriptRoot '../../../../../Helpers/ConsoleCapture.ps1')
}

Describe 'TextOutput Plugin' {
    BeforeEach {
        [Log]::Reset()
        [Variables]::Reset()

        # Silence terminal output so logged messages don't leak into the Pester output.
        $script:writer = Start-ConsoleCapture
    }

    AfterEach {
        [void] (Stop-ConsoleCapture $script:writer)
    }

    AfterAll {
        [Log]::Reset()
        [Variables]::Reset()
    }

    Context 'Constructor and PluginInfo' {
        It 'Should inherit from TaskPluginInterface' {
            $expectedType = [TaskPluginInterface]

            [TextOutput]::new() | Should -BeOfType $expectedType
        }

        It 'Should report its name and version' {
            $info = [TextOutput]::PluginInfo()

            $info['name'] | Should -Be 'TextOutput'
            $info['version'] | Should -Be '1.1.0'
        }

        It 'Should be registered in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([TextOutput])

            $registry.PluginRegistry.ContainsKey('TextOutput') | Should -BeTrue
        }
    }

    Context 'ValidateParameters' {
        It 'Should throw when parameters are null' {
            $plugin = [TextOutput]::new()
            $exceptionType = [System.ArgumentException]

            { $plugin.ValidateParameters($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should accept parameters without a message' {
            $plugin = [TextOutput]::new()

            { $plugin.ValidateParameters(@{}) } | Should -Not -Throw
        }

        It 'Should treat null parameters passed to SetParameters() as empty' {
            $plugin = [TextOutput]::new()

            { $plugin.SetParameters($null) } | Should -Not -Throw
        }
    }

    Context 'Execute' {
        It 'Should log the message at the requested level' {
            $plugin = [TextOutput]::new()
            $plugin.SetParameters(@{ message = 'a warning'; level = 'Warning' })

            $plugin.Execute() | Out-Null

            $entry = @([Log]::GetInstance())[0]
            $entry.GetMessage() | Should -Be 'a warning'
            $entry.GetLevel() | Should -Be ([LogLevel]::Warning)
        }

        It 'Should default the log level to Info when no level is given' {
            $plugin = [TextOutput]::new()
            $plugin.SetParameters(@{ message = 'an info message' })

            $plugin.Execute() | Out-Null

            @([Log]::GetInstance())[0].GetLevel() | Should -Be ([LogLevel]::Info)
            $plugin.parameters.level | Should -Be 'Info'
        }

        It 'Should return the plugin instance so callers can inspect its parameters' {
            $plugin = [TextOutput]::new()
            $plugin.SetParameters(@{ message = 'hello'; level = 'Trace' })

            $result = $plugin.Execute()

            [object]::ReferenceEquals($result, $plugin) | Should -BeTrue
        }

        It 'Should write messages at or above the terminal level to the console' {
            $plugin = [TextOutput]::new()
            $plugin.SetParameters(@{ message = 'visible message'; level = 'Error' })

            $plugin.Execute() | Out-Null

            $script:writer.ToString() | Should -Match '\[ERROR\] visible message'
        }

        It 'Should report an unknown level as a failed task via RunTask()' {
            $plugin = [TextOutput]::new()
            $plugin.SetParameters(@{ message = 'bad level'; level = 'NotALevel' })

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
        }
    }
}
