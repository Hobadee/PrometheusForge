Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'LogEntries' {
    BeforeAll {
        function New-TestEntry {
            param(
                [string] $Message = 'test message',
                [LogLevel] $Level = [LogLevel]::Info,
                [string] $Source = $null,
                [long] $Sequence = 0
            )
            $entry = [LogEntry]::new($Message, $Level)
            if ($Source) { $entry.SetSource($Source) }
            if ($Sequence -gt 0) { $entry.SetSequence($Sequence) }
            return $entry
        }

        function Get-Messages([LogEntries] $Entries) {
            return @(foreach ($e in $Entries) { $e.GetMessage() })
        }
    }

    Context 'Add and enumeration' {
        It 'starts empty' {
            $entries = [LogEntries]::new()

            $entries.Count() | Should -Be 0
            @($entries).Count | Should -Be 0
        }

        It 'enumerates entries in insertion order' {
            $entries = [LogEntries]::new()
            $entries.Add((New-TestEntry -Message 'one'))
            $entries.Add((New-TestEntry -Message 'two'))

            $entries.Count() | Should -Be 2
            Get-Messages $entries | Should -Be @('one', 'two')
        }

        It 'stores the exact LogEntry instance' {
            $entries = [LogEntries]::new()
            $entry = New-TestEntry
            $entries.Add($entry)

            [object]::ReferenceEquals(@($entries)[0], $entry) | Should -BeTrue
        }

        It 'throws when adding null' {
            $entries = [LogEntries]::new()

            $exceptionType = [System.ArgumentNullException]
            { $entries.Add($null) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Construction from a collection' {
        It 'copies the entries from the supplied collection' {
            $list = [System.Collections.Generic.List[LogEntry]]::new()
            $list.Add((New-TestEntry -Message 'a'))
            $list.Add((New-TestEntry -Message 'b'))

            $entries = [LogEntries]::new($list)

            Get-Messages $entries | Should -Be @('a', 'b')
        }

        It 'is independent of the source collection afterwards' {
            $list = [System.Collections.Generic.List[LogEntry]]::new()
            $list.Add((New-TestEntry -Message 'a'))
            $entries = [LogEntries]::new($list)
            $list.Add((New-TestEntry -Message 'b'))

            $entries.Count() | Should -Be 1
        }
    }

    Context 'Snapshot' {
        It 'returns a new object with the same entries' {
            $entries = [LogEntries]::new()
            $entries.Add((New-TestEntry -Message 'one'))

            $snapshot = $entries.Snapshot()

            [object]::ReferenceEquals($snapshot, $entries) | Should -BeFalse
            Get-Messages $snapshot | Should -Be @('one')
            [object]::ReferenceEquals(@($snapshot)[0], @($entries)[0]) | Should -BeTrue
        }

        It 'does not see entries added to the original afterwards' {
            $entries = [LogEntries]::new()
            $entries.Add((New-TestEntry -Message 'one'))
            $snapshot = $entries.Snapshot()
            $entries.Add((New-TestEntry -Message 'two'))

            $snapshot.Count() | Should -Be 1
            $entries.Count() | Should -Be 2
        }
    }

    Context 'Index access' {
        It 'throws from SetCurrentIndex when the index is out of range (<Index>)' -ForEach @(
            @{ Index = -1 }
            @{ Index = 0 }
            @{ Index = 3 }
        ) {
            $entries = [LogEntries]::new()
            if ($Index -ne 0) { $entries.Add((New-TestEntry)) }

            $exceptionType = [System.ArgumentOutOfRangeException]
            { $entries.SetCurrentIndex($Index) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'returns the first entry from GetCurrentItem by default' {
            $entries = [LogEntries]::new()
            $entries.Add((New-TestEntry -Message 'first'))
            $entries.Add((New-TestEntry -Message 'second'))

            $entries.GetCurrentItem().GetMessage() | Should -Be 'first'
        }

        It 'returns the entry at the index set by SetCurrentIndex' {
            $entries = [LogEntries]::new()
            $entries.Add((New-TestEntry -Message 'first'))
            $entries.Add((New-TestEntry -Message 'second'))
            $entries.SetCurrentIndex(1)

            $entries.GetCurrentItem().GetMessage() | Should -Be 'second'
        }

        It 'throws from GetCurrentItem when there are no entries' {
            $exceptionType = [System.InvalidOperationException]
            { [LogEntries]::new().GetCurrentItem() } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Filtering and searching' {
        BeforeEach {
            $base = [datetime]::new(2026, 1, 1, 12, 0, 0)
            $script:entries = [LogEntries]::new()
            $script:entries.Add((New-TestEntry -Message 'disk full'        -Level ([LogLevel]::Error)   -Source 'step-a' -Sequence 1))
            $script:entries.Add((New-TestEntry -Message 'Disk cleaned'     -Level ([LogLevel]::Info)    -Source 'STEP-A' -Sequence 2))
            $script:entries.Add((New-TestEntry -Message 'network timeout'  -Level ([LogLevel]::Warning) -Source 'step-b' -Sequence 3))
            $script:entries.Add((New-TestEntry -Message 'trace detail'     -Level ([LogLevel]::Trace)   -Sequence 4))
            $script:entries.Add((New-TestEntry -Message 'fatal (crash)'    -Level ([LogLevel]::Critical) -Sequence 5))
        }

        It 'WhereLevel returns only exact matches' {
            Get-Messages $script:entries.WhereLevel([LogLevel]::Warning) | Should -Be @('network timeout')
        }

        It 'WhereLevelAtLeast includes the level and anything more severe' {
            Get-Messages $script:entries.WhereLevelAtLeast([LogLevel]::Warning) |
                Should -Be @('disk full', 'network timeout', 'fatal (crash)')
        }

        It 'WhereSource matches ignoring case and skips entries without a source' {
            Get-Messages $script:entries.WhereSource('step-a') | Should -Be @('disk full', 'Disk cleaned')
        }

        It 'WhereSequence returns the entry with that sequence number' {
            Get-Messages $script:entries.WhereSequence(3) | Should -Be @('network timeout')
            $script:entries.WhereSequence(99).Count() | Should -Be 0
        }

        It 'SinceSequence is inclusive' {
            Get-Messages $script:entries.SinceSequence(4) | Should -Be @('trace detail', 'fatal (crash)')
        }

        It 'UntilSequence is inclusive' {
            Get-Messages $script:entries.UntilSequence(2) | Should -Be @('disk full', 'Disk cleaned')
        }

        It 'Since and Until are inclusive on the timestamp' {
            $entries = [LogEntries]::new()
            $first = New-TestEntry -Message 'first'
            Start-Sleep -Milliseconds 20
            $second = New-TestEntry -Message 'second'
            Start-Sleep -Milliseconds 20
            $third = New-TestEntry -Message 'third'
            foreach ($e in $first, $second, $third) { $entries.Add($e) }

            Get-Messages $entries.Since($second.GetTimestamp()) | Should -Be @('second', 'third')
            Get-Messages $entries.Until($second.GetTimestamp()) | Should -Be @('first', 'second')
        }

        It 'Search matches messages ignoring case' {
            Get-Messages $script:entries.Search('disk') | Should -Be @('disk full', 'Disk cleaned')
        }

        It 'Search treats the text as a regular expression' {
            Get-Messages $script:entries.Search('^(network|trace)') | Should -Be @('network timeout', 'trace detail')
        }

        It 'Search supports a case-sensitive match through an inline option' {
            Get-Messages $script:entries.Search('(?-i)Disk') | Should -Be @('Disk cleaned')
        }

        It 'Search throws on an empty pattern' {
            $exceptionType = [System.ArgumentNullException]
            { $script:entries.Search('') } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Search throws on an invalid pattern' {
            # PowerShell wraps the .NET exception raised by the regex constructor
            $thrown = $null
            try { $script:entries.Search('(unclosed') } catch { $thrown = $_.Exception }

            $thrown | Should -Not -BeNullOrEmpty
            ($thrown.InnerException -is [System.ArgumentException]) | Should -BeTrue
        }

        It 'Filter keeps entries for which the predicate is true' {
            $result = $script:entries.Filter({ $_.GetMessage().Length -gt 12 })

            Get-Messages $result | Should -Be @('network timeout', 'fatal (crash)')
        }

        It 'Filter throws on a null predicate' {
            $exceptionType = [System.ArgumentNullException]
            { $script:entries.Filter($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'returns a new LogEntries and leaves the original untouched' {
            $result = $script:entries.WhereLevel([LogLevel]::Error)

            $result.GetType().Name | Should -Be 'LogEntries'
            [object]::ReferenceEquals($result, $script:entries) | Should -BeFalse
            $script:entries.Count() | Should -Be 5
        }

        It 'shares the LogEntry instances with the original' {
            $result = $script:entries.WhereSequence(1)

            [object]::ReferenceEquals(@($result)[0], @($script:entries)[0]) | Should -BeTrue
        }

        It 'returns an empty set when nothing matches' {
            $script:entries.WhereLevel([LogLevel]::Emergency).Count() | Should -Be 0
        }

        It 'can be chained' {
            $result = $script:entries.WhereLevelAtLeast([LogLevel]::Warning).Search('timeout')

            Get-Messages $result | Should -Be @('network timeout')
        }
    }
}
