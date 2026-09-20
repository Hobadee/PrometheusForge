class Logs : System.Collections.IEnumerable{
    <#
    .SYNOPSIS
    Represents a logging utility for outputting messages at various log levels.

    .DESCRIPTION
    The Log class provides static methods for logging messages at different severity levels.
    It supports terminal output based on a configurable log level.

    .NOTES
    This class is implemented as a singleton to ensure no issues when writing to files or other shared resources.

    TODO: Writing to file or other resources can be done at exit time via a dedicated cleanup or flush method.
    TODO: Make log locations plugins
    #>

    static [Logs] $Instance = $null
    [System.Collections.Generic.List[LogEntry]] $Entries = [System.Collections.Generic.List[LogEntry]]::new()


    # Hidden constructor to enforce singleton pattern
    hidden Logs() {
    }


    static [Logs] GetInstance() {
        if ($null -eq [Logs]::Instance) {
            [Logs]::Instance = [Logs]::new()
        }

        return [Logs]::Instance
    }

    
    # Clears the singleton so the next GetInstance() call starts a fresh run
    static [void] Reset() {
        [Logs]::Instance = $null
    }


    [void] AddEntry([LogEntry] $entry) {
        $this.Entries.Add($entry)

        # For now we will default to outputting all log entries to the terminal
        $this.Output($entry)
    }


    [void] Output([LogEntry] $entry) {

        # Default terminal log level, if none specified
        $terminalLevel = [LogLevel]::Warning

        $variables = [Variables]::GetInstance()
        if ($variables.HasKey('logTerminalLevel')) {
            # Config values come in from YAML as strings, so coerce explicitly
            $terminalLevel = [LogLevel] $variables.Get('logTerminalLevel')
        }

        # If the log level is below or equal to the terminal log level, output the message to the terminal
        if ([int] $entry.GetLevel() -le [int] $terminalLevel) {
            $timestamp = $entry.GetTimestamp().ToString('yyyy-MM-dd HH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture)
            $levelName = $entry.GetLevel().ToString().ToUpperInvariant()
            $originalColor = [System.Console]::ForegroundColor
            try {
                [System.Console]::ForegroundColor = $this.GetColor($entry.GetLevel())
                [System.Console]::Out.WriteLine("[$timestamp] [$levelName] $($entry.GetMessage())")
            }
            finally {
                [System.Console]::ForegroundColor = $originalColor
            }
        }

    }


    [System.ConsoleColor] GetColor([LogLevel] $level) {
        <#
        .SYNOPSIS
        Gets the console color associated with a specific log level.

        .DESCRIPTION
        Maps each log level to a corresponding console color for terminal output.

        .NOTES
        TODO: This method needs to move to an OutputHandler class in the future.
        #>
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

        # Unknown log level, default to white color
        return [System.ConsoleColor]::White
    }


    [System.Collections.IEnumerator] GetEnumerator() {
        return $this.Entries.GetEnumerator()
    }


}
