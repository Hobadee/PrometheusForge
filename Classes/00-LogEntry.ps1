class LogEntry{
    <#
    .SYNOPSIS
    Represents a single log entry with message, level, timestamp, source, trace, and source.

    .DESCRIPTION
    The LogEntry class encapsulates all relevant information for a log entry.
    It includes the message, log level, timestamp, source of the log, trace information, and a source for identification.

    .NOTES
    Levels, as defined in [LogLevel]
        Emergency = 0
        Alert     = 1
        Critical  = 2
        Error     = 3
        Warning   = 4
        Notice    = 5
        Info      = 6
        Debug     = 7
        Trace     = 8
    #>

    # Passed Parameters
    [string] $message = $null
    [LogLevel] $level =  [LogLevel]::Info

    # Other Parameters
    # Hidden so Format-List, Select-Object and Export-Csv don't dump the call stack; read it with GetTrace()
    hidden [System.Management.Automation.CallStackFrame[]] $trace = $null
    [string] $source = $null
    [long] $sequence = 0

    # Automatically Set Parameters
    [datetime] $timestamp = [datetime]::MinValue


    LogEntry([string] $message, [LogLevel] $level) {
        $this.timestamp = [datetime]::Now
        $this.message = $message
        $this.level = $level
    }


    [string] ToString() {
        $rtn = "[{0}] [{1}]: {2}" -f $this.timestamp, $this.level, $this.message
        return $rtn
    }


    [string] GetSource() {
        return $this.source
    }


    [string] GetTrace() {
        if (-not $this.hasTrace()) {
            return ''
        }
        return ($this.trace | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    }


    [System.Management.Automation.CallStackFrame[]] GetTraceRaw() {
        if (-not $this.hasTrace()) {
            return $null
        }
        return $this.trace
    }


    [string] GetMessage() {
        return $this.message
    }


    [LogLevel] GetLevel() {
        return $this.level
    }


    [datetime] GetTimestamp() {
        return $this.timestamp
    }


    [long] GetSequence() {
        return $this.sequence
    }


    [bool] hasSequence(){
        return $this.sequence -ne 0
    }


    [bool] hasSource(){
        # [string] fields coerce $null to "", so test for empty rather than $null
        return -not [string]::IsNullOrEmpty($this.source)
    }


    [bool] hasTrace(){
        return $null -ne $this.trace
    }


    <###########
     # SETTERS #
     ###########>


    [void] SetSequence([long] $sequence) {
        <#
        .SYNOPSIS
        Sets the sequence number for the log entry.

        .DESCRIPTION
        This method is called by the [Log] class when it records the entry. An entry is assigned a sequence number only once.
        If the entry already has a sequence number, an exception is thrown.
        #>
        if ($sequence -lt 1) {
            throw [System.ArgumentOutOfRangeException]::new('sequence', 'Sequence must be 1 or greater')
        }
        if ($this.sequence -ne 0) {
            throw [System.InvalidOperationException]::new("Entry already has sequence number $($this.sequence)")
        }
        $this.sequence = $sequence
    }


    [void] SetTrace([System.Management.Automation.CallStackFrame[]] $trace) {
        <#
        .SYNOPSIS
        Sets the trace for the log entry.

        .DESCRIPTION
        This method sets the trace for the log entry.
        #>
        if ($null -ne $this.trace) {
            throw [System.InvalidOperationException]::new("Entry already has a trace")
        }
        $this.trace = $trace
    }


    [void] SetSource([string] $source) {
        <#
        .SYNOPSIS
        Sets the source for the log entry.

        .DESCRIPTION
        This method sets the source for the log entry.
        #>
        if ($this.hasSource()) {
            throw [System.InvalidOperationException]::new("Entry already has a source")
        }
        $this.source = $source
    }
    
}
