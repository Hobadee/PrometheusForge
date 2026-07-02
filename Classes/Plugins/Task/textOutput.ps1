class textOutput : TaskPluginInterface {

    textOutput() : base(){
        <#
        .SYNOPSIS
        Constructor for the textOutput plugin class

        .DESCRIPTION
        This constructor initializes the textOutput plugin by calling the base class constructor.
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
            name = "textOutput"
            version = "1.0.0"
        }
    }


    [textOutput] Execute([object]$parameters) {
        <#
        .SYNOPSIS
        Executes the textOutput plugin functionality.

        .DESCRIPTION
        This method contains the logic that the textOutput plugin performs
        when invoked by the task management system. Implement the necessary
        behavior for the plugin here.
        #>
        $str = $parameters.message
        [console]::WriteLine($str)
        return $this
    }
    
}

# Register the textOutput plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([textOutput])
