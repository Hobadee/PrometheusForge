class RegisterVariable : TaskPluginInterface {
    <#
    .SYNOPSIS
    Simple plugin for registering a variable so it's easier to access later
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
        <#
        .SYNOPSIS
        Validates and extracts the name/value parameters for the RegisterVariable plugin.

        .DESCRIPTION
        Requires:
        - name: A non-null, non-empty string identifying the Variables key to register.
        - value: The value to store under that key. Any type is accepted, including $null.
        #>

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
