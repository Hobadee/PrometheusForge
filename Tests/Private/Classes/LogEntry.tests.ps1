Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'LogEntry' {
    Context 'Construction' {
        It 'stores the message and level' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Error)

            $entry.GetMessage() | Should -Be 'hello'
            $entry.GetLevel() | Should -Be ([LogLevel]::Error)
        }

        It 'stores each log level unchanged' -ForEach @(
            @{ Level = [LogLevel]::Emergency }
            @{ Level = [LogLevel]::Warning }
            @{ Level = [LogLevel]::Info }
            @{ Level = [LogLevel]::Trace }
        ) {
            [LogEntry]::new('hello', $Level).GetLevel() | Should -Be $Level
        }

        It 'sets the timestamp at creation time' {
            $before = [datetime]::Now
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $after = [datetime]::Now

            $entry.GetTimestamp() | Should -BeGreaterOrEqual $before
            $entry.GetTimestamp() | Should -BeLessOrEqual $after
        }

        It 'starts with no sequence, source, or trace' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)

            $entry.hasSequence() | Should -BeFalse
            $entry.hasSource() | Should -BeFalse
            $entry.hasTrace() | Should -BeFalse
            $entry.GetSequence() | Should -Be 0
            $entry.GetSource() | Should -BeNullOrEmpty
            $entry.GetTrace() | Should -BeNullOrEmpty
        }
    }

    Context 'SetSequence' {
        It 'stores the sequence number' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetSequence(5)

            $entry.GetSequence() | Should -Be 5
            $entry.hasSequence() | Should -BeTrue
        }

        It 'throws when the sequence is set a second time, leaving the first value intact' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetSequence(5)

            $exceptionType = [System.InvalidOperationException]
            { $entry.SetSequence(6) } | Should -Throw -ExceptionType $exceptionType
            $entry.GetSequence() | Should -Be 5
        }

        It 'rejects a sequence below 1 (<Value>)' -ForEach @(
            @{ Value = 0 }
            @{ Value = -1 }
        ) {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)

            $exceptionType = [System.ArgumentOutOfRangeException]
            { $entry.SetSequence($Value) } | Should -Throw -ExceptionType $exceptionType
            $entry.hasSequence() | Should -BeFalse
        }
    }

    Context 'SetTrace' {
        It 'stores the trace' {
            $trace = Get-PSCallStack
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetTrace($trace)

            $entry.hasTrace() | Should -BeTrue
            $entry.trace.Count | Should -Be $trace.Count
        }

        It 'throws when the trace is set a second time' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetTrace((Get-PSCallStack))

            $exceptionType = [System.InvalidOperationException]
            { $entry.SetTrace((Get-PSCallStack)) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'SetSource' {
        It 'stores the source' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetSource('my-step')

            $entry.GetSource() | Should -Be 'my-step'
            $entry.hasSource() | Should -BeTrue
        }

        It 'throws when the source is set a second time, leaving the first value intact' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetSource('first')

            $exceptionType = [System.InvalidOperationException]
            { $entry.SetSource('second') } | Should -Throw -ExceptionType $exceptionType
            $entry.GetSource() | Should -Be 'first'
        }
    }

    Context 'GetTrace' {
        It 'returns the supplied call stack as text, one frame per line' {
            $trace = Get-PSCallStack
            $entry = [LogEntry]::new('hello', [LogLevel]::Info)
            $entry.SetTrace($trace)

            $lines = $entry.GetTrace() -split '\r?\n'
            $lines.Count | Should -Be $trace.Count
            $lines[0] | Should -Be $trace[0].ToString()
        }
    }

    Context 'ToString' {
        It 'includes the timestamp, level, and message' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Warning)

            $entry.ToString() | Should -Be ('[{0}] [Warning]: hello' -f $entry.GetTimestamp())
        }
    }
}
