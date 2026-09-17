class CurrentTime : TaskPluginInterface {
    <#
    .SYNOPSIS
    Simple plugin for retrieving the current date and time.

    .NOTES
    A better template system should be able to insert basic varaible such as current date/time
    making this obsolete.  We are not there yet.
    #>

    CurrentTime() : base(){
        <#
        .SYNOPSIS
        Constructor for the CurrentTime plugin class
        #>
    }


    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "CurrentTime"
            version = "1.0.0"
        }
    }


    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Currently no parameters are required for the CurrentTime plugin.

        .DESCRIPTION
        Requires: None.
        #>
        # No validation needed as there are no parameters required for the CurrentTime plugin.
    }


    [object] Execute() {
        <#
        .SYNOPSIS
        Returns the current date and time.

        .OUTPUTS
        A hashtable describing what was loaded/inserted, for debugging/result inspection.
        #>

        return [datetime]::Now

        # return @{
        #     currentTime = [datetime]::Now
        # }
    }
}

# Register the CurrentTime plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([CurrentTime])
