Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'Log' {
    BeforeEach {
        [Log]::Reset()
        [Variables]::Reset()
    }

    AfterAll {
        [Log]::Reset()
        [Variables]::Reset()
    }

    Context 'Write' {
        It 'records an entry in the Logs singleton' {
            [Log]::Write('recorded', [LogLevel]::Trace)

            $entries = @([Logs]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetMessage() | Should -Be 'recorded'
            $entries[0].GetLevel() | Should -Be ([LogLevel]::Trace)
        }

        It 'defaults to the Info level when no level is given' {
            [Log]::Write('default level')

            @([Logs]::GetInstance())[0].GetLevel() | Should -Be ([LogLevel]::Info)
        }

        It 'accepts the level as a case-insensitive string' {
            [Log]::Write('string level', 'debug')

            @([Logs]::GetInstance())[0].GetLevel() | Should -Be ([LogLevel]::Debug)
        }
    }

    Context 'Level helpers' {
        It 'maps <Method> to the <Level> level' -ForEach @(
            @{ Method = 'Debug'; Level = [LogLevel]::Debug }
            @{ Method = 'Trace'; Level = [LogLevel]::Trace }
            @{ Method = 'Info'; Level = [LogLevel]::Info }
            @{ Method = 'Warning'; Level = [LogLevel]::Warning }
            @{ Method = 'Error'; Level = [LogLevel]::Error }
            @{ Method = 'Verbose'; Level = [LogLevel]::Info }
        ) {
            $writer = [System.IO.StringWriter]::new()
            $originalWriter = [System.Console]::Out

            try {
                [System.Console]::SetOut($writer)
                [Log]::$Method("$Method message")
            }
            finally {
                [System.Console]::SetOut($originalWriter)
                $writer.Dispose()
            }

            $entries = @([Logs]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetMessage() | Should -Be "$Method message"
            $entries[0].GetLevel() | Should -Be $Level
        }
    }

    Context 'Reset' {
        It 'clears all recorded entries' {
            [Log]::Info('before reset')
            [Log]::Reset()

            @([Logs]::GetInstance()).Count | Should -Be 0
        }
    }

    Context 'Terminal output' {
        It 'writes warnings to the terminal by default' {
            $writer = [System.IO.StringWriter]::new()
            $originalWriter = [System.Console]::Out

            try {
                [System.Console]::SetOut($writer)
                [Log]::Warning('configuration warning')

                $writer.ToString() | Should -Match '\[WARNING\] configuration warning'
            }
            finally {
                [System.Console]::SetOut($originalWriter)
                $writer.Dispose()
            }
        }

        It 'does not write messages below the configured terminal level' {
            $writer = [System.IO.StringWriter]::new()
            $originalWriter = [System.Console]::Out

            try {
                [System.Console]::SetOut($writer)
                [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Error)
                [Log]::Info('hidden message')

                $writer.ToString() | Should -Be ''
            }
            finally {
                [System.Console]::SetOut($originalWriter)
                $writer.Dispose()
            }
        }
    }
}
