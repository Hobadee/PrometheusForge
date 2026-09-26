Using Module "../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../Helpers/ConsoleCapture.ps1')
    Remove-Module PrometheusForge -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-ForgeLogs' {
    BeforeAll {
        function New-Workflow {
            param([string] $Name, [string] $Content)
            $path = Join-Path $TestDrive $Name
            $Content | Set-Content -Path $path -Encoding utf8
            return $path
        }

        $script:firstWorkflow = New-Workflow 'first.yaml' @'
name: First workflow
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
        message: hello from the first run
        level: Info
'@

        $script:secondWorkflow = New-Workflow 'second.yaml' @'
name: Second workflow
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Say goodbye
      slug: say-goodbye
      plugin: TextOutput
      parameters:
        message: goodbye from the second run
        level: Info
'@

        $missing = Join-Path $TestDrive 'does-not-exist.yaml'
        $script:abortingWorkflow = New-Workflow 'aborting.yaml' @"
name: Aborting workflow
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Import something missing
      slug: import-missing
      plugin: ImportConfig
      onError: abort
      retry:
        retries: 1
        delay: 0
      parameters:
        URI: '$missing'
        SourcePluginName: yamlSource
"@

        $script:noRootWorkflow = New-Workflow 'no-root.yaml' @'
name: No root
version: 1.0
variables:
  onlyVariables: true
'@
    }

    BeforeEach {
        # Keep terminal log output from leaking into the Pester output.
        $script:writer = Start-ConsoleCapture
    }

    AfterEach {
        [void] (Stop-ConsoleCapture $script:writer)
    }

    Context 'Reading the logs of a run' {
        It 'returns nothing when nothing has been logged' {
            [Log]::Reset()

            @(Get-ForgeLogs).Count | Should -Be 0
        }

        It 'returns the entries of the last run, in order, without -OutputLogs' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $entries = @(Get-ForgeLogs)

            $entries.Count | Should -BeGreaterThan 0
            $entries[0] | Should -BeOfType ([LogEntry])
            $entries.ForEach({ $_.GetSequence() }) | Should -Be (1..$entries.Count)
            $entries.ForEach({ $_.GetMessage() }) | Should -Contain 'hello from the first run'
        }

        It 'returns the same entries as -OutputLogs' {
            $fromRun = @(Invoke-Forge -FilePath $script:firstWorkflow -OutputLogs)

            $fromGet = @(Get-ForgeLogs)

            $fromGet.Count | Should -Be $fromRun.Count
            $fromGet.ForEach({ $_.GetSequence() }) | Should -Be $fromRun.ForEach({ $_.GetSequence() })
        }

        It 'returns the same entries each time it is called' {
            Invoke-Forge -FilePath $script:firstWorkflow

            @(Get-ForgeLogs).Count | Should -Be @(Get-ForgeLogs).Count
        }

        It 'can be piped to Search-ForgeLogs' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $found = @(Get-ForgeLogs | Search-ForgeLogs -Message 'hello from')

            $found.Count | Should -Be 1
            $found[0].GetSequence() | Should -BeGreaterThan 0
        }
    }

    Context 'Returning versus printing' {
        BeforeEach {
            Invoke-Forge -FilePath $script:firstWorkflow

            # Discard what the run itself wrote to the terminal, so only Get-ForgeLog's own output is measured.
            [void] $script:writer.GetStringBuilder().Clear()
        }

        It 'prints nothing to the terminal by default' {
            $logs = Get-ForgeLogs

            $script:writer.ToString() | Should -Be ''
            $logs.Count | Should -BeGreaterThan 0
        }

        It 'returns the entries so they can be captured, indexed, and counted' {
            $logs = Get-ForgeLogs

            $logs.Count | Should -BeGreaterThan 0
            $logs[0] | Should -BeOfType ([LogEntry])
            $logs[0].GetSequence() | Should -Be 1
        }

        It 'returns entries that can be searched and filtered' {
            $logs = Get-ForgeLogs

            @($logs | Search-ForgeLogs -Level Info).Count | Should -BeGreaterThan 0
            @($logs | Search-ForgeLogs -Level Emergency).Count | Should -Be 0
        }

        It 'prints every entry to the terminal, one line each, with -Print' {
            $expected = @(Get-ForgeLogs).Count
            [void] $script:writer.GetStringBuilder().Clear()

            Get-ForgeLogs -Print

            $lines = @($script:writer.ToString() -split '\r?\n' | Where-Object { $_ })
            $lines.Count | Should -Be $expected
            $lines | ForEach-Object { $_ | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[[A-Z]+\] ' }
        }

        It 'prints entries in the same format as the live terminal output' {
            Get-ForgeLogs -Print

            $script:writer.ToString() | Should -Match '\[INFO\] hello from the first run'
        }

        It 'prints entries below the terminal log level with -Print' {
            # The run used the default terminal level (Warning), so its Trace entries were never shown.
            Get-ForgeLogs -Print

            $script:writer.ToString() | Should -Match '\[TRACE\] Completed successfully'
        }

        It 'returns nothing with -Print' {
            @(Get-ForgeLogs -Print).Count | Should -Be 0
        }

        It 'leaves the recorded logs unchanged after -Print' {
            $before = @(Get-ForgeLogs).Count

            Get-ForgeLogs -Print

            @(Get-ForgeLogs).Count | Should -Be $before
        }

        It 'prints nothing with -Print when nothing has been logged' {
            [Log]::Reset()
            [void] $script:writer.GetStringBuilder().Clear()

            Get-ForgeLogs -Print

            $script:writer.ToString() | Should -Be ''
        }
    }

    Context 'Display' {
        It 'is shown as a compact table rather than a property dump when not captured' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $display = Get-ForgeLogs | Out-String -Width 200

            $display | Should -Match 'Seq\s+Time\s+Level\s+Source\s+Message'
            $display | Should -Match 'hello from the first run'
            $display | Should -Not -Match 'trace\s+:'
        }

        It 'ships the format file with the module' {
            (Get-Module PrometheusForge).ExportedFormatFiles | Should -Not -BeNullOrEmpty
        }

        It 'lists the read-only properties, without the call-stack trace, in Format-List *' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $display = Get-ForgeLogs | Select-Object -First 1 | Format-List * | Out-String

            $display | Should -Match '(?m)^Sequence\s+: 1'
            $display | Should -Match '(?m)^Message\s+: '
            $display | Should -Not -Match '(?m)^Trace\s+:'
        }

        It 'can be exported to CSV with its sequence numbers' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $rows = @(Get-ForgeLogs | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -BeGreaterThan 0
            $rows[0].Sequence | Should -Be '1'
            $rows.Message | Should -Contain 'hello from the first run'
        }

        It 'still reads every field through the getters' {
            Invoke-Forge -FilePath $script:firstWorkflow

            $entry = Get-ForgeLogs | Select-Object -First 1

            $entry.GetSequence() | Should -Be 1
            $entry.GetMessage() | Should -Not -BeNullOrEmpty
            $entry.GetTrace() | Should -Not -BeNullOrEmpty
            $entry.GetTimestamp() | Should -BeOfType ([datetime])
        }
    }

    Context 'After a run that ends with an error' {
        It 'still returns the entries when the workflow is invalid' {
            { Invoke-Forge -FilePath $script:noRootWorkflow } | Should -Throw

            @(Get-ForgeLogs).ForEach({ $_.GetMessage() }) | Should -Contain "Loading configuration from '$script:noRootWorkflow'."
        }

        It 'returns the Error logged for a step that aborts the run' {
            { Invoke-Forge -FilePath $script:abortingWorkflow } | Should -Throw

            $errors = @(Get-ForgeLogs | Search-ForgeLogs -Level Emergency)

            $errors.Count | Should -Be 1
            $errors[0].GetMessage() | Should -Match '^Aborting after 1 attempts'
        }
    }

    Context 'Starting a new run' {
        It 'discards the entries of the previous run' {
            Invoke-Forge -FilePath $script:firstWorkflow
            Invoke-Forge -FilePath $script:secondWorkflow

            $messages = @(Get-ForgeLogs).ForEach({ $_.GetMessage() })

            $messages | Should -Contain 'goodbye from the second run'
            $messages | Should -Not -Contain 'hello from the first run'
        }

        It 'restarts the sequence numbers at 1' {
            Invoke-Forge -FilePath $script:firstWorkflow
            $firstRunCount = @(Get-ForgeLogs).Count

            Invoke-Forge -FilePath $script:secondWorkflow

            $entries = @(Get-ForgeLogs)
            $entries[0].GetSequence() | Should -Be 1
            $entries[-1].GetSequence() | Should -Be $entries.Count
            $firstRunCount | Should -BeGreaterThan 0
        }

        It 'clears logging state left over from before the run' {
            # Simulate state that would otherwise leak into the run: old entries and a used sequence counter.
            [Log]::Info('left over from before')

            Invoke-Forge -FilePath $script:firstWorkflow

            $entries = @(Get-ForgeLogs)
            $entries.ForEach({ $_.GetMessage() }) | Should -Not -Contain 'left over from before'
            $entries[0].GetSequence() | Should -Be 1
        }

        It 'starts a new run cleanly after a run that ended with an error' {
            { Invoke-Forge -FilePath $script:abortingWorkflow } | Should -Throw

            Invoke-Forge -FilePath $script:firstWorkflow

            $entries = @(Get-ForgeLogs)
            $entries.Where({ $_.GetLevel() -eq [LogLevel]::Error }).Count | Should -Be 0
            $entries[0].GetSequence() | Should -Be 1
        }
    }
}
