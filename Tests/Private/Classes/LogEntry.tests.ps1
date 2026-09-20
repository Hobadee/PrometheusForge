Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'LogEntry' {
    Context 'Construction' {
        It 'stores the message, level, and trace' {
            $trace = Get-PSCallStack
            $entry = [LogEntry]::new('hello', [LogLevel]::Error, $trace)

            $entry.GetMessage() | Should -Be 'hello'
            $entry.GetLevel() | Should -Be ([LogLevel]::Error)
            $entry.trace.Count | Should -Be $trace.Count
        }

        It 'leaves the source empty when none is provided' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Info, (Get-PSCallStack))

            $entry.GetSource() | Should -BeNullOrEmpty
        }

        It 'stores the provided source' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Debug, (Get-PSCallStack), 'my-step')

            $entry.GetSource() | Should -Be 'my-step'
        }

        It 'stores each log level unchanged' -ForEach @(
            @{ Level = [LogLevel]::Emergency }
            @{ Level = [LogLevel]::Warning }
            @{ Level = [LogLevel]::Info }
            @{ Level = [LogLevel]::Trace }
        ) {
            $entry = [LogEntry]::new('hello', $Level, (Get-PSCallStack))

            $entry.GetLevel() | Should -Be $Level
        }

        It 'sets the timestamp at creation time' {
            $before = [datetime]::Now
            $entry = [LogEntry]::new('hello', [LogLevel]::Info, (Get-PSCallStack))
            $after = [datetime]::Now

            $entry.GetTimestamp() | Should -BeGreaterOrEqual $before
            $entry.GetTimestamp() | Should -BeLessOrEqual $after
        }
    }

    Context 'GetTrace' {
        It 'returns the supplied call stack as text, one frame per line' {
            $trace = Get-PSCallStack
            $entry = [LogEntry]::new('hello', [LogLevel]::Info, $trace)

            $lines = $entry.GetTrace() -split '\r?\n'
            $lines.Count | Should -Be $trace.Count
            $lines[0] | Should -Be $trace[0].ToString()
        }
    }

    Context 'ToString' {
        It 'includes the timestamp, level, and message' {
            $entry = [LogEntry]::new('hello', [LogLevel]::Warning, (Get-PSCallStack))

            $entry.ToString() | Should -Be ('[{0}] [Warning]: hello' -f $entry.GetTimestamp())
        }
    }
}
