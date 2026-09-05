class ForgeVariableApi {
    <#
    .SYNOPSIS
    Curated read/write access to workflow Variables for plugins.

    .DESCRIPTION
    Wraps the Variables singleton so plugins interact with a stable, purpose-built
    surface instead of the internal Variables class directly.
    #>

    hidden [Variables] $variables

    ForgeVariableApi() {
        <#
        .SYNOPSIS
        Constructor for the ForgeVariableApi class.

        .DESCRIPTION
        Pulls the Variables singleton internally, matching how other classes in this
        codebase (Variables, Steps, taskPluginRegistry) access their own singletons.
        #>
        $this.variables = [Variables]::GetInstance()
    }

    [object] Get([string] $key) {
        <#
        .SYNOPSIS
        Gets a Variables value by key.
        #>
        return $this.variables.Get($key)
    }

    [void] Set([string] $key, [object] $value) {
        <#
        .SYNOPSIS
        Sets a Variables key/value pair.
        #>
        $this.variables.Set($key, $value)
    }

    [bool] HasKey([string] $key) {
        <#
        .SYNOPSIS
        Checks whether a Variables key exists.
        #>
        return $this.variables.HasKey($key)
    }

    [void] SetMany([object] $entries) {
        <#
        .SYNOPSIS
        Sets multiple Variables key/value pairs in one operation.
        #>
        $this.variables.SetMany($entries)
    }
}
