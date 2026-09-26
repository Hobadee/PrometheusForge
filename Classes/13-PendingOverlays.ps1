class PendingOverlays {
    <#
    .SYNOPSIS
    Singleton, run-scoped store of step/section overlay configs requested via
    ForgeConfigurationApi.RequestOverlay(), keyed by target slug.

    .DESCRIPTION
    ForgeConfigurationApi.RequestOverlay() queues the caller's raw config here as-is.
    StepTree.ApplyPendingOverlay() checks this store for its own slug at the start of every
    Process() call, so an overlay requested by any previously-processed step is applied
    wherever - and whenever - in the tree a node with a matching slug is next visited, not
    only to children of the requesting step.

    Construction of the actual [Step]/[StepTree] replacement is deliberately left to
    StepTree.ApplyPendingOverlay() rather than done here or in RequestOverlay(): an overlay
    commonly reuses slugs still held by the subtree it's replacing (e.g. "keep this child,
    just change its parameters"), and building a [StepTree] eagerly would collide with those
    still-registered slugs. StepTree.ApplyPendingOverlay() unregisters the old subtree via
    StepTree.Remove() first, then builds the replacement against clean slugs.

    Because plugin instances (and their ForgeApi/ForgeConfigurationApi) are constructed fresh
    per Step (see taskPluginRegistry.GetPlugin()), this store has to live independently of any
    single plugin instance so that an overlay requested by one step's plugin is visible to
    every StepTree node in the run.

    .NOTES
    This class is intended to be used as a singleton. Access via [PendingOverlays]::GetInstance().
    #>

    static [PendingOverlays] $Instance = $null

    [System.Collections.Generic.Dictionary[string, object]] $Overlays = $null


    hidden PendingOverlays() {
        $this.Overlays = [System.Collections.Generic.Dictionary[string, object]]::new()
    }


    static [PendingOverlays] GetInstance() {
        if ($null -eq [PendingOverlays]::Instance) {
            [PendingOverlays]::Instance = [PendingOverlays]::new()
        }
        return [PendingOverlays]::Instance
    }


    # Clears the singleton so the next GetInstance() call starts a fresh run
    static [void] Reset() {
        [PendingOverlays]::Instance = $null
    }


    [void] Request([string] $slug, [object] $config) {
        <#
        .SYNOPSIS
        Queues config to replace whatever currently occupies the StepTree location with the
        given slug, the next time a node with that slug is processed.

        .PARAMETER slug
        The target slug this overlay applies to.

        .PARAMETER config
        The raw step/section configuration to apply, in the same shape accepted by
        [StepTree]::new(). Not constructed into a [Step]/[StepTree] until it is drained and
        applied by StepTree.ApplyPendingOverlay().

        .NOTES
        If a pending overlay already exists for slug, it is overwritten and a warning is
        logged, since the earlier queued overlay will never be applied/drained.
        #>
        if ([string]::IsNullOrWhiteSpace($slug)) {
            throw [System.ArgumentException]::new('slug cannot be null or empty', 'slug')
        }
        if ($null -eq $config) {
            throw [System.ArgumentNullException]::new('config', 'config cannot be null')
        }

        if ($this.Overlays.ContainsKey($slug)) {
            [Log]::Warning("[PendingOverlays]::Request() - A pending overlay for slug '$slug' was never applied and is being replaced by a newer request. Only the most recently requested overlay for a given slug is kept.")
        }

        $this.Overlays[$slug] = $config
    }


    [bool] HasOverlay([string] $slug) {
        <#
        .SYNOPSIS
        Checks whether an overlay is currently queued for slug.
        #>
        return $this.Overlays.ContainsKey($slug)
    }


    [object] Drain([string] $slug) {
        <#
        .SYNOPSIS
        Removes and returns the queued overlay config for slug.

        .OUTPUTS
        [object] The queued raw config, or $null if none is queued.
        #>
        if (-not $this.Overlays.ContainsKey($slug)) {
            return $null
        }

        $config = $this.Overlays[$slug]
        $this.Overlays.Remove($slug)
        return $config
    }


    [string[]] GetPendingSlugs() {
        <#
        .SYNOPSIS
        Returns the slugs of all overlays still queued.
        #>
        $slugs = [string[]]::new($this.Overlays.Count)
        $this.Overlays.Keys.CopyTo($slugs, 0)
        return $slugs
    }


    [int] Count() {
        <#
        .SYNOPSIS
        Returns the number of overlays currently queued.
        #>
        return $this.Overlays.Count
    }

}
