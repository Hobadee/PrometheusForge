class Step{
    <#
    .SYNOPSIS
    Represents a single step in the process
    #>

    # Default Values
    $default_retries = 3
    $default_delay = 1
    $default_onError = "fail"

    [string] $name = $null
    [taskPluginInterface] $plugin = $null
    [object] $config = $null
    [object] $result = $null


    Step([object]$config) {
        <#
        .SYNOPSIS
        Initializes a new instance of the Step class
        #>
        
        #Write-Debug "[Step]::new() Creating Step: $($config.name)"
        if (-not ($config.name -and $config.name -is [string])) {
            [Log]::Debug("[Step]::new() Failed attempt to create a Step with an invalid name: $($config.name)")
            throw [System.ArgumentException]::new("Every step must contain a name") 
        }

        $this.name = $config.name
        $this.config = $config

        # Note: DO NOT check for plugin name here - that may be deferred until
        # execution time.  We will check for plugin name and parameters in
        # InitializePlugin().

        # We don't actually *REQUIRE* parameters - plugins *MAY* have no parameters.  (Although it is probably rare.)  So we will just warn if they are missing, but not throw an exception.
        if (-not ($this.config.parameters -and $this.config.parameters -is [object])){
            [Log]::Warning("[Step]::new() Step $($this.config.name) does not include plugin parameters.  This may be valid if the plugin does not require parameters, but it is unusual.")
        }

        if($true -ne $this.config.defer_binding){
            $this.InitializePlugin()
        }
        else {
            [Log]::Verbose("Step $($this.name) is configured for late binding. Plugin will be resolved at execution time.")
        }
    }


    [bool] IsProcessed(){
        <#
        .SYNOPSIS
        Checks if the step has been processed
        
        .OUTPUTS
        System.Boolean
        - $true  if the step has been processed
        - $false if the step has not been processed
        #>
        return $null -ne $this.result
    }


    [void] InitializePlugin(){
        <#
        .SYNOPSIS
        Initializes the plugin for the step

        .DESCRIPTION
        Initializing the plugin in it's own method makes it simple to setup
        deferred binding, as we simply don't initialize until right before
        Process().
        
        .PARAMETER plugin
        The plugin to set for the step. Must implement taskPluginInterface.
        
        .NOTES
        This method is used to associate a plugin with the step. The plugin is responsible for executing the task associated with the step.
        #>

        if (-not ($this.config.plugin -and $this.config.plugin -is [string])) {
            throw [System.ArgumentException]::new("Step $($this.config.name) must include a plugin name") 
        }

        $configuration = [Variables]::GetInstance()

        # Template out the entire plugin name because why the hell not?
        try{
            # Run parameters through the template engine to expand any top-level string values before passing to the plugin
            $this.config.plugin = [TemplateEngine]::ExpandTopLevelValues($this.config.plugin, $configuration)
        }
        catch{
            $err = $_
            throw [System.Exception]::new("Step: $($this.name) - Failed to set plugin name $($this.config.plugin): $err")
        }

        # Throws if the plugin is not found in the registry
        $this.plugin = [taskPluginRegistry]::GetPlugin($this.config.plugin)

        # Set parameters on the plugin instance (this triggers validation)
        if ($null -ne $this.plugin) {
            try{
                # Run parameters through the template engine to expand any top-level string values before passing to the plugin
                $expandedParameters = [TemplateEngine]::ExpandTopLevelValues($this.config.parameters, $configuration)
                $this.plugin.SetParameters($expandedParameters)
            }
            catch{
                $err = $_
                throw [System.Exception]::new("Step: $($this.name) - Failed to set parameters for plugin $($this.config.plugin): $err")
            }
        }

        #Write-Debug "[Step]::InitializePlugin() - $($this.name) - Plugin initialized"
        
        # Parameters are now stored in the plugin
        # We could remove them from the config to reduce memory bloat, but
        # keeping them lets us compare original pre-expanded parameters with
        # the plugin's internal state for debugging and validation purposes.
        #$this.config.Remove("parameters")

    }

    
    [object] Process(){
        <#
        .SYNOPSIS
        Executes the step plugin with retry and error handling.

        .DESCRIPTION
        Invokes plugin.RunTask() until success or retry exhaustion.

        Execution flow:
        1. NOT MVP - Check conditionals - if any are false, skip execution and return $true.
        2. Initialize defaults: retries=3, delay=1, onError="fail".
        3. Override retries/delay from config.retry when values are ints.
        4. Attempt RunTask(), capturing thrown exceptions as failed results.
        5. Sleep delay seconds between failed attempts.
        6. On final failure, apply onError policy:
           - abort: throw exception
           - fail : return $false
        7. If config.result is set, store full result object in Variables singleton.

        .OUTPUTS
        System.Object
        - Returns $true (as object) when RunTask ultimately reports success
        - Returns $false (as object) when all attempts fail and onError is "fail"

        .NOTES
        RunTask is expected to return an object/hashtable containing at least a success field.
        When RunTask throws, Process captures the exception and treats it as a failed attempt.

        .EXAMPLE
        Example behavior when retries are configured:
        - retry.retries = 5
        - retry.delay = 2

        Process attempts up to 5 executions, waiting 2 seconds between failed attempts,
        then either throws (onError=abort) or returns $false (onError=fail).
        #>

        # Check if we need to initialize the plugin for late binding
        if($null -eq $this.plugin) {
            [Log]::Debug("[Step]::Process() - $($this.name) is configured for late binding. Initializing plugin now.")
            $this.InitializePlugin()
        }

        # Set defaults
        $retries = $this.default_retries
        $delay = $this.default_delay
        $onError = $this.default_onError

        # Init variables we need
        $res = @{success = $false}
        $i = 0

        # Check if we have retries configured
        if ($this.config.retry -and $this.config.retry.retries -is [int]){
            $retries = $this.config.retry.retries
        }
        if ($this.config.retry -and $this.config.retry.delay -is [int]){
            $delay = $this.config.retry.delay
        }
        
        <#############################################################################
        # UNVERIFIED: The following code is unverified and may not work as intended. #
        #############################################################################>

        # Attempt to run
        while(-not $res.success -and $i -lt $retries){
            try{
                $res = $this.plugin.RunTask()
            }
            catch {
                # This should only trigger if plugin pre-flight checks fail
                # Plugin exceptions will be caught in $res
                $res = @{success = $false; error = $_}
            }

            # If we did not succeed or run out of retries, sleep before the
            # next attempt
            if(-not ($res.success -or $i -ge $retries)){
                Start-Sleep -Seconds $delay
            }

            $i++
        }

        # We ran and failed
        if (-not $res.success){
            # Handle failure
            # Check failure mode; abort/fail and handle
            if ($this.config.onError -and $this.config.onError -is [string]){
                $onError = $this.config.onError
            }
            if ($onError -eq "abort"){
                throw [System.Exception]::new("$($this.config.name) failed after $i attempts with result: $($res.error | Out-String)")
            }
            if ($onError -eq "fail"){
                # Don't throw an exception; just allow the failure to be recorded and continue
            }
        }


        # Check if we need to register the result
        if ($this.config.result -and $this.config.result -is [string]){
            # Store the result
            $configuration = [Variables]::GetInstance()
            $configuration.Set($this.config.result, $res)
        }

        $this.result = $res

        #Write-Debug "[Step]::Process() - $($this.name) - Result: $($res | Out-String)"

        return $res.success
    }



}
