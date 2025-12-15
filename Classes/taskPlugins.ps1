class taskPlugins {
    <#
    .SYNOPSIS
    Singleton class to handle registration of task handler plugins

    .DESCRIPTION
    This class is a singleton that manages the registration of task handler plugins. It ensures that only one instance of the class exists and provides methods to register, remove, and retrieve plugins.
    #>


    static [taskPlugins] $Instance = $null  # Singleton object; Explicitly initialize to $null
    static [System.Collections.Generic.List[taskPluginInterface]] $Plugins = $null  # List of registered plugins; Explicitly initialize to $null

    static [taskPlugins] GetInstance() {
        if ($null -eq [taskPlugins]::Instance) {
            [taskPlugins]::Instance = [taskPlugins]::new()
        }
        return [taskPlugins]::Instance
    }


    [void]RegisterPlugin([Type] $pluginType) {
        <#
        .SYNOPSIS
        Registers a new plugin type with the task manager.

        .DESCRIPTION
        This method registers a new plugin type with the task manager. The plugin type must implement the taskPlugins interface.

        .PARAMETER pluginType
        The type of the plugin to register. It must implement the taskPlugins interface.

        .EXAMPLE
        Call after your plugin to register it with the task manager:
        [taskPlugins]::GetInstance().RegisterPlugin([myPlugin])
        #>

        # Ensure the type implements taskPlugins
        $plugin = [Activator]::CreateInstance($pluginType)
        if (-not ($plugin -is [taskPlugins])) {
                throw [ArgumentException]::New("The provided type does not implement taskPlugins.")
        }

        # Add each field name to the registry, mapping it to the plugin type
        foreach ($field in $pluginType::fieldNames()) {
            $this.PluginRegistry[$field] = $pluginType
        }
    }





    # constructor() {
    #     this.plugins = [];
    # }

    # addPlugin(plugin) {
    #     this.plugins.push(plugin);
    # }

    # removePlugin(pluginName) {
    #     this.plugins = this.plugins.filter(plugin => plugin.name !== pluginName);
    # }

    # getPlugin(pluginName) {
    #     return this.plugins.find(plugin => plugin.name === pluginName);
    # }

    # getPlugins() {
    #     return this.plugins;
    # }
}
