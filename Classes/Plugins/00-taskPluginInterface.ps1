class TaskPluginInterface {
    <#
    .SYNOPSIS
    Interface class for task plugins

    .DESCRIPTION
    This class defines the interface that all task plugins must implement.
    It provides abstract methods for parameter validation and execution.
    Derived plugins must implement these methods to be compatible with the task management system.

    EXECUTION MODEL:
    - Each task receives a fresh plugin instance (per-task instantiation pattern).
    - This prevents cross-contamination between tasks and ensures a clean state for each execution.
    - Plugins needing shared resources (database connections, caches, etc.) can implement a singleton pattern internally.
    
    PARAMETER FLOW:
    1. Plugin instance is created via [taskPluginRegistry]::GetPlugin($name)
    2. Parameters are set via SetParameters($params) — this triggers ValidateParameters()
    3. Validation happens early (fail-fast): errors are caught during setup, not during execution
    4. Execute() is called with no arguments; it uses stored parameters in $this.parameters
    5. RunTask() orchestrates this: calls Execute(), handles errors, captures timing metadata

    .NOTES
    This is technically an abstract class rather than a true interface, but we use it to
    define the contract that all task plugins must follow.
    #>


    # Instance state
    [object] $parameters = $null


    TaskPluginInterface() {
        <#
        .SYNOPSIS
        Constructor for the TaskPluginInterface class.

        .DESCRIPTION
        Initializes a new instance of the TaskPluginInterface class.
        Optionally derived classes can pass parameters to initialize upfront.
        #>
    }
    TaskPluginInterface([object]$initialParameters) {
        <#
        .SYNOPSIS
        Constructor for the TaskPluginInterface class with initial parameters.

        .DESCRIPTION
        Initializes a new instance of the TaskPluginInterface class and sets the initial parameters.
        This triggers parameter validation via SetParameters().

        .PARAMETER initialParameters
        The initial parameters object to set and validate.
        #>
        $this.SetParameters($initialParameters)
    }


    #
    # Public Methods for Parameter Management
    #
    [void] SetParameters([object]$params) {
        <#
        .SYNOPSIS
        Sets and validates execution parameters for the plugin.

        .DESCRIPTION
        This method validates the provided parameters using the abstract ValidateParameters method,
        then stores them for use during execution. Validation happens upfront (fail-fast model):
        errors are caught during parameter setup, not during task execution.

        .PARAMETER params
        The parameters object to set and validate. This is typically a JSON object parsed from YAML.

        .NOTES
        Derived plugins must implement ValidateParameters() to perform plugin-specific validation.
        This method is called automatically if parameters are passed to the constructor.
        #>
        $this.ValidateParameters($params)
        $this.parameters = $params
    }


    #
    # Abstract/Virtual Methods (Derived classes must implement)
    #
    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates execution parameters for the plugin.

        .DESCRIPTION
        This abstract method must be implemented by derived plugin classes to validate
        parameters specific to their execution model. Validation happens during SetParameters(),
        allowing errors to be caught early (fail-fast).

        Derived classes should:
        - Check for required parameters
        - Validate parameter types
        - Check parameter constraints
        - Throw descriptive exceptions if validation fails

        .PARAMETER params
        The parameters object to validate.

        .NOTES
        This method is called by SetParameters() before parameters are stored.
        #>
        throw [System.NotImplementedException]::new("ValidateParameters method must be implemented by derived plugin")
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Executes a task using the plugin.

        .DESCRIPTION
        This abstract method must be implemented by derived plugin classes to perform the work
        associated with a task. The method should use the stored $this.parameters instance variable
        to access execution parameters.

        .NOTES
        Derived plugins must implement this method to provide task execution functionality.
        Parameters should NOT be passed to this method; use $this.parameters instead.
        If parameters are not set before Execute() is called, this method should throw an appropriate error.
        #>
        throw [System.NotImplementedException]::new("Execute method must be implemented by derived plugin")
    }


    [object] RunTask() {
        <#
        .SYNOPSIS
        Executes the task and returns execution metadata.

        .DESCRIPTION
        This method orchestrates task execution by calling Execute() and capturing
        execution metadata (success status, errors, timing). This is a concrete method
        that should be called instead of Execute() directly.

        .OUTPUTS
        A hashtable containing:
        - Success: Boolean indicating if execution succeeded
        - object: The return value from Execute() (if successful)
        - error: The exception that was thrown (if failed)
        - startTime: DateTime when execution started
        - endTime: DateTime when execution ended
        - executionTime: Execution duration in seconds

        .NOTES
        Internal framework code should call this method, not Execute() directly.
        Parameters must be set via SetParameters() before calling this method.
        #>

        # Variable Setup
        $error = $null

        # Pre-flight Checks
        if ($null -eq $this.parameters) {
            throw [System.InvalidOperationException]::new("Parameters must be set via SetParameters() before calling Execute()")
        }
        
        # Execute
        $startTime = [datetime]::Now
        try {
            $rtn = $this.Execute()
            $success = $true
        }
        catch {
            $error = $_
            $success = $false
            $rtn = $null
        }
        $endTime = [datetime]::Now

        # Build result and return
        $result = @{
            success = $success
            object = $rtn
            error = $error
            startTime = $startTime
            endTime = $endTime
            executionTime = ($endTime - $startTime).TotalSeconds
        }

        return $result
    }


    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Returns metadata about the plugin, including its name and version.

        .DESCRIPTION
        This static method provides information about the plugin. It must be implemented
        by derived plugin classes to return a hashtable containing at least the Name and Version.

        .OUTPUTS
        A hashtable with the following required keys:
        - Name: Globally unique plugin name (string)
        - Version: Plugin version (string)

        The following are recommended keys:
        - Description: A brief description of the plugin (string)
        - Author: The author of the plugin (string)
        - License: The license under which the plugin is distributed (string)
        #>
        throw [System.NotImplementedException]::new("PluginInfo method must be implemented by derived plugin")
    }

}
