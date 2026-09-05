class Steps {

    static [Steps] $Instance = $null # Singleton instance

    [System.Collections.Generic.Dictionary[string, [Step]]] $Steps  # List of steps


    Steps() {
        <#
        .SYNOPSIS
        Initializes the Steps collection
        #>
        $this.Steps = [System.Collections.Generic.Dictionary[string, [Step]]]::new()
    }


    static [Steps] GetInstance() {
        <#
        .SYNOPSIS
        Gets the singleton instance of the Steps class

        .OUTPUTS
        [Steps] The singleton instance of the Steps class
        #>
        if ($null -eq [Steps]::Instance) {
            [Steps]::Instance = [Steps]::new()
        }
        return [Steps]::Instance
    }


    [void] Add([Step]$step) {
        <#
        .SYNOPSIS
        Adds a new step to the collection

        .PARAMETER step
        The Step object to add

        .NOTES
        Throws an exception if a step with the same name already exists
        #>
        if ($true -eq $this.Exists($step.name)) {
            throw [System.ArgumentException]::new("A step with the name '$($step.name)' already exists.")
        }
        $this.Steps.Add($step.name, $step)
    }


    [void] Remove([string]$name) {
        <#
        .SYNOPSIS
        Removes a step by name

        .PARAMETER name
        The name of the step to remove

        .NOTES
        Throws an exception if the step does not exist
        #>
        if (-not $this.Exists($name)) {
            throw [System.ArgumentException]::new("No step with the name '$name' exists to remove.")
        }
        $this.Steps.Remove($name)
    }


    [void] Update([Step]$step) {
        <#
        .SYNOPSIS
        Updates an existing step by name

        .PARAMETER step
        The Step object to update

        .NOTES
        Throws an exception if the step does not exist
        #>
        if (-not $this.Exists($step.name)) {
            throw [System.ArgumentException]::new("No step with the name '$($step.name)' exists.")
        }

        if ($this.Steps[$step.name].IsProcessed()) {
            throw [System.InvalidOperationException]::new("Cannot update step '$($step.name)' because it has already run.")
        }

        $this.Steps[$step.name] = $step
    }


    [void] AddOrUpdate([Step]$step) {
        <#
        .SYNOPSIS
        Adds a new step or updates an existing step by name

        .PARAMETER step
        The Step object to add or update
        #>
        if ($this.Exists($step.name)) {
            $this.Update($step)
        } else {
            $this.Add($step)
        }
    }


    [Step] Get([string]$name) {
        <#
        .SYNOPSIS
        Gets a step by name

        .PARAMETER name
        The name of the step to retrieve

        .OUTPUTS
        [Step] The Step object associated with the name, or $null if it doesn't exist
        #>
        if ($this.Exists($name)) {
            return $this.Steps[$name]
        }

        return $null
    }

    [bool] Exists([string]$name) {
        <#
        .SYNOPSIS
        Checks if a step exists by name

        .PARAMETER name
        The name of the step to check

        .OUTPUTS
        System.Boolean
        - $true  if the step exists
        - $false if the step does not exist
        #>
        return $this.Steps.ContainsKey($name)
    }

    static [void] Reset() {
        <#
        .SYNOPSIS
        Resets the singleton instance

        .DESCRIPTION
        Clears the singleton instance, forcing GetInstance() to create a new one on the next call.
        This is primarily used for testing.
        #>
        [Steps]::Instance = $null
    }

}
