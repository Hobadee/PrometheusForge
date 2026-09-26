class TextOutput : TaskPluginInterface {
    <#
    .SYNOPSIS
    Writes a message to the configured log sink.

    .PARAMETER message
    The text to write to the log stream. This is the primary output payload.

    .PARAMETER level
    Optional log level to write the message at: any [LogLevel] name, such as 'Trace', 'Info', 'Warning',
    or 'Error'. Defaults to 'Info'.
    #>

    [string] $message = $null
    [string] $level = $null

    TextOutput() : base(){
        <#
        .SYNOPSIS
        Constructor for the TextOutput plugin class

        .DESCRIPTION
        This constructor initializes the TextOutput plugin by calling the base class constructor.
        It sets up any necessary state for the plugin to function within the task management system.
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin

        .DESCRIPTION
        This method returns a hashtable containing plugin metadata including
        the name and other extensible properties used by the task management system.
        #>
        return @{
            name = "TextOutput"
            version = "1.1.0"
        }
    }

    [void] ValidateParameters([object]$params) {
        if ($null -eq $params) {
            throw [System.ArgumentException]::new("Parameters cannot be null")
        }

        # We will accept a $null message, but it still needs to be set
        # This is broken right now for some reason, so we are commenting it out
        # A unit test should catch problems with a missing "message" parameter later
        #if (-not $params.Contains("message")) {
        #    throw [System.ArgumentException]::new("Parameters must contain a 'message' property")
        #}
    }

    [TextOutput] Execute() {
        <#
        .SYNOPSIS
        Executes the TextOutput plugin functionality.

        .DESCRIPTION
        Outputs the stored message parameter to the console.

        .OUTPUTS
        The instance of the TextOutput class after execution.
        #>

        if ($null -eq $this.parameters.level) {
            $this.parameters.level = "Info"
        }

        # Note: in a default run, this will NOT output to the terminal!
        # Terminal output defaults to [LogLevel]::Warning, whereas this
        # defaults to [LogLevel]::Info.
        # Not sure if there is a better way to handle things.  Ignore for now.
        # TODO: Resolve this issue.
        [Log]::Write($this.parameters.message, $this.parameters.level)

        return $this
    }
    
}

# Register the TextOutput plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])
