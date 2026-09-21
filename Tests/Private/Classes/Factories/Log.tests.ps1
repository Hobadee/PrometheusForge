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

    Context 'Source overloads' {
        BeforeEach {
            $script:writer = [System.IO.StringWriter]::new()
            $script:originalWriter = [System.Console]::Out
            [System.Console]::SetOut($script:writer)
        }

        AfterEach {
            [System.Console]::SetOut($script:originalWriter)
            $script:writer.Dispose()
        }

        It 'records the source passed to <Method>' -ForEach @(
            @{ Method = 'Debug'; Level = [LogLevel]::Debug }
            @{ Method = 'Trace'; Level = [LogLevel]::Trace }
            @{ Method = 'Info'; Level = [LogLevel]::Info }
            @{ Method = 'Warning'; Level = [LogLevel]::Warning }
            @{ Method = 'Error'; Level = [LogLevel]::Error }
            @{ Method = 'Verbose'; Level = [LogLevel]::Info }
        ) {
            [Log]::$Method("$Method message", 'my-source')

            $entries = @([Logs]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetMessage() | Should -Be "$Method message"
            $entries[0].GetLevel() | Should -Be $Level
            $entries[0].GetSource() | Should -Be 'my-source'
        }

        It 'records the source passed to Write() along with an explicit trace' {
            $trace = Get-PSCallStack

            [Log]::Write('with source', [LogLevel]::Notice, $trace, 'writer-source')

            $entry = @([Logs]::GetInstance())[0]
            $entry.GetMessage() | Should -Be 'with source'
            $entry.GetLevel() | Should -Be ([LogLevel]::Notice)
            $entry.GetSource() | Should -Be 'writer-source'
            $entry.GetTrace() | Should -Not -BeNullOrEmpty
        }

        It 'records an explicit trace passed to Write() without a source' {
            $trace = Get-PSCallStack

            [Log]::Write('with trace', [LogLevel]::Notice, $trace)

            $entry = @([Logs]::GetInstance())[0]
            $entry.GetMessage() | Should -Be 'with trace'
            $entry.GetSource() | Should -BeNullOrEmpty
            $entry.GetTrace() | Should -Not -BeNullOrEmpty
        }

        It 'leaves the source empty when none is given' {
            [Log]::Info('no source')

            @([Logs]::GetInstance())[0].GetSource() | Should -BeNullOrEmpty
        }

        It 'Add() records entries with and without a source' {
            $trace = Get-PSCallStack

            [Log]::Add('plain', [LogLevel]::Trace, $trace)
            [Log]::Add('sourced', [LogLevel]::Trace, $trace, 'add-source')

            $entries = @([Logs]::GetInstance())
            $entries.Count | Should -Be 2
            $entries[0].GetSource() | Should -BeNullOrEmpty
            $entries[1].GetSource() | Should -Be 'add-source'
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
