class LogEntryFactory {

    static [LogLevel] $defaultLevel = [LogLevel]::Info


    static [LogEntry] Create([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace, [string] $source) {
        $entry = [LogEntry]::new($message, $level)
        $entry.SetTrace($trace)
        $entry.SetSource($source)
        return $entry
    }

    static [LogEntry] Create([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace) {
        $entry = [LogEntry]::new($message, $level)
        $entry.SetTrace($trace)
        return $entry
    }

    static [LogEntry] Create([string] $message, [LogLevel] $level) {
        $entry = [LogEntry]::new($message, $level)

        # $trace = Get-PSCallStack | Select-Object -Skip 1
        $trace = Get-PSCallStack
        $entry.SetTrace($trace)

        return $entry
    }

    static [LogEntry] Create([string] $message) {
        $entry = [LogEntry]::new($message, [LogEntryFactory]::defaultLevel)

        # $trace = Get-PSCallStack | Select-Object -Skip 1
        $trace = Get-PSCallStack
        $entry.SetTrace($trace)

        return $entry
    }
}
