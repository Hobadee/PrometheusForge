class ForgeConfigurationApi {
    <#
    .SYNOPSIS
    Plugin-facing API for requesting configuration changes.

    .DESCRIPTION
    Provides plugins an entry point for queuing tree overrides (RequestOverride) and inline
    insertions (Insert). Override requests are queued on the shared, run-scoped
    [PendingOverrides] singleton rather than on this instance, so that any StepTree node - not
    only children of the requesting step - can see and apply a pending override for its own
    slug. See StepTree.ApplyPendingOverride().
    #>

    hidden [System.Collections.Generic.List[object]] $pendingInserts

    ForgeConfigurationApi() {
        $this.pendingInserts = [System.Collections.Generic.List[object]]::new()
    }


    <#############
     # Overrides #
     #############>


    [void] RequestOverride([string] $key, [object] $config) {
        <#
        .SYNOPSIS
        Queues a step or section configuration to replace whatever currently occupies the
        StepTree location with slug key, the next time a node with that slug is processed.

        .DESCRIPTION
        The raw config is queued on the shared [PendingOverrides] singleton, keyed by key.
        Building the replacement [Step]/[StepTree] is intentionally deferred to
        StepTree.ApplyPendingOverride() rather than done here: an override commonly reuses
        slugs still held by the subtree it's replacing (e.g. "keep this child, just change its
        parameters"), so the old subtree needs to be unregistered first - which only happens
        once the target node is actually reached during Process().

        A config with type 'step' is a leaf-only replacement: only the registered Step for key
        is swapped; the node's position, tags and children are untouched. Any other config is
        a structural replacement: the whole subtree at key, including its children and tags,
        is replaced.

        Yes - we run AFTER - we cannot replace ourself since we are the "override" step that
        requests the change: our own StepTree node has already begun Process() by the time we run.

        .PARAMETER key
        The slug of the StepTree node/Step this override targets.

        .PARAMETER config
        A step/section configuration, in the same shape accepted by [StepTree]::new(). Must
        describe a configuration with the same slug as key.
        #>
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [System.ArgumentException]::new('key cannot be null or empty', 'key')
        }
        if ($null -eq $config) {
            throw [System.ArgumentNullException]::new('config', 'config cannot be null')
        }
        # Note: config.slug lives at the root here even for a 'section' config - the top-level
        # YAML file's 'root' wrapper is stripped once in Invoke-Forge before anything reaches
        # StepTree/Step, so it never applies to nested step/section configs like this one.
        if ($config.slug -ne $key) {
            throw [System.ArgumentException]::new("Override for '$key' must provide a configuration with the same slug.")
        }

        [PendingOverrides]::GetInstance().Request($key, $config)
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
