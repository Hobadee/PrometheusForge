class ItemFactory {

    static [ItemInterface] Create([object]$config){
        <#
        .Synopsis
        Creates an instance of an ItemInterface implementation based on the configuration object.

        .Description
        This method inspects the 'type' property of the configuration object and returns an instance of the
        appropriate class (ItemStep or ItemSection). If the type is unknown, it throws an exception.

        .PARAMETER config
        The configuration object that contains the 'type' property used to determine which ItemInterface implementation to create.

        .OUTPUTS
        An instance of an ItemInterface implementation (ItemStep or ItemSection) based on the 'type' property of the configuration object.
        #>
        if ([string]::IsNullOrWhiteSpace($config.type)) {
            throw [System.ArgumentException]::new("Item type is missing in the configuration object.")
        }

        if ($config.type -eq "step") {
            Write-Debug "Creating ItemStep for config: $($config.name)"
            return [ItemStep]::new($config)
        }
        elseif ($config.type -eq "section") {
            Write-Debug "Creating ItemSection for config: $($config.name)"
            return [ItemSection]::new($config)
        }
        throw [System.ArgumentException]::new("Unknown item type: $($config.type)")
    }
}
