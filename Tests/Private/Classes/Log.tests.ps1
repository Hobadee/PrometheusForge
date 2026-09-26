Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'Log' {
    BeforeAll {
        function New-TestEntry {
            param(
                [string] $Message = 'test message',
                [LogLevel] $Level = [LogLevel]::Info,
                [string] $Source = $null
            )
            $entry = [LogEntry]::new($Message, $Level)
            $entry.SetTrace((Get-PSCallStack))
            if ($Source) { $entry.SetSource($Source) }
            return $entry
        }
    }

    BeforeEach {
        [Log]::Reset()
        [Variables]::Reset()

        # Capture console output so entries at or above the terminal level don't leak into Pester output.
        $script:writer = [System.IO.StringWriter]::new()
        $script:originalWriter = [System.Console]::Out
        [System.Console]::SetOut($script:writer)
    }

    AfterEach {
        [System.Console]::SetOut($script:originalWriter)
        $script:writer.Dispose()
    }

    AfterAll {
        [Log]::Reset()
        [Variables]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same singleton instance' {
            [object]::ReferenceEquals([Log]::GetInstance(), [Log]::GetInstance()) | Should -BeTrue
        }

        It 'starts with an empty LogEntries' {
            $log = [Log]::GetInstance()

            $log.Entries.GetType().Name | Should -Be 'LogEntries'
            $log.Entries.Count() | Should -Be 0
        }

        It 'returns a fresh, empty instance after Reset()' {
            $first = [Log]::GetInstance()
            $first.AddEntry((New-TestEntry))
            [Log]::Reset()
            $second = [Log]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            $second.Entries.Count() | Should -Be 0
        }

        It 'restarts sequence numbering after Reset()' {
            [Log]::Warning('before reset')
            [Log]::Warning('before reset again')
            [Log]::Reset()
            [Log]::Warning('after reset')

            @([Log]::GetInstance())[0].GetSequence() | Should -Be 1
        }
    }

    Context 'AddEntry' {
        It 'stores the exact LogEntry instance' {
            $log = [Log]::GetInstance()
            $entry = New-TestEntry -Message 'prebuilt' -Level ([LogLevel]::Trace)
            $log.AddEntry($entry)

            @($log).Count | Should -Be 1
            [object]::ReferenceEquals(@($log)[0], $entry) | Should -BeTrue
        }

        It 'assigns consecutive sequence numbers starting at 1' {
            $log = [Log]::GetInstance()
            $log.AddEntry((New-TestEntry -Message 'a' -Level ([LogLevel]::Trace)))
            $log.AddEntry((New-TestEntry -Message 'b' -Level ([LogLevel]::Trace)))
            $log.AddEntry((New-TestEntry -Message 'c' -Level ([LogLevel]::Trace)))

            @($log | ForEach-Object { $_.GetSequence() }) | Should -Be @(1, 2, 3)
        }

        It 'keeps sequence numbers on filtered views unchanged' {
            $log = [Log]::GetInstance()
            $log.AddEntry((New-TestEntry -Message 'a' -Level ([LogLevel]::Trace)))
            $log.AddEntry((New-TestEntry -Message 'b' -Level ([LogLevel]::Error)))

            @($log.Entries.WhereLevel([LogLevel]::Error))[0].GetSequence() | Should -Be 2
        }

        It 'throws when the entry already has a sequence number, and does not store it' {
            $log = [Log]::GetInstance()
            $entry = New-TestEntry -Level ([LogLevel]::Trace)
            $entry.SetSequence(10)

            $exceptionType = [System.InvalidOperationException]
            { $log.AddEntry($entry) } | Should -Throw -ExceptionType $exceptionType
            $log.Entries.Count() | Should -Be 0
        }

        It 'stores entries in insertion order, even those hidden from the terminal' {
            $log = [Log]::GetInstance()
            $log.AddEntry((New-TestEntry -Message 'hidden' -Level ([LogLevel]::Trace)))
            $log.AddEntry((New-TestEntry -Message 'shown' -Level ([LogLevel]::Error)))

            @($log | ForEach-Object { $_.GetMessage() }) | Should -Be @('hidden', 'shown')
        }

        It 'enumerates the same entries as its Entries property' {
            $log = [Log]::GetInstance()
            $log.AddEntry((New-TestEntry -Message 'one' -Level ([LogLevel]::Trace)))

            @($log).Count | Should -Be $log.Entries.Count()
        }
    }

    Context 'Write' {
        It 'records an entry with the message and level' {
            [Log]::Write('recorded', [LogLevel]::Trace)

            $entries = @([Log]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetMessage() | Should -Be 'recorded'
            $entries[0].GetLevel() | Should -Be ([LogLevel]::Trace)
            $entries[0].GetSequence() | Should -Be 1
            $entries[0].hasTrace() | Should -BeTrue
        }

        It 'defaults to the Info level when no level is given' {
            [Log]::Write('default level')

            @([Log]::GetInstance())[0].GetLevel() | Should -Be ([LogLevel]::Info)
        }

        It 'accepts the level as a case-insensitive string' {
            [Log]::Write('string level', 'debug')

            @([Log]::GetInstance())[0].GetLevel() | Should -Be ([LogLevel]::Debug)
        }

        It 'records an explicit trace without a source' {
            [Log]::Write('with trace', [LogLevel]::Notice, (Get-PSCallStack))

            $entry = @([Log]::GetInstance())[0]
            $entry.hasSource() | Should -BeFalse
            $entry.GetTrace() | Should -Not -BeNullOrEmpty
        }

        It 'records the source passed with an explicit trace' {
            [Log]::Write('with source', [LogLevel]::Notice, (Get-PSCallStack), 'writer-source')

            $entry = @([Log]::GetInstance())[0]
            $entry.GetSource() | Should -Be 'writer-source'
            $entry.GetTrace() | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Level helpers' {
        It 'maps <Method> to the <Level> level' -ForEach @(
            @{ Method = 'Trace'; Level = [LogLevel]::Trace }
            @{ Method = 'Debug'; Level = [LogLevel]::Debug }
            @{ Method = 'Info'; Level = [LogLevel]::Info }
            @{ Method = 'Notice'; Level = [LogLevel]::Notice }
            @{ Method = 'Warning'; Level = [LogLevel]::Warning }
            @{ Method = 'Error'; Level = [LogLevel]::Error }
            @{ Method = 'Critical'; Level = [LogLevel]::Critical }
            @{ Method = 'Alert'; Level = [LogLevel]::Alert }
            @{ Method = 'Emergency'; Level = [LogLevel]::Emergency }
            @{ Method = 'Verbose'; Level = [LogLevel]::Info }
        ) {
            [Log]::$Method("$Method message")

            $entries = @([Log]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetMessage() | Should -Be "$Method message"
            $entries[0].GetLevel() | Should -Be $Level
            $entries[0].hasSource() | Should -BeFalse
        }

        It 'records the source passed to <Method>' -ForEach @(
            @{ Method = 'Trace'; Level = [LogLevel]::Trace }
            @{ Method = 'Debug'; Level = [LogLevel]::Debug }
            @{ Method = 'Info'; Level = [LogLevel]::Info }
            @{ Method = 'Notice'; Level = [LogLevel]::Notice }
            @{ Method = 'Warning'; Level = [LogLevel]::Warning }
            @{ Method = 'Error'; Level = [LogLevel]::Error }
            @{ Method = 'Critical'; Level = [LogLevel]::Critical }
            @{ Method = 'Alert'; Level = [LogLevel]::Alert }
            @{ Method = 'Emergency'; Level = [LogLevel]::Emergency }
            @{ Method = 'Verbose'; Level = [LogLevel]::Info }
        ) {
            [Log]::$Method("$Method message", 'my-source')

            $entries = @([Log]::GetInstance())
            $entries.Count | Should -Be 1
            $entries[0].GetLevel() | Should -Be $Level
            $entries[0].GetSource() | Should -Be 'my-source'
        }

        It 'numbers entries from different helpers in call order' {
            [Log]::Info('first')
            [Log]::Error('second')
            [Log]::Debug('third')

            @([Log]::GetInstance() | ForEach-Object { "$($_.GetSequence()):$($_.GetMessage())" }) |
                Should -Be @('1:first', '2:second', '3:third')
        }
    }

    Context 'Searching the recorded entries' {
        It 'supports filtering through the Entries property' {
            [Log]::Info('starting')
            [Log]::Error('disk failure')
            [Log]::Warning('disk almost full')

            $found = [Log]::GetInstance().Entries.WhereLevelAtLeast([LogLevel]::Warning).Search('disk')

            @($found | ForEach-Object { $_.GetMessage() }) | Should -Be @('disk failure', 'disk almost full')
        }
    }

    Context 'Terminal output' {
        It 'writes the timestamp, level, and message to the terminal' {
            $originalColor = [System.Console]::ForegroundColor

            [Log]::GetInstance().AddEntry((New-TestEntry -Message 'configuration warning' -Level ([LogLevel]::Warning)))

            $script:writer.ToString() | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[WARNING\] configuration warning\r?\n$'
            [System.Console]::ForegroundColor | Should -Be $originalColor
        }

        It 'includes the source tag when the entry has a source' {
            [Log]::Warning('sourced warning', 'my-step')

            $script:writer.ToString() | Should -Match '\[WARNING\] \[my-step\] sourced warning'
        }

        It 'defaults the terminal level to Warning' {
            [Log]::Notice('not shown')
            [Log]::Warning('shown')

            $output = $script:writer.ToString()
            $output | Should -Not -Match 'not shown'
            $output | Should -Match '\[WARNING\] shown'
        }

        It 'filters messages below the configured terminal level' {
            [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Error)
            [Log]::Info('hidden message')

            $script:writer.ToString() | Should -Be ''
        }

        It 'accepts the configured terminal level as a string, as it arrives from YAML' {
            [Variables]::GetInstance().Set('logTerminalLevel', 'Trace')
            [Log]::Trace('very detailed')

            $script:writer.ToString() | Should -Match '\[TRACE\] very detailed'
        }

        It 'records entries hidden from the terminal' {
            [Log]::Info('hidden but recorded')

            $script:writer.ToString() | Should -Be ''
            [Log]::GetInstance().Entries.Count() | Should -Be 1
        }

        It 'WriteToTerminal shows an entry regardless of its level' {
            [Log]::GetInstance().WriteToTerminal((New-TestEntry -Message 'forced' -Level ([LogLevel]::Trace)))

            $script:writer.ToString() | Should -Match '\[TRACE\] forced'
        }

        It 'WriteToTerminal throws on a null entry' {
            $exceptionType = [System.ArgumentNullException]
            { [Log]::GetInstance().WriteToTerminal($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'restores the console color even when the write fails' {
            $originalColor = [System.Console]::ForegroundColor
            $throwingWriter = [System.IO.StringWriter]::new()
            $throwingWriter.Dispose()
            [System.Console]::SetOut($throwingWriter)

            { [Log]::GetInstance().WriteToTerminal((New-TestEntry -Level ([LogLevel]::Error))) } | Should -Throw
            [System.Console]::ForegroundColor | Should -Be $originalColor
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
            [Log]::GetInstance().GetColor($Level) | Should -Be $Color
        }

        It 'falls back to white for an unknown level' {
            # A plain [LogLevel]99 cast is rejected by PowerShell, so build the undefined value explicitly.
            $unknownLevel = [System.Enum]::ToObject([LogLevel], 99)

            [Log]::GetInstance().GetColor($unknownLevel) | Should -Be ([System.ConsoleColor]::White)
        }
    }
}
