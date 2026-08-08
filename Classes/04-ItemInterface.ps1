class ItemInterface {
    # - type: section
    #   name: Documentation


    [string] $name = $null


    ItemInterface([object]$config) {
        <#
        .SYNOPSIS
        Constructor for the ItemInterface class

        .PARAMETER config
        The node configuration
        #>
        
        if (-not ($config.name -and $config.name -is [string])) {
            throw [System.ArgumentException]::new("Every item must contain a name") 
        }

        $this.name = $config.name
        # Derived classes may implement their own constructor as needed
    }
    

    # Process returns [object] instead of [bool] because PowerShell class method
    # dispatch was throwing InvalidCastException when a Boolean return was
    # produced through a typed call site. Implementations still return Boolean
    # values at runtime, but the broader return type avoids the binder mismatch.
    [object] Process(){
        throw [System.NotImplementedException]::new("Process method must be implemented by derived class")
    }
}
