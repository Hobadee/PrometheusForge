class sourcePluginFactory {

    static [sourcePluginInterface] GetPlugin([string] $name, [string] $uri) {
        <#
        .SYNOPSIS
        Constructs and returns a source plugin instance ready for loading.

        .DESCRIPTION
        Looks up the registered type for the given plugin name and instantiates it with the
        provided URI. The returned instance has passed URI validation but Load() has not yet
        been called.

        .PARAMETER name
        The registered name of the source plugin (e.g. 'yamlSource').

        .PARAMETER uri
        The URI or file path to pass to the plugin constructor.

        .OUTPUTS
        sourcePluginInterface

        .EXAMPLE
        $plugin = [sourcePluginFactory]::GetPlugin('yamlSource', './config.yaml')
        $config  = $plugin.Load()
        #>
        $registry = [sourcePluginRegistry]::GetInstance()

        if (-not $registry.IsRegistered($name)) {
            throw [System.ArgumentException]::new("Source plugin '$name' not found in registry.", 'name')
        }

        $pluginType = $registry.PluginRegistry[$name]

        # Unwrap reflection wrappers so callers see the original exception type.
        try {
            return [Activator]::CreateInstance($pluginType, [object[]]@($uri))
        } catch {
            $ex = $_.Exception
            while ($null -ne $ex.InnerException) { $ex = $ex.InnerException }
            throw $ex
        }
    }


    static [Type] GetPluginType([string] $name) {
        <#
        .SYNOPSIS
        Returns the registered [Type] for the named source plugin.

        .DESCRIPTION
        Retrieves the concrete type stored in the registry without constructing an instance.
        Useful when the caller needs to inspect plugin metadata or perform its own instantiation.

        .PARAMETER name
        The registered name of the source plugin (e.g. 'yamlSource').

        .OUTPUTS
        System.Type

        .EXAMPLE
        $type = [sourcePluginFactory]::GetPluginType('yamlSource')
        $info  = $type::PluginInfo()
        #>
        $registry = [sourcePluginRegistry]::GetInstance()

        if (-not $registry.IsRegistered($name)) {
            throw [System.ArgumentException]::new("Source plugin '$name' not found in registry.", 'name')
        }

        return $registry.PluginRegistry[$name]
    }
}
