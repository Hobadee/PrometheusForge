class Log {
    <#
    .SYNOPSIS
    Provides static methods for logging messages at various levels.

    .DESCRIPTION
    The Log class acts as a factory for creating and writing log entries.
    It supports different log levels and ensures that all log entries are properly recorded.

    .NOTES
    We need to be very careful where we initiate `GetPSCallStack` from, as it captures the current call stack
    and may not reflect the intended context if called too early or too late.  We should always call it at the
    originating call to [Log] + 1
    #>


    static [void]Add([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace) {
        $log = [LogEntry]::new($message, $level, $trace)
        [Logs]::GetInstance().AddEntry($log)
    }

    static [void]Add([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace, [string] $source) {
        $log = [LogEntry]::new($message, $level, $trace, $source)
        [Logs]::GetInstance().AddEntry($log)
    }


    ###

    
    # Clears the singleton so the next GetInstance() call starts a fresh run
    static [void] Reset() {
        [Logs]::Reset()
    }


    ### Overloaded Write Methods ###

    static [void] Write([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Add($message, [LogLevel]::Info, $trace)
    }

    static [void] Write([string] $message, [LogLevel] $level) {
        $trace = Get-PSCallStack
        [Log]::Add($message, $level, $trace)
    }

    static [void] Write([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace) {
        [Log]::Add($message, $level, $trace)
    }

    static [void] Write([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace, [string] $source) {
        [Log]::Add($message, $level, $trace, $source)
    }

    ### End Overloaded Write Methods ###


    static [void] Debug([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Debug, $trace)
    }
    static [void] Debug([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Debug, $trace, $source)
    }


    static [void] Trace([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Trace, $trace)
    }
    static [void] Trace([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Trace, $trace, $source)
    }


    static [void] Info([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace)
    }
    static [void] Info([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace, $source)
    }


    static [void] Warning([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Warning, $trace)
    }
    static [void] Warning([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Warning, $trace, $source)
    }


    static [void] Error([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Error, $trace)
    }
    static [void] Error([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Error, $trace, $source)
    }


    static [void] Verbose([string] $message) {
        <#
        .SYNOPSIS
        Logs a verbose message to the console.

        .DESCRIPTION
        "Verbose" doesn't actually exist in our log levels, but it's a PowerShell
        standard, so we are mapping it here to make it easy to use within our logging framework.
        #>
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace)
    }
    static [void] Verbose([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace, $source)
    }
}
