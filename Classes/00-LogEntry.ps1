class LogEntry{
    <#
    .SYNOPSIS
    Represents a single log entry with message, level, timestamp, source, trace, and slug.

    .DESCRIPTION
    The LogEntry class encapsulates all relevant information for a log entry.
    It includes the message, log level, timestamp, source of the log, trace information, and a slug for identification.

    .NOTES
    Levels, as defined in [Logs]
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

    # "source" should either be a trace, or a slug.
    [string] $source = $null
    [System.Management.Automation.CallStackFrame[]] $trace = $null

    # Automatically Set Parameters
    [datetime] $timestamp = [datetime]::MinValue


    LogEntry([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace) {
        $this.timestamp = [datetime]::Now
        $this.message = $message
        $this.level = $level
        $this.trace = $trace
    }

    LogEntry([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace, [string] $source) {
        $this.timestamp = [datetime]::Now
        $this.message = $message
        $this.level = $level
        $this.trace = $trace
        $this.source = $source
    }


    [string] ToString() {
        $rtn = "[{0}] [{1}]: {2}" -f $this.timestamp, $this.level, $this.message
        return $rtn
    }


    [string] GetSource() {
        return $this.source
    }


    [string] GetTrace() {
        return ($this.trace | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
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
    
}
