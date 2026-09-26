Using Module "../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../Helpers/ConsoleCapture.ps1')
    Remove-Module PrometheusForge -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1'
    Import-Module $modulePath -Force
}

Describe 'Search-ForgeLogs' {
    BeforeAll {
        $script:t0 = [datetime]'2026-01-01T12:00:00'

        # LogEntry stamps itself with the current time, so pin the timestamp for deterministic time filters.
        function New-TestEntry {
            param(
                [string] $Message,
                [LogLevel] $Level = [LogLevel]::Info,
                [string] $Source = $null,
                [int] $Offset = 0,
                [long] $Sequence = 0
            )
            $entry = [LogEntry]::new($Message, $Level)
            $entry.timestamp = $script:t0.AddSeconds($Offset)
            $entry.SetTrace((Get-PSCallStack))
            if ($Source) { $entry.SetSource($Source) }
            if ($Sequence -gt 0) { $entry.SetSequence($Sequence) }
            return $entry
        }

        function Get-Messages {
            param([Parameter(ValueFromPipeline)] $Entry)
            begin { $messages = @() }
            process { $messages += $Entry.GetMessage() }
            end { , $messages }
        }
    }

    BeforeEach {
        $script:logs = @(
            New-TestEntry -Message 'loading config' -Level ([LogLevel]::Trace) -Source 'loader' -Offset 0 -Sequence 1
            New-TestEntry -Message 'Config loaded' -Level ([LogLevel]::Info) -Source 'Loader' -Offset 10 -Sequence 2
            New-TestEntry -Message 'disk almost full' -Level ([LogLevel]::Warning) -Source 'storage' -Offset 20 -Sequence 3
            New-TestEntry -Message 'Timeout talking to server' -Level ([LogLevel]::Error) -Source 'net' -Offset 30 -Sequence 4
            New-TestEntry -Message 'no source here' -Level ([LogLevel]::Error) -Offset 40 -Sequence 5
        )
    }

    Context 'Input' {
        It 'returns every entry, in order, when no filter is given' {
            $result = $script:logs | Search-ForgeLogs

            ($result | Get-Messages) | Should -Be @('loading config', 'Config loaded', 'disk almost full', 'Timeout talking to server', 'no source here')
        }

        It 'returns the original LogEntry objects' {
            $result = @($script:logs | Search-ForgeLogs -Source 'net')

            [object]::ReferenceEquals($result[0], $script:logs[3]) | Should -BeTrue
        }

        It 'accepts entries through -InputObject' {
            $result = @(Search-ForgeLogs -InputObject $script:logs -Level Warning)

            $result.Count | Should -Be 1
            $result[0].GetMessage() | Should -Be 'disk almost full'
        }

        It 'returns nothing when piped nothing' {
            @($null | Where-Object { $_ } | Search-ForgeLogs -Level Error).Count | Should -Be 0
        }

        It 'returns nothing for an empty -InputObject' {
            @(Search-ForgeLogs -InputObject @()).Count | Should -Be 0
        }

        It 'returns nothing when no entry matches' {
            @($script:logs | Search-ForgeLogs -Level Emergency).Count | Should -Be 0
        }

        It 'does not modify the entries it is given' {
            $before = $script:logs.Count

            $script:logs | Search-ForgeLogs -Level Error | Out-Null

            $script:logs.Count | Should -Be $before
        }

        It 'rejects input that is not a log entry' {
            # A pipeline binding failure is non-terminating unless the caller asks for it to stop.
            { 'not an entry' | Search-ForgeLogs -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Level' {
        It 'returns only entries at exactly that level' {
            ($script:logs | Search-ForgeLogs -Level Error | Get-Messages) | Should -Be @('Timeout talking to server', 'no source here')
        }

        It 'accepts the level name in any case' {
            @($script:logs | Search-ForgeLogs -Level 'warning').Count | Should -Be 1
        }

        It 'treats Emergency as a level to filter on, not as an unset parameter' {
            $emergency = New-TestEntry -Message 'boom' -Level ([LogLevel]::Emergency)

            $result = @(($script:logs + $emergency) | Search-ForgeLogs -Level Emergency)

            $result.Count | Should -Be 1
            $result[0].GetMessage() | Should -Be 'boom'
        }

        It 'rejects a level that does not exist' {
            { $script:logs | Search-ForgeLogs -Level NotALevel } | Should -Throw
        }
    }

    Context 'MinimumLevel' {
        It 'returns entries at that level and more severe ones' {
            ($script:logs | Search-ForgeLogs -MinimumLevel Warning | Get-Messages) |
                Should -Be @('disk almost full', 'Timeout talking to server', 'no source here')
        }

        It 'returns everything for the least severe level' {
            @($script:logs | Search-ForgeLogs -MinimumLevel Trace).Count | Should -Be 5
        }
    }

    Context 'Source' {
        It 'matches the source ignoring case' {
            ($script:logs | Search-ForgeLogs -Source LOADER | Get-Messages) | Should -Be @('loading config', 'Config loaded')
        }

        It 'does not match on part of a source' {
            @($script:logs | Search-ForgeLogs -Source 'load').Count | Should -Be 0
        }

        It 'returns entries with no source when given an empty source' {
            ($script:logs | Search-ForgeLogs -Source '' | Get-Messages) | Should -Be @('no source here')
        }
    }

    Context 'Message' {
        It 'matches message text ignoring case' {
            ($script:logs | Search-ForgeLogs -Message CONFIG | Get-Messages) | Should -Be @('loading config', 'Config loaded')
        }

        It 'matches part of a message' {
            ($script:logs | Search-ForgeLogs -Message 'almost' | Get-Messages) | Should -Be @('disk almost full')
        }

        It 'does not search the source' {
            @($script:logs | Search-ForgeLogs -Message 'storage').Count | Should -Be 0
        }

        It 'rejects an empty message' {
            { $script:logs | Search-ForgeLogs -Message '' } | Should -Throw
        }
    }

    Context 'Since and Until' {
        It 'Since includes entries at or after the time' {
            ($script:logs | Search-ForgeLogs -Since $script:t0.AddSeconds(30) | Get-Messages) | Should -Be @('Timeout talking to server', 'no source here')
        }

        It 'Until includes entries at or before the time' {
            ($script:logs | Search-ForgeLogs -Until $script:t0.AddSeconds(10) | Get-Messages) | Should -Be @('loading config', 'Config loaded')
        }

        It 'selects a window when both are given' {
            $result = $script:logs | Search-ForgeLogs -Since $script:t0.AddSeconds(5) -Until $script:t0.AddSeconds(25)

            ($result | Get-Messages) | Should -Be @('Config loaded', 'disk almost full')
        }
    }

    Context 'Sequence' {
        It '-Sequence returns the entry with exactly that number' {
            ($script:logs | Search-ForgeLogs -Sequence 3 | Get-Messages) | Should -Be @('disk almost full')
        }

        It '-Sequence 0 is a filter, not an unset parameter' {
            @($script:logs | Search-ForgeLogs -Sequence 0).Count | Should -Be 0
        }

        It '-SinceSequence includes entries at or after the number' {
            ($script:logs | Search-ForgeLogs -SinceSequence 4 | Get-Messages) | Should -Be @('Timeout talking to server', 'no source here')
        }

        It '-UntilSequence includes entries at or before the number' {
            ($script:logs | Search-ForgeLogs -UntilSequence 2 | Get-Messages) | Should -Be @('loading config', 'Config loaded')
        }

        It 'selects a range when both are given' {
            $result = $script:logs | Search-ForgeLogs -SinceSequence 2 -UntilSequence 4

            ($result | Get-Messages) | Should -Be @('Config loaded', 'disk almost full', 'Timeout talking to server')
        }

        It 'keeps the original sequence numbers on the entries it returns' {
            $result = @($script:logs | Search-ForgeLogs -Level Error)

            $result.ForEach({ $_.GetSequence() }) | Should -Be @(4, 5)
        }

        It 'finds an entry by sequence number after filtering it by other means first' {
            $result = @($script:logs | Search-ForgeLogs -MinimumLevel Warning | Search-ForgeLogs -Sequence 4)

            $result.Count | Should -Be 1
            $result[0].GetMessage() | Should -Be 'Timeout talking to server'
        }
    }

    Context 'Combining filters' {
        It 'requires an entry to match every filter given' {
            $result = $script:logs | Search-ForgeLogs -Level Error -Source net -Message 'timeout'

            ($result | Get-Messages) | Should -Be @('Timeout talking to server')
        }

        It 'returns nothing when the filters cannot all match' {
            @($script:logs | Search-ForgeLogs -Level Error -Source storage).Count | Should -Be 0
        }

        It 'can be chained through the pipeline' {
            $result = $script:logs | Search-ForgeLogs -MinimumLevel Warning | Search-ForgeLogs -Source net

            ($result | Get-Messages) | Should -Be @('Timeout talking to server')
        }
    }

    Context 'With Invoke-Forge' {
        BeforeAll {
            $script:workflow = Join-Path $TestDrive 'search.yaml'
            @'
name: Search workflow
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Say hello
      slug: say-hello
      plugin: TextOutput
      parameters:
        message: hello there
        level: Info
    - type: step
      name: Say problem
      slug: say-problem
      plugin: TextOutput
      parameters:
        message: something went wrong
        level: Error
'@ | Set-Content -Path $script:workflow -Encoding utf8
        }

        BeforeEach {
            # Keep terminal log output from leaking into the Pester output.
            $script:writer = Start-ConsoleCapture
        }

        AfterEach {
            [void] (Stop-ConsoleCapture $script:writer)
        }

        It 'searches the logs returned by Invoke-Forge -OutputLogs' {
            $runLogs = Invoke-Forge -FilePath $script:workflow -OutputLogs

            $errors = @($runLogs | Search-ForgeLogs -MinimumLevel Error -Message 'something went wrong')

            $errors.Count | Should -Be 1
            $errors[0].GetLevel() | Should -Be ([LogLevel]::Error)
        }

        It 'finds the output of a single step by its message' {
            $runLogs = Invoke-Forge -FilePath $script:workflow -OutputLogs

            @($runLogs | Search-ForgeLogs -Message 'hello there').Count | Should -Be 1
            @($runLogs | Search-ForgeLogs -Level Info -Message 'hello there' | Search-ForgeLogs -Message 'something went wrong').Count | Should -Be 0
        }
    }
}
