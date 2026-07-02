class TaskPluginInterface {
    <#
    .SYNOPSIS
    Interface class for task plugins

    .DESCRIPTION
    This class defines the interface that all task plugins must implement.
    It provides abstract methods for initialization, execution, and validation, as well as a property for the plugin name.
    Derived plugins must implement these methods and property to be compatible with the task management system.

    .NOTES
    Okay, this is technically an abstract class rather than a true interface, but we are
    using it as an interface to define the contract that all task plugins must follow.
    #>


    #
    # Class Constructors
    #
    TaskPluginInterface() {
        # Constructor for the TaskPluginInterface class
        # Derived classes may implement their own constructor as needed
    }


    # We may need an "Initialize" method in the future, but for now it's an unnecessary complication
    # [void] Initialize([object]$config) {
    #     <#
    #     .SYNOPSIS
    #     Initializes the plugin with the provided configuration.

    #     .DESCRIPTION
    #     This method is intended to be implemented by derived plugin classes
    #     to perform any necessary setup using the provided configuration object.

    #     .PARAMETER config
    #     The configuration object containing initialization parameters for the plugin.

    #     .NOTES
    #     This method DOES NOT need to be implemented if the plugin does not require any initialization.
    #     #>
    #     throw [System.NotImplementedException]::new("Initialize method must be implemented by derived plugin")
    # }


    [object] Execute([object]$parameters) {
        <#
        .SYNOPSIS
        Executes a task using the plugin.

        .DESCRIPTION
        This method is intended to be implemented by derived plugin classes
        to perform the work associated with a task. The method receives
        a single JSON object containing all execution data.

        .PARAMETER executionData
        An object containing all execution data including task details and any other relevant information needed for task execution.
        This will be a subset of the YAML data used to drive task execution, as parsed by `ConvertFrom-Yaml`.

        .NOTES
        Derived plugins must implement this method to provide task execution functionality.
        #>
        throw [System.NotImplementedException]::new("Execute method must be implemented by derived plugin")
    }


    [object] RunTask([object]$parameters) {
        <#
        .SYNOPSIS
        Runs a task using the plugin after validating execution data.

        .DESCRIPTION
        This method first validates the provided execution data using
        the ValidateExecutionData method. If the data is invalid,
        an exception is thrown. Otherwise, the method proceeds to
        execute the task by calling the Execute method.

        .PARAMETER executionData
        A JSON object containing all execution data including task details and any other relevant information needed for task execution.

        .OUTPUTS
        An object containing the result of the task execution, including success status, any returned object, error information, and timing metadata.

        .NOTES
        This is a concrete method!  We want to always ensure that execution data
        is validated before attempting to execute a task, this concrete method ensures
        derived plugins do not have to repeat this validation logic.

        Possible TODOs:
        - Accept additional arguments for task execution beyond the executionData JSON object (such as error handling/retries)
        #>
        if (-not $this.ValidateExecutionData($parameters)) {
            throw [System.ArgumentException]::new("Invalid execution data")
        }


        $error = $null
        $startTime = [datetime]::Now
        try {
            $rtn = $this.Execute($parameters)
            $success = $true
        }
        catch {
            $error = $_
            $success = $false
            $rtn = $null
        }
        $endTime = [datetime]::Now

        $result = @{
            Success = $success
            object = $rtn
            error = $error
            startTime = $startTime
            endTime = $endTime
            executionTime = ($endTime - $startTime).TotalSeconds
        }

        return $result
    }


    [bool] ValidateExecutionData([object]$parameters) {
        <#
        .SYNOPSIS
        Validates the execution data for the plugin.

        .DESCRIPTION
        This method verifies that the provided execution data is valid JSON.
        Derived plugin classes may override this method to perform additional validation
        specific to their requirements.

        .PARAMETER executionData
        A JSON object containing all execution data including task details and any other relevant information needed for task execution.

        .NOTES
        This base implementation checks that executionData is valid JSON.
        Derived plugins may extend this method to add custom validation logic.
        #>
        if ($null -eq $parameters) {
            return $false
        }

        try {
            $parameters | ConvertFrom-Json -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }


    # Abstract method: Get plugin information
    # Returns: A hashtable containing plugin metadata such as name and version
        <#
        Current Hashtable specification requires at least the following fields:
        Name = "Globally unique plugin name (string)"
        Version = "Plugin version (string)"
        #>
    static [hashtable] PluginInfo() {
        throw [System.NotImplementedException]::new("PluginInfo method must be implemented by derived plugin")
    }

}
