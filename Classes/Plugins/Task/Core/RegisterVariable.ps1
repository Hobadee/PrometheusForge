class RegisterVariable : TaskPluginInterface {
    <#
    .SYNOPSIS
    Simple plugin for registering a variable so it's easier to access later
    #>

    RegisterVariable() : base(){
        <#
        .SYNOPSIS
        Constructor for the RegisterVariable plugin class
        #>
    }


    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "RegisterVariable"
            version = "1.0.0"
        }
    }


    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Currently no parameters are required for the RegisterVariable plugin.

        .DESCRIPTION
        Requires: None.
        #>
        # No validation needed as there are no parameters required for the RegisterVariable plugin.

        throw [System.NotImplementedException]::new("RegisterVariable plugin is not implemented yet.")
    }


    [object] Execute() {
        <#
        .SYNOPSIS
        Registers a variable.

        .OUTPUTS
        A hashtable describing what was loaded/inserted, for debugging/result inspection.
        #>

        $variables = [Variables]::GetInstance()

        $params = @{$this.var = $this.val}

        $variables.Register($params)

        return $true
    }
}

# Register the RegisterVariable plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([RegisterVariable])
