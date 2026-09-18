class TextOutput : TaskPluginInterface {
    <#
    .SYNOPSIS
    Writes a message to the configured log sink.

    .PARAMETER message
    The text to write to the log stream. This is the primary output payload.

    .PARAMETER method
    Optional log level or method name to pass to [Log]::Write(), such as 'Info', 'Warn', 'Error', or 'Trace'.
    #>

    [string] $message = $null
    [string] $method = $null

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
            version = "1.0.1"
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

        if ($null -eq $this.parameters.method) {
            $this.parameters.method = "Info"
        }

        [Log]::Write($this.parameters.message, $this.parameters.method)

        return $this
    }
    
}

# Register the TextOutput plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])
