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

        ### BEGIN UN-VETTED IMPORT CODE
        if ($null -eq $config) {
            throw [System.ArgumentNullException]::new("config", "Item configuration cannot be null.")
        }

        if ($config.type -eq "import") {
            if ([string]::IsNullOrWhiteSpace($config.sourcePlugin)) {
                throw [System.ArgumentException]::new("Import items must include a sourcePlugin value.", 'sourcePlugin')
            }

            $configuration = [Configuration]::GetInstance()
            $expandedUri = [TemplateEngine]::ExpandString([string]$config.uri, $configuration)

            if ([string]::IsNullOrWhiteSpace($config.uri)) {
                throw [System.ArgumentException]::new("Import items must include a uri value.", 'uri')
            }

            if ([string]::IsNullOrWhiteSpace($expandedUri)) {
                throw [System.ArgumentException]::new("Import items must include a uri value.", 'uri')
            }

            $plugin = [sourcePluginFactory]::GetPlugin($config.sourcePlugin, $expandedUri)
            $loadedConfig = $plugin.Load()

            $configuration.SetMany($loadedConfig.variables)

            $resolvedConfig = if ($null -ne $loadedConfig.root) { $loadedConfig.root } else { $loadedConfig }

            if ($resolvedConfig -is [System.Collections.IEnumerable] -and -not ($resolvedConfig -is [string]) -and -not ($resolvedConfig -is [System.Collections.IDictionary])) {
                $resolvedConfig = [pscustomobject]@{
                    name = if ($null -ne $config.name -and $config.name -is [string]) { $config.name } else { 'Imported section' }
                    type = 'section'
                    items = @($resolvedConfig)
                }
            }

            if ($resolvedConfig.type -eq 'step') {
                $wrappedSection = [pscustomobject]@{
                    name = if ($null -ne $resolvedConfig.name -and $resolvedConfig.name -is [string]) { $resolvedConfig.name } else { 'Imported section' }
                    type = 'section'
                    items = @($resolvedConfig)
                }
                Write-Debug "Wrapping imported step config '$($wrappedSection.name)' in a synthetic section item."
                return [ItemSection]::new($wrappedSection)
            }

            if ($resolvedConfig.type -eq 'section') {
                Write-Debug "Creating imported ItemSection for config: $($resolvedConfig.name)"
                return [ItemSection]::new($resolvedConfig)
            }

            throw [System.ArgumentException]::new("Imported item type '$($resolvedConfig.type)' is not supported.", 'config')
        }

        ### END UN-VETTED IMPORT CODE
        
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
