class Steps {

    static [Steps] $Instance = $null # Singleton instance

    [System.Collections.Generic.Dictionary[string, [Step]]] $Steps  # List of steps


    hidden Steps() {
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
        Throws an exception if a step with the same slug already exists
        #>
        if ($true -eq $this.Exists($step.slug)) {
            throw [System.ArgumentException]::new("A step with the slug '$($step.slug)' already exists.")
        }
        $this.Steps.Add($step.slug, $step)
    }


    [void] Remove([string]$slug) {
        <#
        .SYNOPSIS
        Removes a step by slug

        .PARAMETER slug
        The slug of the step to remove

        .NOTES
        Throws an exception if the step does not exist
        #>
        if (-not $this.Exists($slug)) {
            throw [System.ArgumentException]::new("No step with the slug '$slug' exists to remove.")
        }
        $this.Steps.Remove($slug)
    }


    [bool] RemoveIfExists([string]$slug) {
        <#
        .SYNOPSIS
        Removes a step by slug if it exists

        .PARAMETER slug
        The slug of the step to remove
        #>
        if ($this.Exists($slug)) {
            $this.Steps.Remove($slug)
            return $true
        }
        return $false
    }


    [void] Update([Step]$step) {
        <#
        .SYNOPSIS
        Updates an existing step by slug

        .PARAMETER step
        The Step object to update

        .NOTES
        Throws an exception if the step does not exist
        #>
        if (-not $this.Exists($step.slug)) {
            throw [System.ArgumentException]::new("No step with the slug '$($step.slug)' exists.")
        }

        if ($this.Steps[$step.slug].IsProcessed()) {
            throw [System.InvalidOperationException]::new("Cannot update step '$($step.slug)' because it has already run.")
        }

        $this.Steps[$step.slug] = $step
    }


    [void] AddOrUpdate([Step]$step) {
        <#
        .SYNOPSIS
        Adds a new step or updates an existing step by slug

        .PARAMETER step
        The Step object to add or update
        #>
        if ($this.Exists($step.slug)) {
            $this.Update($step)
        } else {
            $this.Add($step)
        }
    }


    [Step] Get([string]$slug) {
        <#
        .SYNOPSIS
        Gets a step by slug

        .PARAMETER slug
        The slug of the step to retrieve

        .OUTPUTS
        [Step] The Step object associated with the slug, or $null if it doesn't exist
        #>
        if ($this.Exists($slug)) {
            return $this.Steps[$slug]
        }

        return $null
    }


    [object] GetResult([string]$slug) {
        <#
        .SYNOPSIS
        Gets the result of a step by slug

        .PARAMETER slug
        The slug of the step to retrieve the result for

        .OUTPUTS
        System.Object
        - The result of the step, or $null if it doesn't exist
        #>
        if ($this.IsProcessed($slug)) {
            return $this.Get($slug).GetResult()
        }

        return $null
    }


    [bool] IsProcessed([string]$slug) {
        <#
        .SYNOPSIS
        Checks if a step has been processed (run) by slug

        .PARAMETER slug
        The slug of the step to check

        .OUTPUTS
        System.Boolean
        - $true  if the step has been processed
        - $false if the step has not been processed or does not exist
        #>
        if ($this.Exists($slug)) {
            return $this.Get($slug).IsProcessed()
        }

        return $false
    }
    

    [bool] Exists([string]$slug) {
        <#
        .SYNOPSIS
        Checks if a step exists by slug

        .PARAMETER slug
        The slug of the step to check

        .OUTPUTS
        System.Boolean
        - $true  if the step exists
        - $false if the step does not exist
        #>
        return $this.Steps.ContainsKey($slug)
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
