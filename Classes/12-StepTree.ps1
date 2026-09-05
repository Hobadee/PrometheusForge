class StepTree : System.Collections.IEnumerable{

    <#
    .SYNOPSIS
    Represents a tree structure of steps.
    
    .DESCRIPTION
    The StepTree class is designed to represent a hierarchical structure of
    steps, where each node can have multiple child nodes. It implements the
    IEnumerable interface, allowing for easy iteration over its children.
    
    When a StepTree node is processed, it will invoke the Process() method of
    the corresponding Step object and all child StepTree nodes in a depth-first
    manner.

    There are no separate classes for leaf nodes and internal nodes; both are
    represented by the StepTree class. The distinction is made based on whether
    a node has children.

    There is nothing preventing a StepTree branch from having an attached Step
    object, but it is not recommended, and will be disallowed by convention and
    possibly by validation in the future.
    #>


    [string] $name = $null
    [System.Collections.Generic.List[StepTree]] $children = $null

    # For IEnumerable implementation, track the current index for iteration
    [int] $currentIndex = 0


    StepTree([object]$config) {
        <#
        .SYNOPSIS
        Constructor for the StepTree class

        .PARAMETER config
        The node configuration
        #>

        if (-not ($config.name -and $config.name -is [string])) {
            throw [System.ArgumentException]::new("Every item must contain a name") 
        }
        #Write-Debug "[StepTree]::new() Creating StepTree node '$($config.name)'"
        $this.name = $config.name

        # Add and associate Step object to the Steps collection
        $steps = [Steps]::GetInstance()
        
        <#
        In theory, our design doesn't preclude us from a "section" also having a plugin and step
        associated with it, but it isn't a great idea, and currently we have an issue where
        Step creation fails because no plugin is specified for a section.
        So we will just skip adding a Step for sections for now.

        This is already marked as unsupported in the documentation, so we will just enforce that here.
        We can always change this in the future if we want to support it, but for now, we will just skip adding a Step for sections.
        #>
        if($config.type -eq "step"){
            $steps.Add([Step]::new($config))
        }

        # Do nothing for Sections

        # Initialize children list before handling imports or regular items
        $this.children = [System.Collections.Generic.List[StepTree]]::new()

        # Deprecated; Imports are handled via plugins now
        # # Special handling for Import
        # if($config.type -eq "import"){
        #     # Import steps are not added to the Steps collection, but we will still create a StepTree node for them
        #     Write-Debug "[StepTree]::new() Import: '$($config.name)'@'$($config.uri)'"
        #     foreach ($child in [SourceFactory]::Create($config)) {
        #         #Write-Debug "[StepTree]::new() Adding imported child StepTree node '$($child.name)' to parent '$($this.name)'"
        #         $this.Add($child)
        #     }
        # }
        
        if ($null -ne $config.items -and $config.items -is [System.Collections.IEnumerable]) {
            foreach ($stepConfig in $config.items) {
                # We probably don't actually need to complicate things with a factory
                #$this.Add([StepTreeFactory]::Create($itemConfig))

                #Write-Debug "[StepTree]::new() Adding child StepTree node '$($stepConfig.name)' to parent '$($this.name)'"

                $this.Add([StepTree]::new($stepConfig))
            }
        }

    }


    [void] Add([StepTree] $child) {
        <#
        .SYNOPSIS
        Adds a child node to the tree.

        .DESCRIPTION
        Appends a StepTree-derived object to the internal children collection.
        Null values are rejected to maintain collection integrity.

        .PARAMETER child
        Child node to add. Must not be null.

        .NOTES
        Insertion order determines execution and enumeration order.
        #>
        if ($null -eq $child) {
            throw [System.ArgumentNullException]::new("child", "Child cannot be null")
        }

        $this.children.Add($child)
    }
    

    [object] Process(){
        <#
        .SYNOPSIS
        Processes the current step and its child steps recursively.

        .OUTPUTS
        System.Object
        Really a boolean, but PowerShell binding quirks require it to be declared as System.Object.
        #>
        $stepTotal = 0
        $stepSuccess = 0
        $stepFailure = 0

        $step = [Steps]::GetInstance().Get($this.name)

        # Note: DO NOT wrap this in a try/catch as [Step]::Process() SHOULD
        # throw an unhandled exception if set to "abort" on error.
        # Only call Process() if the step exists (sections have no step in the registry)
        if ($null -ne $step) {
            $res = $step.Process()
        } else {
            $res = $null
        }

        switch ($res) {
            $true {
                $stepSuccess++
                $stepTotal++
            }
            $false {
                $stepFailure++
                $stepTotal++
            }
            $null {
                # Step was not found, so we don't count it as a step
            }
        }

        # Drain any configs the plugin queued via Api.Configuration.Insert() during its own step,
        # so they run as additional children of this node in the same pass.
        # PowerShell property access on $null short-circuits to $null, so this chain is safe even
        # when $step (e.g. sections have none) or $step.plugin is $null.
        # Insert() may have been called multiple times (per Execute() or across retries); each
        # queued config becomes its own child here, added in the same order Insert() was called.
        if ($null -ne $step.plugin.Api) {
            foreach ($insertedConfig in $step.plugin.Api.Configuration.GetPendingInserts()) {
                Write-Debug "[StepTree]::Process() - Inserting plugin-requested child config '$($insertedConfig.name)' under '$($this.name)'"
                $this.Add([StepTree]::new($insertedConfig))
            }
            $step.plugin.Api.Configuration.ClearPendingInserts()
        }

        foreach ($child in $this.children) {
            $res = $child.Process()

            switch ($res) {
                $true {
                    $stepSuccess++
                    $stepTotal++
                }
                $false {
                    $stepFailure++
                    $stepTotal++
                }
                $null {
                    # Step was not found, so we don't count it as a step
                }
            }
        }

        Write-Debug "[StepTree]::Process() - '$($this.name)' - Processed $stepTotal steps: $stepSuccess succeeded, $stepFailure failed."

        if ($stepFailure -gt 0) {
            return $false
        }
        return $true
    }


    <#############################
    # IEnumerable implementation #
    #############################>

    [System.Collections.IEnumerator] GetEnumerator() {
        return $this.children.GetEnumerator()
    }


    [void] SetCurrentIndex([int] $index) {
        if ($index -lt 0 -or $index -ge $this.children.Count) {
            throw [System.ArgumentOutOfRangeException]::new("index", "Index must be between 0 and $($this.children.Count - 1)")
        }
        $this.currentIndex = $index
    }

    
    [StepTree] GetCurrentItem() {
        if ($this.children.Count -eq 0) {
            throw [System.InvalidOperationException]::new("No items are available")
        }

        return $this.children[$this.currentIndex]
    }


    [int] Count() {
        return $this.children.Count
    }

    <#############################
    #                            #
    #############################>


}
