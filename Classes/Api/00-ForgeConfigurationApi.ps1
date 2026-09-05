class ForgeConfigurationApi {
    <#
    .SYNOPSIS
    Scaffold API for plugin-requested configuration changes.

    .DESCRIPTION
    MVP stub: records requested overrides for later processing. Override-merging
    semantics are not yet implemented elsewhere in the codebase (see PROJECT_STATUS.md);
    this class exists so the API surface and injection pattern are in place ahead of that work.
    #>

    hidden [System.Collections.Generic.List[object]] $pendingOverrides
    hidden [System.Collections.Generic.List[object]] $pendingInserts

    ForgeConfigurationApi() {
        $this.pendingOverrides = [System.Collections.Generic.List[object]]::new()
        $this.pendingInserts = [System.Collections.Generic.List[object]]::new()
    }


    <#############
     # Overrides #
     #############>


    [void] RequestOverride([string] $key, [object] $value) {
        <#
        .SYNOPSIS
        Queues a step configuration to replace the existing step named by key.

        .DESCRIPTION
        StepTree.Process() consumes queued overrides after a step runs. The replacement
        config must describe a step with the same name as key; other override shapes are
        intentionally out of scope for the current MVP.

        Yes - we run AFTER - we cannot replace ourself since we are the "override" step that requests the change.
        #>
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [System.ArgumentException]::new('key cannot be null or empty', 'key')
        }
        $this.pendingOverrides.Add(@{ key = $key; value = $value })
    }

    [object] GetPendingOverrides() {
        <#
        .SYNOPSIS
        Returns all configuration overrides requested so far.

        .NOTES
        Returns [object] rather than a specific array type, matching StepTree's own convention of
        staying generic - avoids PowerShell coercing/unrolling a strictly-typed array return value.
        #>
        return $this.pendingOverrides
    }

    [void] ClearPendingOverrides() {
        <#
        .SYNOPSIS
        Clears queued overrides after StepTree has consumed them.
        #>
        $this.pendingOverrides.Clear()
    }

    <#################
     # END Overrides #
     #################>


    <################
     # Insertions #
     ################>


    [void] Insert([object] $config) {
        <#
        .SYNOPSIS
        Queues a step/section configuration to be inserted as a child of the current StepTree node.

        .DESCRIPTION
        This only records the request on this plugin instance. StepTree.Process() is responsible
        for draining GetPendingInserts() (via the owning Step's plugin reference) and building the
        actual StepTree nodes - this class has no knowledge of StepTree at all.

        Insert() may be called multiple times per Execute() (or across retries); each call queues
        an additional config rather than replacing the previous one. Queued configs are added as
        children in the same order Insert() was called.

        .PARAMETER config
        A step/section configuration object, in the same shape accepted by [StepTree]::new().
        #>
        if ($null -eq $config) {
            throw [System.ArgumentNullException]::new('config', 'config cannot be null')
        }
        $this.pendingInserts.Add($config)
    }

    [object] GetPendingInserts() {
        <#
        .SYNOPSIS
        Returns all queued Insert() configs so far, in the order Insert() was called.
        #>
        return $this.pendingInserts
    }

    [void] ClearPendingInserts() {
        <#
        .SYNOPSIS
        Clears queued Insert() configs after they've been consumed.
        #>
        $this.pendingInserts.Clear()
    }

    <##################
     # END Insertions #
     ##################>
}
