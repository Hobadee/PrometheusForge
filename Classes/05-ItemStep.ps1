class ItemStep : ItemInterface {
    <#
    .SYNOPSIS
        Represents one executable checklist step backed by a task plugin.

    .DESCRIPTION
        ItemStep is the concrete runtime implementation for YAML nodes with type "step".
        During construction it validates step metadata, resolves a plugin from taskPluginRegistry,
        and forwards step parameters to the plugin for plugin-specific validation.

        During execution (Process), ItemStep invokes the plugin, applies retry logic, optionally
        stores the execution result in shared configuration state, and enforces error behavior
        controlled by onError.

        This class is typically created by ItemFactory and executed by a parent ItemSection.

        .INPUTS
        A configuration object (usually deserialized from YAML) containing at minimum:
        - name       : string
        - type       : "step"
        - plugin     : string (registered plugin name)
        - parameters : object (plugin-specific parameters)

        Optional execution keys:
        - retry.retries : int (attempt count, default 3)
        - retry.delay   : int (seconds between retries, default 1)
        - onError       : string ("fail" or "abort", default "fail")
        - result        : string (configuration key to store execution result)

        .OUTPUTS
        System.Boolean from Process indicating whether plugin execution succeeded.

    .NOTES
        The parameters object is intentionally removed from this.config after constructor validation
        because parameter state is owned by the plugin instance.

        onError behavior:
        - fail  : returns $false when all retries fail
        - abort : throws an exception when all retries fail

        Plugin exceptions thrown during RunTask are captured as an error payload unless onError=abort.

        .EXAMPLE
        YAML step mapped to ItemStep:
        name: Generate Password
        type: step
        plugin: PasswordGenerator
        parameters:
            length: 20
            includeSpecial: true
        retry:
            retries: 3
            delay: 2
        onError: fail
        result: generated.password
    #>

    <#
    .SYNOPSIS
    Gets the plugin instance associated with this step.

    .DESCRIPTION
    The plugin is resolved from taskPluginRegistry using config.plugin and initialized by
    calling SetParameters(config.parameters) during construction.
    This property is expected to implement TaskPluginInterface.
    #>
    [TaskPluginInterface]$plugin = $null

    <#
    .SYNOPSIS
    Gets the normalized step configuration used during execution.

    .DESCRIPTION
    Stores execution-related step settings after constructor normalization.
    The original parameters node is removed once applied to the plugin.
    Typical fields consumed by Process are retry, onError, result, and name.
    #>
    [object]$config = $null


    ItemStep([object]$config) : base($config){
        <#
        .SYNOPSIS
        Initializes a new ItemStep from a step configuration object.

        .DESCRIPTION
        Performs the following setup steps:
        1. Validates required step keys (plugin and parameters).
        2. Resolves plugin instance from taskPluginRegistry.
        3. Calls plugin.SetParameters(...) to trigger plugin-specific validation.
        4. Removes parameters from local config to avoid duplicate storage.
        5. Stores normalized config for runtime execution.

        Validation and plugin binding happen at construction time so configuration problems
        are raised early instead of during checklist execution.

        .PARAMETER config
        Step configuration object. Required keys:
        - plugin     : non-empty string
        - parameters : object passed to plugin.SetParameters

        Recommended keys:
        - name        : step display name used in error text
        - retry       : object with retries and delay values
        - onError     : "fail" or "abort"
        - result      : configuration key for storing execution result

        .NOTES
        If plugin.SetParameters throws, the constructor wraps that error with step and plugin context.
        #>
        if (-not ($config.plugin -and $config.plugin -is [string])) {
            throw [System.ArgumentException]::new("Step $($config.name) must include a plugin name") 
        }

        # We don't actually *REQUIRE* parameters - plugins *MAY* have no parameters.  (Although it is probably rare.)  So we will just warn if they are missing, but not throw an exception.
        if (-not ($config.parameters -and $config.parameters -is [object])){
            Write-Error "Step $($config.name) does not include plugin parameters.  This may be valid if the plugin does not require parameters, but it is unusual."
            #throw [System.ArgumentException]::new("Step $($config.name) must include plugin parameters") 
        }

        $this.plugin = [taskPluginRegistry]::GetPlugin($config.plugin)

        # Set parameters on the plugin instance (this triggers validation)
        if ($null -ne $this.plugin) {
            try{
                $this.plugin.SetParameters($config.parameters)
            }
            catch{
                $err = $_
                throw [System.Exception]::new("Step: $($config.name) - Failed to set parameters for plugin $($config.plugin): $err")
            }
        }

        # Parameters are now stored in the plugin, so we remove them from the config to reduce memory bloat
        $config.Remove("parameters")
        
        $this.config = $config
    }


    [object] Process(){
        <#
        .SYNOPSIS
        Executes the step plugin with retry and error handling.

        .DESCRIPTION
        Invokes plugin.RunTask() until success or retry exhaustion.

        Execution flow:
        1. Initialize defaults: retries=3, delay=1, onError="fail".
        2. Override retries/delay from config.retry when values are ints.
        3. Attempt RunTask(), capturing thrown exceptions as failed results.
        4. Sleep delay seconds between failed attempts.
        5. On final failure, apply onError policy:
           - abort: throw exception
           - fail : return $false
        6. If config.result is set, store full result object in Configuration singleton.

        .OUTPUTS
        System.Boolean
        - $true  when RunTask ultimately reports success
        - $false when all attempts fail and onError is "fail"

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

        # Set defaults
        $retries = 3
        $delay = 1
        $onError = "fail"

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

        # Attempt to run
        while(-not $res.success -and $i -lt $retries){
            try{
                $res = $this.plugin.RunTask()
            }
            catch {
                $res = @{success = $false; error = $_}
            }

            $i++

            if($res.success -or $i -ge $retries){
                # Even though the while loop will break us anyways,
                # break before the sleep to save time
                # Keep the check in the while loop to prevent accidental locking with
                # something like a while(1)
                break
            }
            Start-Sleep -Seconds $delay
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


        # Check if we need to store the result
        if ($this.config.result -and $this.config.result -is [string]){
            # Store the result
            $configuration = [Configuration]::GetInstance()
            $configuration.Set($this.config.result, $res)
        }

        return $res.success
    }

}
