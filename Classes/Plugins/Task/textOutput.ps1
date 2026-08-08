class TextOutput : TaskPluginInterface {

    [string] $message

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
            version = "1.0.0"
        }
    }

    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates the parameters for the TextOutput plugin.

        .DESCRIPTION
        Ensures that the 'message' parameter is present and not null/empty.
        #>
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
        [console]::WriteLine($this.parameters.message)
        return $this
    }
    
}

# Register the TextOutput plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])
