<#
.SYNOPSIS
Test helper that captures (or silences) what the module writes to the terminal.

.DESCRIPTION
[Log] writes entries with [System.Console]::Out.WriteLine(), which Pester does not capture, so any test that
causes logging would otherwise print raw log lines into the test results.  These helpers swap the console's
output writer for an in-memory one for the duration of a test and put the original back afterwards.

    Start-ConsoleCapture   Redirects console output and returns the capture (a StringWriter).
    Stop-ConsoleCapture    Restores console output, disposes the capture, and returns everything captured.

The capture is a plain [System.IO.StringWriter], so `$capture.ToString()` reads what has been written so far and
`$capture.GetStringBuilder().Clear()` discards it.

.NOTES
Load it from a test file with a dot-source inside a file-level BeforeAll, so the functions exist by the time
BeforeEach / It / AfterEach blocks run (Pester 5 does not run BeforeAll during discovery).  Adjust the number of
'..' for the test file's depth under Tests/:

    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Helpers/ConsoleCapture.ps1')
    }

Silence output for a whole file (nothing needs to be inspected):

    BeforeAll { $script:capture = Start-ConsoleCapture }
    AfterAll  { [void] (Stop-ConsoleCapture $script:capture) }

Silence output for each test, and inspect it in some:

    BeforeEach { $script:writer = Start-ConsoleCapture }
    AfterEach  { [void] (Stop-ConsoleCapture $script:writer) }

    It 'warns' {
        [Log]::Warning('careful')
        $script:writer.ToString() | Should -Match '\[WARNING\] careful'
    }

To change how output is handled across every test (for example to also capture [Console]::Error, or to write to a
file for debugging), change these two functions; the tests only go through them.

Captures nest: each remembers the writer that was active when it started, and Stop-ConsoleCapture restores that one.
Stop them in the reverse order they were started.
#>

function Start-ConsoleCapture {
    [CmdletBinding()]
    [OutputType([System.IO.StringWriter])]
    param ()

    $capture = [System.IO.StringWriter]::new()

    # Remember what was active so Stop-ConsoleCapture can put it back
    Add-Member -InputObject $capture -NotePropertyName OriginalOut -NotePropertyValue ([System.Console]::Out)
    [System.Console]::SetOut($capture)

    return $capture
}


function Stop-ConsoleCapture {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.StringWriter] $Capture
    )

    # Restore first, so a failure below can never leave the console redirected
    [System.Console]::SetOut($Capture.OriginalOut)

    $text = $Capture.ToString()
    $Capture.Dispose()

    return $text
}
