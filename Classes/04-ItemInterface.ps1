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
    

    [bool] DoItem(){
        throw [System.NotImplementedException]::new("DoItem method must be implemented by derived class")
    }
}
