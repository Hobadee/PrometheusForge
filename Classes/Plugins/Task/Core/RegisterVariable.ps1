class RegisterVariable : TaskPluginInterface {
    <#
    .SYNOPSIS
    Simple plugin for registering a variable so it's easier to access later.

    .PARAMETER name
    The variable name to register in the workflow variable store.

    .PARAMETER value
    The value to associate with that variable name; it may be a scalar, list, object, or $null.
    #>

    [string]$name = $null
    [object]$value = $null

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
        if ($null -ne $params.name -and $params.name -isnot [string]) {
            throw [System.ArgumentException]::new("Parameter 'name' must be a string")
        }
        if ([string]::IsNullOrEmpty($params.name)) {
            throw [System.ArgumentException]::new("Parameter 'name' is required and must be a non-empty string")
        }

        $this.name = $params.name
        $this.value = $params.value
    }


    [object] Execute() {
        <#
        .SYNOPSIS
        Registers a variable.

        .OUTPUTS
        A hashtable describing what was loaded/inserted, for debugging/result inspection.
        #>

        $variables = [Variables]::GetInstance()

        $variables.Set($this.name, $this.value)

        return @{
            name  = $this.name
            value = $this.value
        }
    }
}

# Register the RegisterVariable plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([RegisterVariable])
