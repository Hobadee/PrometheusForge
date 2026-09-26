function Search-ForgeLogs {
    <#
    .SYNOPSIS
    Searches and filters Prometheus Forge log entries.

    .DESCRIPTION
    Takes log entries, such as those returned by `Invoke-Forge -OutputLogs`, and returns only the
    entries that match every filter given.  Entries are returned as objects, so the results can be
    piped on to this function again, or to cmdlets like Where-Object, Select-Object and Format-Table.

    When no filter is given, all entries are returned.

    .PARAMETER InputObject
    The log entries to search.  Usually supplied through the pipeline.

    .PARAMETER Level
    Only entries logged at exactly this level.

    .PARAMETER MinimumLevel
    Only entries logged at this level or a more severe one.  For example, Warning returns Warning,
    Error, Critical, Alert and Emergency entries.

    .PARAMETER Source
    Only entries with this source, ignoring case.  Entries logged from within a step have that step's
    slug as their source.  An empty string returns entries that have no source.

    .PARAMETER Message
    Only entries whose message contains this text, ignoring case.

    .PARAMETER Since
    Only entries logged at or after this time.

    .PARAMETER Until
    Only entries logged at or before this time.

    .PARAMETER Sequence
    Only the entry with exactly this sequence number.  Every entry is numbered in the order it was logged during
    a run, starting at 1.  The number is kept with the entry, so it identifies the same entry after filtering
    and does not depend on the timestamp.

    .PARAMETER SinceSequence
    Only entries with this sequence number or a higher one.

    .PARAMETER UntilSequence
    Only entries with this sequence number or a lower one.

    .OUTPUTS
    LogEntry
    The matching entries, in the order they were logged.

    .EXAMPLE
    $logs = Invoke-Forge -FilePath ./Samples/Sample.Onboard.yaml -OutputLogs
    $logs | Search-ForgeLog -MinimumLevel Warning

    Runs a workflow, then lists its warnings and errors.

    .EXAMPLE
    $logs | Search-ForgeLog -Source create-user -Message 'timeout'

    Lists entries logged by the step with the slug 'create-user' whose message mentions a timeout.

    .EXAMPLE
    $logs | Search-ForgeLog -Level Error | Search-ForgeLog -Since (Get-Date).AddMinutes(-5)

    Filters can be chained by piping the results into another search.

    .EXAMPLE
    $logs | Search-ForgeLog -SinceSequence 40 -UntilSequence 60

    Lists the entries logged 40th through 60th in the run.

    .NOTES
    Filters are combined with AND.  Every entry is left untouched; this function never modifies the
    entries it is given.
    #>
    [CmdletBinding()]
    [OutputType([LogEntry])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [LogEntry[]] $InputObject,

        [LogLevel] $Level,

        [LogLevel] $MinimumLevel,

        # Not validated for empty: an empty source is how to ask for entries that have none.
        [string] $Source,

        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [datetime] $Since,

        [datetime] $Until,

        [long] $Sequence,

        [long] $SinceSequence,

        [long] $UntilSequence
    )

    begin {
        $entries = [LogEntries]::new()
    }

    process {
        foreach ($entry in $InputObject) {
            $entries.Add($entry)
        }
    }

    end {
        if ($PSBoundParameters.ContainsKey('Level')) {
            $entries = $entries.WhereLevel($Level)
        }
        if ($PSBoundParameters.ContainsKey('MinimumLevel')) {
            $entries = $entries.WhereLevelAtLeast($MinimumLevel)
        }
        if ($PSBoundParameters.ContainsKey('Source')) {
            $entries = $entries.WhereSource($Source)
        }
        if ($PSBoundParameters.ContainsKey('Message')) {
            $entries = $entries.Search($Message)
        }
        if ($PSBoundParameters.ContainsKey('Since')) {
            $entries = $entries.Since($Since)
        }
        if ($PSBoundParameters.ContainsKey('Until')) {
            $entries = $entries.Until($Until)
        }
        if ($PSBoundParameters.ContainsKey('Sequence')) {
            $entries = $entries.WhereSequence($Sequence)
        }
        if ($PSBoundParameters.ContainsKey('SinceSequence')) {
            $entries = $entries.SinceSequence($SinceSequence)
        }
        if ($PSBoundParameters.ContainsKey('UntilSequence')) {
            $entries = $entries.UntilSequence($UntilSequence)
        }

        # Enumerate explicitly so each entry is written to the pipeline individually.
        foreach ($entry in $entries) {
            $entry
        }
    }
}
