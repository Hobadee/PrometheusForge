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
    [string] $slug = $null
    [System.Collections.Generic.List[StepTree]] $children = $null
    [tags] $tags = $null

    # For IEnumerable implementation, track the current index for iteration
    [int] $currentIndex = 0


    StepTree([object]$config) {
        <#
        .SYNOPSIS
        Constructor for the StepTree class

        .PARAMETER config
        The node configuration
        #>

        # TODO: This regex validation is duplicated in Step - dedup, along with the name validation above, at some later time.
        if (-not ($config.slug -and $config.slug -is [string] -and $config.slug -match '^[a-zA-Z0-9_-]+$')) {
            throw [System.ArgumentException]::new("Every item must contain a slug matching '^[a-zA-Z0-9_-]+`$'")
        }

        if($null -ne $config.name){
        $this.name = $config.name
        }
        $this.slug = $config.slug

        $this.tags = [tags]::new()
        if ($null -ne $config.tags) {
            $this.tags.AddTags($config.tags)
        }

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


    [void] Remove() {
        <#
        .SYNOPSIS
        Recursively unregisters this subtree's steps from the Steps registry.

        .DESCRIPTION
        Removes every descendant's registered Step first (depth-first), then this node's own
        registered Step, if any. Used by ApplyPendingOverlay() to discard a node's existing
        content before grafting in a [StepTree]-shaped overlay, so the overlay's own
        construction has clean slugs to register against and no orphaned Step entries are
        left behind in the registry once this subtree is no longer part of the tree.

        .NOTES
        Does not touch $this.children itself - the caller is responsible for
        detaching/replacing this node afterward.
        #>
        foreach ($child in $this.children) {
            $child.Remove()
        }

        [Steps]::GetInstance().RemoveIfExists($this.slug)

    }


    [void] ApplyPendingOverlay() {
        <#
        .SYNOPSIS
        Applies a queued overlay targeting this node's own slug, if one is pending.

        .DESCRIPTION
        Checked at the start of every Process() call so an overlay requested by any
        previously-processed step in the run takes effect the next time a node with a matching
        slug is visited - not only for children of the requesting step.

        Building the replacement [Step]/[StepTree] happens here, rather than eagerly when the
        overlay was requested: a structural (section) overlay commonly reuses slugs still
        held by the subtree it's replacing (e.g. "keep this child, just change its
        parameters"), so the old subtree is unregistered via Remove() FIRST, and only then is
        the overlay config actually constructed - giving it clean slugs to register against.

        A config with type 'step' is a leaf-only replacement: only this slug's registered Step
        is swapped; this node's position, tags and children are untouched. Any other config is
        a structural replacement: this node's own subtree is discarded (via Remove()) and its
        name/tags/children are replaced with the overlay's.
        #>
        $pendingOverlays = [PendingOverlays]::GetInstance()
        if (-not $pendingOverlays.HasOverlay($this.slug)) {
            return
        }

        $config = $pendingOverlays.Drain($this.slug)

        if ($config.type -eq 'step') {
            if (-not [Steps]::GetInstance().Exists($this.slug)) {
                throw [System.ArgumentException]::new("No step with slug '$($this.slug)' exists to overlay.")
            }
            [Log]::Debug("[StepTree]::ApplyPendingOverlay() - Replacing API-requested step '$($this.slug)'.")
            [Steps]::GetInstance().Update([Step]::new($config))
            return
        }
        elseif ($config.type -eq 'section') {
            [Log]::Debug("[StepTree]::ApplyPendingOverlay() - Replacing subtree '$($this.slug)' with an API-requested overlay.")
            $this.Remove()
            $overlay = [StepTree]::new($config)

            # Replace current node's properties with those from the overlay
            # If we add class properties later, make sure to copy them from the overlay as well
            $this.name = $overlay.name
            $this.tags = $overlay.tags
            $this.children = $overlay.children

            # Index *SHOULD* still be 0, but in case it isn't, reset the current index to start processing the new children from the beginning.
            $this.currentIndex = 0
        }
        else {
            throw [System.ArgumentException]::new("Unsupported overlay type '$($config.type)'.")
        }

    }


    [bool] checkConditionals() {
        <#
        .SYNOPSIS
        Checks if the step should be executed based on its conditionals.

        .DESCRIPTION
        Compares this node's tags against the run's configured IncludeTags/ExcludeTags:
        - Matches neither: run
        - Matches exclude only: skip
        - Matches include only: run
        - Matches both: fall back to the 'tagsPrecedence' variable ('include' runs, 'exclude' skips,
          unset/anything else defaults to running)

        .NOTES
        Checking conditionals in StepTree vs. Step allows for skipping entire sections of the tree.

        .OUTPUTS
        [bool] True if all conditionals are met, false otherwise
        #>
        $variables = [Variables]::GetInstance()
        $includeTags = $variables.IncludeTags
        $excludeTags = $variables.ExcludeTags

        $matchesInclude = $includeTags.Count() -gt 0 -and $this.tags.HasTags($includeTags.GetTags())
        $matchesExclude = $excludeTags.Count() -gt 0 -and $this.tags.HasTags($excludeTags.GetTags())

        [Log]::Trace("[StepTree]::checkConditionals() - $($this.name) matchesInclude=$matchesInclude matchesExclude=$matchesExclude")

        # Run by default if no conditionals trigger
        $rtn = $true

        if ($matchesExclude) {
            $rtn = $false
        }

        if ($matchesInclude -and $matchesExclude) {
            $precedence = [Variables]::GetInstance().Get('tagsPrecedence')
            $rtn = $precedence -ne 'exclude'
        }

        return $rtn
    }
    

    [object] Process(){
        <#
        .SYNOPSIS
        Processes the current step and its child steps recursively.

        .OUTPUTS
        System.Object
        Really a boolean, but PowerShell binding quirks require it to be declared as System.Object.
        #>

        # Apply any overlay queued for this node's own slug before doing anything else, so a
        # [StepTree]-shaped overlay's tags are honored by checkConditionals() below, and a
        # [Step]-shaped overlay's plugin is what actually runs.
        $this.ApplyPendingOverlay()

        # Check if we even need to run this step, given our conditionals
        if (-not $this.checkConditionals()) {
            [Log]::Debug("[StepTree]::Process() - $($this.name) conditionals not met. Skipping execution.")

            # Returning early will skip processing childres as well; this is what we want.
            return $true

            # Would be nice to note somehow that step was skipped, but result is stored in Step object, not StepTree
            # TODO: Ponder this and figure out a solution - maybe force the result into the StepTree's result property?
            #$res = @{success = $true; skipped = $true}
            #return $res
        }

        $stepTotal = 0
        $stepSuccess = 0
        $stepFailure = 0

        $step = [Steps]::GetInstance().Get($this.slug)

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
                # This is actually expected for sections, which do not have a corresponding step in the registry.
                [Log]::Debug("[StepTree]::Process() - Step '$($this.name)' not found.")
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
                [Log]::Debug("[StepTree]::Process() - Inserting API-requested child config '$($insertedConfig.name)' under '$($this.name)'")
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

        [Log]::Trace("[StepTree]::Process() - '$($this.name)' - Processed $stepTotal steps: $stepSuccess succeeded, $stepFailure failed.")

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
