class Log : System.Collections.IEnumerable{
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
    TODO: This class currently does too much.  Need to clean up and separate responsibilities.
    #>

    # Class Variables
    static [Log] $Instance = $null
    static [LogLevel] $DefaultTerminalLevel = [LogLevel]::Warning

    # Instance Variables
    [LogEntries] $Entries = $null
    [long] $sequence = 1
    [int] $currentIndex = 0


    <#######################>
    <# Lifecycle Functions #>
    <#######################>


    # Hidden constructor to help enforce singleton pattern
    hidden Log() {
        $this.Entries = [LogEntries]::new()
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

    
    # Returns a snapshot of every entry recorded this run, which can be searched and filtered.
    # A snapshot is returned so callers can't add entries to the shared set and bypass sequencing and terminal output.
    static [LogEntries] GetEntries() {
        return [Log]::GetInstance().Entries.Snapshot()
    }


    <#############################
    # IEnumerable implementation #
    #############################>


    # Everything simply passes through to the underlying Entries IEnumerable implementation.
    [System.Collections.IEnumerator] GetEnumerator() {
        return $this.Entries.GetEnumerator()
    }
    [void] SetCurrentIndex([int] $index) {
        $this.Entries.SetCurrentIndex($index)
    }
    [LogEntry] GetCurrentItem() {
        return $this.Entries.GetCurrentItem()
    }
    [int] Count() {
        return $this.Entries.Count()
    }


    <####################>
    <# Recording Entries #>
    <####################>


    [void] AddEntry([LogEntry] $entry) {
        $entry.SetSequence($this.sequence)
        $this.sequence++

        $this.Entries.Add($entry)

        # For now we will default to outputting all log entries to the terminal
        [Log]::Output($entry)
    }

    
    <###########################>
    <# Static Write Functions  #>
    <###########################>


    static [void] Write([string] $message) {
        $trace = Get-PSCallStack
        $log = [LogEntryFactory]::Create($message, [LogLevel]::Info, $trace)
        [Log]::GetInstance().AddEntry($log)
    }

    static [void] Write([string] $message, [LogLevel] $level) {
        $trace = Get-PSCallStack
        $log = [LogEntryFactory]::Create($message, $level, $trace)
        [Log]::GetInstance().AddEntry($log)
    }

    static [void] Write([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace) {
        $log = [LogEntryFactory]::Create($message, $level, $trace)
        [Log]::GetInstance().AddEntry($log)
    }

    static [void] Write([string] $message, [LogLevel] $level, [System.Management.Automation.CallStackFrame[]] $trace, [string] $source) {
        $log = [LogEntryFactory]::Create($message, $level, $trace, $source)
        [Log]::GetInstance().AddEntry($log)
    }

    
    <###########################>
    <# Static Logger Functions #>
    <###########################>


    static [void] Trace([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Trace, $trace)
    }
    static [void] Trace([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Trace, $trace, $source)
    }


    static [void] Debug([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Debug, $trace)
    }
    static [void] Debug([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Debug, $trace, $source)
    }


    static [void] Info([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace)
    }
    static [void] Info([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Info, $trace, $source)
    }


    static [void] Notice([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Notice, $trace)
    }
    static [void] Notice([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Notice, $trace, $source)
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


    static [void] Critical([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Critical, $trace)
    }
    static [void] Critical([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Critical, $trace, $source)
    }


    static [void] Alert([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Alert, $trace)
    }
    static [void] Alert([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Alert, $trace, $source)
    }


    static [void] Emergency([string] $message) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Emergency, $trace)
    }
    static [void] Emergency([string] $message, [string] $source) {
        $trace = Get-PSCallStack
        [Log]::Write($message, [LogLevel]::Emergency, $trace, $source)
    }

    
    <#################################>
    <# Alias Static Logger Functions #>
    <#################################>


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


    <####################>
    <# Output Functions #>
    <####################>

    <#
    Output functions should move to plugins.  After every log entry is created, `Output()` is called for each plugin.
    At the end of the run, `Flush()` is called for each plugin to ensure all log entries are properly outputted/written as needed.

    Ideally `Output()` is called asynchronously for each plugin to avoid blocking the main execution flow, but I'm not sure that's
    possible with PowerShell.
    #>


    static [void] Output([LogEntry] $entry) {

        # Default terminal log level, if none specified
        $terminalLevel = [Log]::DefaultTerminalLevel

        $variables = [Variables]::GetInstance()
        if ($variables.HasKey('logTerminalLevel')) {
            # Config values come in from YAML as strings, so coerce explicitly
            $terminalLevel = [LogLevel] $variables.Get('logTerminalLevel')
        }

        # If the log level is below or equal to the terminal log level, output the message to the terminal
        if ([int] $entry.GetLevel() -le [int] $terminalLevel) {
            [Log]::WriteToTerminal($entry)
        }

    }


    # Writes one entry to the terminal in the standard log format and level color, whatever its level.
    # Output() decides *whether* an entry is shown; this only shows it.
    # This should eventually be moved to a terminal-output handler class.
    static[void] WriteToTerminal([LogEntry] $entry) {
        if ($null -eq $entry) {
            throw [System.ArgumentNullException]::new('entry', 'Entry cannot be null')
        }

        $timestamp = $entry.GetTimestamp().ToString('yyyy-MM-dd HH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture)
        $levelName = $entry.GetLevel().ToString().ToUpperInvariant()
        $originalColor = [System.Console]::ForegroundColor
        try {
            [System.Console]::ForegroundColor = [Log]::GetColor($entry.GetLevel())
            # Entries logged from within a step carry that step's slug as their source
            $sourceTag = ''
            if (-not [string]::IsNullOrEmpty($entry.GetSource())) {
                $sourceTag = "[$($entry.GetSource())] "
            }
            [System.Console]::Out.WriteLine("[$timestamp] [$levelName] $sourceTag$($entry.GetMessage())")
        }
        finally {
            [System.Console]::ForegroundColor = $originalColor
        }
    }


    static [System.ConsoleColor] GetColor([LogLevel] $level) {
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


}
