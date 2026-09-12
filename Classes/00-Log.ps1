enum LogLevel {
    Emergency  = 0
    Alert     = 1
    Critical  = 2
    Error     = 3
    Warning   = 4
    Notice    = 5
    Info      = 6
    Debug     = 7
    Trace     = 8
}


class Log {
    <#
    .SYNOPSIS
    Represents a logging utility for outputting messages at various log levels.

    .DESCRIPTION
    The Log class provides static methods for logging messages at different severity levels.
    It supports terminal output based on a configurable log level.

    .NOTES
    This class is implemented as a singleton to ensure no issues when writing to files or other shared resources.

    TODO: Make `LogEntry` a separate class to encapsulate individual log entries with timestamp, level, and message.
          Writing to file or other resources can be done at exit time via a dedicated cleanup or flush method.
    TODO: Make log locations plugins
    #>

    static [Log] $Instance = $null


    Log() {
    }


    static [Log] GetInstance() {
        if ($null -eq [Log]::Instance) {
            [Log]::Instance = [Log]::new()
        }

        return [Log]::Instance
    }

    
    # Clears the singleton so the next GetInstance() call starts a fresh run
    static [void] Reset() {
        [Log]::Instance = $null
    }



    static [void] Write([string] $message, [LogLevel] $level) {
        $logger = [Log]::GetInstance()

        # Default terminal log level, if none specified
        $terminalLevel = [LogLevel]::Warning

        $variables = [Variables]::GetInstance()
        if ($variables.HasKey('logTerminalLevel')) {
            # Config values come in from YAML as strings, so coerce explicitly
            $terminalLevel = [LogLevel] $variables.Get('logTerminalLevel')
        }

        # If the log level is below or equal to the terminal log level, output the message to the terminal
        if ([int] $level -le [int] $terminalLevel) {
            $timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture)
            $levelName = $level.ToString().ToUpperInvariant()
            $originalColor = [System.Console]::ForegroundColor
            try {
                [System.Console]::ForegroundColor = [Log]::GetColor($level)
                [System.Console]::Out.WriteLine("[$timestamp] [$levelName] $message")
            }
            finally {
                [System.Console]::ForegroundColor = $originalColor
            }
        }

    }


    static [System.ConsoleColor] GetColor([LogLevel] $level) {
        switch ($level) {
            ([LogLevel]::Emergency) { return [System.ConsoleColor]::DarkRed }
            ([LogLevel]::Alert) { return [System.ConsoleColor]::Red }
            ([LogLevel]::Critical) { return [System.ConsoleColor]::Red }
            ([LogLevel]::Error) { return [System.ConsoleColor]::Red }
            ([LogLevel]::Warning) { return [System.ConsoleColor]::Yellow }
            ([LogLevel]::Notice) { return [System.ConsoleColor]::Cyan }
            ([LogLevel]::Info) { return [System.ConsoleColor]::Green }
            ([LogLevel]::Debug) { return [System.ConsoleColor]::Gray }
            ([LogLevel]::Trace) { return [System.ConsoleColor]::DarkGray }
        }

        return [System.ConsoleColor]::White
    }


    static [void] Debug([string] $message) {
        [Log]::Write($message, [LogLevel]::Debug)
    }


    static [void] Trace([string] $message) {
        [Log]::Write($message, [LogLevel]::Trace)
    }


    static [void] Info([string] $message) {
        [Log]::Write($message, [LogLevel]::Info)
    }


    static [void] Warning([string] $message) {
        [Log]::Write($message, [LogLevel]::Warning)
    }


    static [void] Error([string] $message) {
        [Log]::Write($message, [LogLevel]::Error)
    }


    static [void] Verbose([string] $message) {
        <#
        .SYNOPSIS
        Logs a verbose message to the console.

        .DESCRIPTION
        "Verbose" doesn't actually exist in our log levels, but it's a PowerShell
        standard, so we are mapping it here to make it easy to use within our logging framework.
        #>
        [Log]::Write($message, [LogLevel]::Info)
    }
}
