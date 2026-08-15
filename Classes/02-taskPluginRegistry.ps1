class taskPluginRegistry {
    <#
    .SYNOPSIS
    Singleton class to handle registration of task handler plugins

    .DESCRIPTION
    This class is a singleton that manages the registration of task handler plugins.
    It ensures that only one instance of the class exists and provides methods to register, remove, and retrieve plugins.

    .NOTES
    This class is intended to be used as a singleton to manage task handler plugins.
    It provides methods to register plugins and maintain a registry of available plugin types.
    The registry maps field names to plugin types so that the task manager can locate and utilize the appropriate plugin for a given task.

    Plugins need to register themselves via the following:
    [taskPluginRegistry]::GetInstance().RegisterPlugin([myTaskPlugin])
    #>


    static [taskPluginRegistry] $Instance = $null  # Singleton object; Explicitly initialize to $null
    [System.Collections.Generic.Dictionary[string, [Type]]] $PluginRegistry  # List of registered plugins


    # Singleton handler
    static [taskPluginRegistry] GetInstance() {
        <#
        .SYNOPSIS
        Gets the singleton instance of the taskPluginRegistry class.

        .DESCRIPTION
        This static method returns the single instance of the taskPluginRegistry class, creating it if it does not already exist.
        It also ensures that the plugin registry dictionary is initialized.
        .#>
        if ($null -eq [taskPluginRegistry]::Instance) {
            [taskPluginRegistry]::Instance = [taskPluginRegistry]::new()
        }
        return [taskPluginRegistry]::Instance
    }


    taskPluginRegistry() {
        <#
        .SYNOPSIS
        Constructor for the taskPluginRegistry class.

        .DESCRIPTION
        Initializes the plugin registry dictionary for the singleton instance.

        .NOTES
        No way of enforcing `private` constructor in PowerShell, but this is intended to be used only via GetInstance().
        #>
        $this.PluginRegistry = [System.Collections.Generic.Dictionary[string, [Type]]]::new()
    }


    [void]RegisterPlugin([Type] $pluginType) {
        <#
        .SYNOPSIS
        Registers a new plugin type with the task manager.

        .DESCRIPTION
        This method registers a new plugin type with the task manager. The plugin type must implement the taskPluginInterface.

        .PARAMETER pluginType
        The type of the plugin to register. It must implement the taskPluginInterface.

        .EXAMPLE
        Call after your plugin to register it with the task manager:
        [taskPluginRegistry]::GetInstance().RegisterPlugin([myPlugin])
        #>

        # Ensure the type implements taskPluginInterface
        $plugin = [Activator]::CreateInstance($pluginType)
        if (-not ($plugin -is [taskPluginInterface])) {
                throw [ArgumentException]::New("The provided type does not implement taskPluginInterface.")
        }

        $pluginName = $plugin::PluginInfo().name

        # Fixes a module-load regression behind the public tests by making
        # plugin registry re-registration idempotent for the same plugin
        # type while still rejecting conflicting names
        if ($this.PluginRegistry.ContainsKey($pluginName)) {
            $existingType = $this.PluginRegistry[$pluginName]
            if ($existingType -eq $pluginType) {
                return
            }

            throw [ArgumentException]::New("A plugin with the same name is already registered.")
        }

        if($this.IsPluginValid($plugin)) {
            # Plugin is valid, continue with registration
            $this.PluginRegistry[$pluginName] = $pluginType
        } else {
            throw [ArgumentException]::New("Plugin is not valid and cannot be registered.")
        }
    }


    [System.Collections.Generic.List[string]]GetPluginValidationErrors([taskPluginInterface] $plugin, [bool] $throwOnError = $false) {
        <#
        .SYNOPSIS
        Gets validation errors for a plugin.

        .DESCRIPTION
        This method validates that a plugin has all required properties set. Currently verifies that a name is set and that a plugin with the same name doesn't already exist in the registry.

        .PARAMETER plugin
        The plugin instance to validate.

        .PARAMETER throwOnError
        If $true, throws an exception with the validation errors. If $false, returns an array of error messages.

        .EXAMPLE
        $errors = $this.GetPluginValidationErrors($plugin)
        $errors = $this.GetPluginValidationErrors($plugin, $true)
        #>

        $errors = [System.Collections.Generic.List[string]]::new()

        if ([string]::IsNullOrEmpty($plugin::PluginInfo().name)) {
            $errors.Add("Plugin name cannot be null or empty.")
        }

        # Validate that the plugin name doesn't already exist in the registry
        if ($this.PluginRegistry.ContainsKey($plugin::PluginInfo().name)) {
            $errors.Add("A plugin with the same name is already registered.")
        }

        if ($throwOnError -and $errors.Count -gt 0) {
            throw [ArgumentException]::New(($errors -join "; "))
        }

        return $errors
    }


    [bool]IsPluginValid([taskPluginInterface] $plugin) {
        <#
        .SYNOPSIS
        Determines whether a plugin is valid.

        .DESCRIPTION
        This method checks whether a plugin passes validation by retrieving any validation errors and returning a boolean indicating validity.

        .PARAMETER plugin
        The plugin instance to check.

        .EXAMPLE
        $isValid = $this.IsPluginValid($plugin)
        #>
        $errors = $this.GetPluginValidationErrors($plugin, $false)
        return $errors.Count -eq 0
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


    static [Object]GetPlugin([string] $pluginName){
        <#
        .SYNOPSIS
        Returns an instance of a plugin

        .PARAMETER pluginName
        The name of the plugin to retrieve

        .NOTES
        Returns a fresh plugin instance with default state.
        To set parameters, call SetParameters() on the returned instance.
        #>

        $me = [taskPluginRegistry]::GetInstance()

        if (-not $me.PluginRegistry.ContainsKey($pluginName)) {
            throw [ArgumentException]::New("Plugin '$pluginName' not found in registry.")
        }
        $plugin = [Activator]::CreateInstance($pluginName)
        return $plugin
    }

    static [Object]GetPluginWithParameters([string] $pluginName, [object] $parameters){
        <#
        .SYNOPSIS
        Returns an instance of a plugin with parameters pre-configured

        .PARAMETER pluginName
        The name of the plugin to retrieve

        .PARAMETER parameters
        The parameters to validate and set on the plugin instance

        .NOTES
        This is a convenience method that creates a plugin instance and immediately
        calls SetParameters() on it. This performs early parameter validation,
        allowing errors to be caught before the plugin is used.
        If validation fails, an exception is thrown and the plugin is not returned.
        #>

        $plugin = [taskPluginRegistry]::GetPlugin($pluginName)
        $plugin.SetParameters($parameters)
        return $plugin
    }


    static [array]GetPluginNames() {
        <#
        .SYNOPSIS
        Retrieves the names of all registered plugins.

        .DESCRIPTION
        This method returns an array of the names of all plugins currently
        registered in the plugin registry.

        .EXAMPLE
        $pluginNames = $this.GetPluginNames()
        #>

        $me = [taskPluginRegistry]::GetInstance()

        $pluginNames = @()
        $pluginNames += $me.PluginRegistry.Values | ForEach-Object { $_::PluginInfo().name }
        return $pluginNames
    }

}
