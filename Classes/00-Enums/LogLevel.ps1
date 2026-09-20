<#
.SYNOPSIS
Represents the various log levels used in the logging system.

.DESCRIPTION
The LogLevel enum defines the severity levels for log messages, ranging from Emergency (most severe) to Trace (least severe).

This is mostly taken from the standard syslog severity levels, although I added the Trace level for very fine-grained debugging information.

.NOTES
The "verbose" log level exists in PowerShell, but it is not included in this enum since we are attempting
to stick to standard log levels for the most part.  Use the "Info" level instead for verbose output.

We make a `[Log]::Verbose()` method available, but it maps to the "Info" log level.
#>

enum LogLevel {
    Emergency = 0
    Alert     = 1
    Critical  = 2
    Error     = 3
    Warning   = 4
    Notice    = 5
    Info      = 6
    Debug     = 7
    Trace     = 8
}
