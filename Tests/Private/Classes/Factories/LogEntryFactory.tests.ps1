Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'LogEntryFactory' {
    Context 'Create' {
        It 'builds an entry from a message alone, using the default level and a captured trace' {
            $entry = [LogEntryFactory]::Create('just a message')

            $entry.GetMessage() | Should -Be 'just a message'
            $entry.GetLevel() | Should -Be ([LogEntryFactory]::defaultLevel)
            $entry.hasTrace() | Should -BeTrue
            $entry.hasSource() | Should -BeFalse
        }

        It 'builds an entry from a message and level, capturing a trace' {
            $entry = [LogEntryFactory]::Create('with level', [LogLevel]::Error)

            $entry.GetMessage() | Should -Be 'with level'
            $entry.GetLevel() | Should -Be ([LogLevel]::Error)
            $entry.hasTrace() | Should -BeTrue
            $entry.hasSource() | Should -BeFalse
        }

        It 'uses the supplied trace' {
            $trace = Get-PSCallStack
            $entry = [LogEntryFactory]::Create('with trace', [LogLevel]::Debug, $trace)

            $entry.GetLevel() | Should -Be ([LogLevel]::Debug)
            $entry.trace.Count | Should -Be $trace.Count
            $entry.hasSource() | Should -BeFalse
        }

        It 'sets the source when one is supplied' {
            $entry = [LogEntryFactory]::Create('with source', [LogLevel]::Notice, (Get-PSCallStack), 'my-step')

            $entry.GetSource() | Should -Be 'my-step'
            $entry.hasTrace() | Should -BeTrue
        }

        It 'leaves the sequence unset; the Log assigns it' {
            [LogEntryFactory]::Create('no sequence').hasSequence() | Should -BeFalse
        }
    }
}
