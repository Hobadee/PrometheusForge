function Get-ForgeLogs {
    <#
    .SYNOPSIS
    Gets the log entries from the most recent Invoke-Forge run.

    .DESCRIPTION
    Returns every log entry recorded by the most recent run of Invoke-Forge, in the order they were logged, as
    objects.  Nothing is printed to the terminal; capture the entries in a variable or pipe them to
    Search-ForgeLog to search and filter them.  Entries that are neither captured nor piped are displayed by
    PowerShell as a table of sequence, time, level, source, and message.

    Use -Print to write the entries to the terminal as log lines instead.

    Use this when you did not capture the logs with `Invoke-Forge -OutputLogs`, or when the run ended with an
    error before it could return them.

    The logs are kept until the next Invoke-Forge run starts, which discards them and begins a new set.
    If Invoke-Forge has not been run in this session, nothing is returned.

    .PARAMETER Print
    Writes the entries to the terminal, one line each, in the same format and level colors used while a workflow
    runs, instead of returning them.  Every entry is printed regardless of the terminal log level.  Nothing is
    returned, so the printed entries cannot be piped on to Search-ForgeLog; leave the switch off to search or
    filter them.

    .OUTPUTS
    LogEntry
    The recorded entries, in the order they were logged.  Nothing is returned when -Print is used.

    .EXAMPLE
    $logs = Get-ForgeLog
    $logs | Search-ForgeLog -MinimumLevel Warning

    Captures the last run's logs, then lists the warnings and errors.

    .EXAMPLE
    Get-ForgeLog -Print

    Prints the last run's logs to the terminal.

    .EXAMPLE
    try {
        Invoke-Forge -FilePath ./onboard.yaml
    }
    catch {
        Get-ForgeLog | Search-ForgeLog -Level Error
    }

    Reads the logs of a run that ended with an error.

    .NOTES
    The entries returned are the ones recorded, not copies, and are not intended to be modified.
    #>
    [CmdletBinding()]
    [OutputType([LogEntry])]
    param (
        [switch] $Print
    )

    $log = [Log]::GetInstance()

    if ($Print) {
        foreach ($entry in $log) {
            [Log]::WriteToTerminal($entry)
        }
        return
    }

    # Enumerate explicitly so each entry is written to the pipeline individually.
    foreach ($entry in $log) {
        $entry
    }
}
