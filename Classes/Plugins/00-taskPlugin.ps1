class TaskPluginInterface {
    # Abstract method: Initialize the plugin
    # Parameters: Config object and optional settings
    [void] Initialize([object]$config) {
        throw [System.NotImplementedException]::new("Initialize method must be implemented by derived plugin")
    }

    # Abstract method: Execute a task
    # Parameters: Task object and context (Run, Engine)
    [object] Execute([object]$task, [hashtable]$context) {
        throw [System.NotImplementedException]::new("Execute method must be implemented by derived plugin")
    }

    # Abstract method: Validate plugin configuration
    # Returns: $true if valid, $false otherwise
    [bool] Validate() {
        throw [System.NotImplementedException]::new("Validate method must be implemented by derived plugin")
    }

    # Abstract property: Plugin name
    [string] get_Name() {
        throw [System.NotImplementedException]::new("Name property must be implemented by derived plugin")
    }
}
