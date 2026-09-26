class sourcePluginRegistry {

    static [sourcePluginRegistry] $Instance = $null
    [System.Collections.Generic.Dictionary[string, [Type]]] $PluginRegistry


    # Hidden constructor to enforce singleton pattern
    hidden sourcePluginRegistry() {
        $this.PluginRegistry = [System.Collections.Generic.Dictionary[string, [Type]]]::new()
    }


    static [sourcePluginRegistry] GetInstance() {
        if ($null -eq [sourcePluginRegistry]::Instance) {
            [sourcePluginRegistry]::Instance = [sourcePluginRegistry]::new()
        }
        return [sourcePluginRegistry]::Instance
    }


    [void] RegisterPlugin([Type] $pluginType) {
        if ($null -eq $pluginType) {
            throw [System.ArgumentNullException]::new('pluginType', 'Plugin type cannot be null.')
        }

        if (-not $pluginType.IsSubclassOf([sourcePluginInterface])) {
            throw [System.ArgumentException]::new(
                "The provided type '$($pluginType.Name)' does not extend sourcePluginInterface.",
                'pluginType'
            )
        }

        $info = $pluginType::PluginInfo()

        if ([string]::IsNullOrEmpty($info.Name)) {
            throw [System.ArgumentException]::new('Plugin name returned by PluginInfo() cannot be null or empty.')
        }

        if ($this.PluginRegistry.ContainsKey($info.Name)) {
            
            # Fixes a module-load regression behind the public tests by making
            # plugin registry re-registration idempotent for the same plugin
            # type while still rejecting conflicting names
            $existingType = $this.PluginRegistry[$info.Name]
            if ($existingType -eq $pluginType) {
                return
            }

            throw [System.ArgumentException]::new("A source plugin named '$($info.Name)' is already registered.")
        }

        $this.PluginRegistry[$info.Name] = $pluginType
    }


    [bool] IsRegistered([string] $name) {
        return $this.PluginRegistry.ContainsKey($name)
    }


}
