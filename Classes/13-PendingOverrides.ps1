class PendingOverrides {
    <#
    .SYNOPSIS
    Singleton, run-scoped store of step/section override configs requested via
    ForgeConfigurationApi.RequestOverride(), keyed by target slug.

    .DESCRIPTION
    ForgeConfigurationApi.RequestOverride() queues the caller's raw config here as-is.
    StepTree.ApplyPendingOverride() checks this store for its own slug at the start of every
    Process() call, so an override requested by any previously-processed step is applied
    wherever - and whenever - in the tree a node with a matching slug is next visited, not
    only to children of the requesting step.

    Construction of the actual [Step]/[StepTree] replacement is deliberately left to
    StepTree.ApplyPendingOverride() rather than done here or in RequestOverride(): an override
    commonly reuses slugs still held by the subtree it's replacing (e.g. "keep this child,
    just change its parameters"), and building a [StepTree] eagerly would collide with those
    still-registered slugs. StepTree.ApplyPendingOverride() unregisters the old subtree via
    StepTree.Remove() first, then builds the replacement against clean slugs.

    Because plugin instances (and their ForgeApi/ForgeConfigurationApi) are constructed fresh
    per Step (see taskPluginRegistry.GetPlugin()), this store has to live independently of any
    single plugin instance so that an override requested by one step's plugin is visible to
    every StepTree node in the run.

    .NOTES
    This class is intended to be used as a singleton. Access via [PendingOverrides]::GetInstance().
    #>

    static [PendingOverrides] $Instance = $null

    [System.Collections.Generic.Dictionary[string, object]] $Overrides = $null


    hidden PendingOverrides() {
        $this.Overrides = [System.Collections.Generic.Dictionary[string, object]]::new()
    }


    static [PendingOverrides] GetInstance() {
        if ($null -eq [PendingOverrides]::Instance) {
            [PendingOverrides]::Instance = [PendingOverrides]::new()
        }
        return [PendingOverrides]::Instance
    }


    # Clears the singleton so the next GetInstance() call starts a fresh run
    static [void] Reset() {
        [PendingOverrides]::Instance = $null
    }


    [void] Request([string] $slug, [object] $config) {
        <#
        .SYNOPSIS
        Queues config to replace whatever currently occupies the StepTree location with the
        given slug, the next time a node with that slug is processed.

        .PARAMETER slug
        The target slug this override applies to.

        .PARAMETER config
        The raw step/section configuration to apply, in the same shape accepted by
        [StepTree]::new(). Not constructed into a [Step]/[StepTree] until it is drained and
        applied by StepTree.ApplyPendingOverride().

        .NOTES
        If a pending override already exists for slug, it is overwritten and a warning is
        logged, since the earlier queued override will never be applied/drained.
        #>
        if ([string]::IsNullOrWhiteSpace($slug)) {
            throw [System.ArgumentException]::new('slug cannot be null or empty', 'slug')
        }
        if ($null -eq $config) {
            throw [System.ArgumentNullException]::new('config', 'config cannot be null')
        }

        if ($this.Overrides.ContainsKey($slug)) {
            [Log]::Warning("[PendingOverrides]::Request() - A pending override for slug '$slug' was never applied and is being replaced by a newer request. Only the most recently requested override for a given slug is kept.")
        }

        $this.Overrides[$slug] = $config
    }


    [bool] HasOverride([string] $slug) {
        <#
        .SYNOPSIS
        Checks whether an override is currently queued for slug.
        #>
        return $this.Overrides.ContainsKey($slug)
    }


    [object] Drain([string] $slug) {
        <#
        .SYNOPSIS
        Removes and returns the queued override config for slug.

        .OUTPUTS
        [object] The queued raw config, or $null if none is queued.
        #>
        if (-not $this.Overrides.ContainsKey($slug)) {
            return $null
        }

        $config = $this.Overrides[$slug]
        $this.Overrides.Remove($slug)
        return $config
    }


    [string[]] GetPendingSlugs() {
        <#
        .SYNOPSIS
        Returns the slugs of all overrides still queued.
        #>
        $slugs = [string[]]::new($this.Overrides.Count)
        $this.Overrides.Keys.CopyTo($slugs, 0)
        return $slugs
    }


    [int] Count() {
        <#
        .SYNOPSIS
        Returns the number of overrides currently queued.
        #>
        return $this.Overrides.Count
    }

}
