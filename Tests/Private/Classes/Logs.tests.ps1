Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'Logs' {
    BeforeAll {
        # Logs no longer builds entries itself; callers hand it a finished LogEntry.
        function New-TestEntry {
            param(
                [string] $Message = 'test message',
                [LogLevel] $Level = [LogLevel]::Info,
                [string] $Source = $null
            )
            return [LogEntry]::new($Message, $Level, (Get-PSCallStack), $Source)
        }
    }

    BeforeEach {
        [Logs]::Reset()
        [Variables]::Reset()
    }

    AfterAll {
        [Logs]::Reset()
        [Variables]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same singleton instance' {
            $first = [Logs]::GetInstance()
            $second = [Logs]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeTrue
        }

        It 'returns a fresh, empty instance after Reset()' {
            $first = [Logs]::GetInstance()
            $first.AddEntry((New-TestEntry))
            [Logs]::Reset()
            $second = [Logs]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            @($second).Count | Should -Be 0
        }
    }

    Context 'AddEntry' {
        BeforeEach {
            # Silence terminal output so entries below the terminal level don't matter and
            # entries at or above it don't leak into the Pester output.
            $script:writer = [System.IO.StringWriter]::new()
            $script:originalWriter = [System.Console]::Out
            [System.Console]::SetOut($script:writer)
        }

        AfterEach {
            [System.Console]::SetOut($script:originalWriter)
            $script:writer.Dispose()
        }

        It 'stores the exact LogEntry instance' {
            $logs = [Logs]::GetInstance()
            $entry = New-TestEntry -Message 'prebuilt' -Level ([LogLevel]::Trace) -Source 'src'
            $logs.AddEntry($entry)

            @($logs).Count | Should -Be 1
            [object]::ReferenceEquals(@($logs)[0], $entry) | Should -BeTrue
        }

        It 'stores entries in insertion order, even those hidden from the terminal' {
            $logs = [Logs]::GetInstance()
            $logs.AddEntry((New-TestEntry -Message 'hidden' -Level ([LogLevel]::Trace)))
            $logs.AddEntry((New-TestEntry -Message 'shown' -Level ([LogLevel]::Error)))

            $entries = @($logs)
            $entries.Count | Should -Be 2
            $entries[0].GetMessage() | Should -Be 'hidden'
            $entries[1].GetMessage() | Should -Be 'shown'
        }

        It 'can be enumerated with foreach' {
            $logs = [Logs]::GetInstance()
            $logs.AddEntry((New-TestEntry -Message 'one'))
            $logs.AddEntry((New-TestEntry -Message 'two'))

            $messages = foreach ($entry in $logs) { $entry.GetMessage() }
            $messages | Should -Be @('one', 'two')
        }
    }

    Context 'Terminal output' {
        BeforeEach {
            $script:writer = [System.IO.StringWriter]::new()
            $script:originalWriter = [System.Console]::Out
            [System.Console]::SetOut($script:writer)
        }

        AfterEach {
            [System.Console]::SetOut($script:originalWriter)
            $script:writer.Dispose()
        }

        It 'writes the timestamp, level, and message to the terminal' {
            $originalColor = [System.Console]::ForegroundColor

            [Logs]::GetInstance().AddEntry((New-TestEntry -Message 'configuration warning' -Level ([LogLevel]::Warning)))

            $script:writer.ToString() | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[WARNING\] configuration warning\r?\n$'
            [System.Console]::ForegroundColor | Should -Be $originalColor
        }

        It 'defaults the terminal level to Warning' {
            $logs = [Logs]::GetInstance()
            $logs.AddEntry((New-TestEntry -Message 'not shown' -Level ([LogLevel]::Notice)))
            $logs.AddEntry((New-TestEntry -Message 'shown' -Level ([LogLevel]::Warning)))

            $output = $script:writer.ToString()
            $output | Should -Not -Match 'not shown'
            $output | Should -Match '\[WARNING\] shown'
        }

        It 'filters messages below the configured terminal level' {
            [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Error)
            [Logs]::GetInstance().AddEntry((New-TestEntry -Message 'hidden message' -Level ([LogLevel]::Info)))

            $script:writer.ToString() | Should -Be ''
        }

        It 'allows messages at or above the configured terminal level' {
            [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Warning)
            [Logs]::GetInstance().AddEntry((New-TestEntry -Message 'visible warning' -Level ([LogLevel]::Warning)))

            $script:writer.ToString() | Should -Match '\[WARNING\] visible warning'
        }

        It 'accepts the configured terminal level as a string, as it arrives from YAML' {
            [Variables]::GetInstance().Set('logTerminalLevel', 'Trace')
            [Logs]::GetInstance().AddEntry((New-TestEntry -Message 'very detailed' -Level ([LogLevel]::Trace)))

            $script:writer.ToString() | Should -Match '\[TRACE\] very detailed'
        }

        It 'restores the console color even when the write fails' {
            $originalColor = [System.Console]::ForegroundColor
            $script:writer.Dispose()
            $throwingWriter = [System.IO.StringWriter]::new()
            $throwingWriter.Dispose()
            [System.Console]::SetOut($throwingWriter)

            { [Logs]::GetInstance().Output((New-TestEntry -Level ([LogLevel]::Error))) } | Should -Throw
            [System.Console]::ForegroundColor | Should -Be $originalColor

            # AfterEach disposes $script:writer again, which is harmless.
        }
    }

    Context 'GetColor' {
        It 'maps <Level> to <Color>' -ForEach @(
            @{ Level = [LogLevel]::Emergency; Color = [System.ConsoleColor]::DarkRed }
            @{ Level = [LogLevel]::Alert; Color = [System.ConsoleColor]::Red }
            @{ Level = [LogLevel]::Critical; Color = [System.ConsoleColor]::Red }
            @{ Level = [LogLevel]::Error; Color = [System.ConsoleColor]::Red }
            @{ Level = [LogLevel]::Warning; Color = [System.ConsoleColor]::Yellow }
            @{ Level = [LogLevel]::Notice; Color = [System.ConsoleColor]::Cyan }
            @{ Level = [LogLevel]::Info; Color = [System.ConsoleColor]::Green }
            @{ Level = [LogLevel]::Debug; Color = [System.ConsoleColor]::Gray }
            @{ Level = [LogLevel]::Trace; Color = [System.ConsoleColor]::DarkGray }
        ) {
            [Logs]::GetInstance().GetColor($Level) | Should -Be $Color
        }

        It 'falls back to white for an unknown level' {
            # A plain [LogLevel]99 cast is rejected by PowerShell, so build the undefined value explicitly.
            $unknownLevel = [System.Enum]::ToObject([LogLevel], 99)

            [Logs]::GetInstance().GetColor($unknownLevel) | Should -Be ([System.ConsoleColor]::White)
        }
    }
}
