class OverlayConfig : TaskPluginInterface {
    <#
    .SYNOPSIS
    Task plugin that loads a configuration file via a source plugin and queues its contents as
    step/section overlays and variable updates for the current workflow run.

    .DESCRIPTION
    Uses [sourcePluginFactory] to load a config document from a URI (the same source plugin
    family ImportConfig and Invoke-Forge's -Overlay use), applies any top-level 'variables' from
    the loaded document via $this.Api.Variables, then queues each entry of the loaded 'root' (a
    single step/section config, or a list of them) as a step/section overlay via
    $this.Api.Configuration.RequestOverlay() - the same mechanism a `-Overlay` CLI file uses to
    queue overlays, but reachable declaratively from inside a workflow step instead of only from
    the command line.

    Unlike ImportConfig (which INSERTS the loaded root as a new child of the current step), this
    plugin treats the loaded root as a set of REPLACEMENTS: each entry must carry its own `slug`
    and replaces whatever currently occupies that slug the next time a StepTree node with a
    matching slug is processed - it is never inserted as a child of the current step, and it is
    never required to be a descendant of it either; like a CLI overlay file, it can target any
    slug anywhere in the tree.

    .PARAMETER URI
    The resource path or location that the selected source plugin should load.

    .PARAMETER SourcePluginName
    The source plugin identifier, such as 'yamlSource', used to resolve the loader.
    #>

    OverlayConfig() : base(){
        <#
        .SYNOPSIS
        Constructor for the OverlayConfig plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "OverlayConfig"
            version = "1.0.0"
        }
    }

    [void] ValidateParameters([object]$params) {
        if ($null -eq $params) {
            throw [System.ArgumentException]::new("Parameters cannot be null")
        }

        if ([string]::IsNullOrWhiteSpace([string]$params.URI)) {
            throw [System.ArgumentException]::new("Parameters must include a 'URI' value.", 'URI')
        }

        if ([string]::IsNullOrWhiteSpace([string]$params.SourcePluginName)) {
            throw [System.ArgumentException]::new("Parameters must include a 'SourcePluginName' value.", 'SourcePluginName')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Loads the configured URI via the named source plugin, applies its variables, and queues
        its root entries as step/section overlays.

        .OUTPUTS
        A hashtable describing what was loaded/queued, for debugging/result inspection.
        #>
        if ($null -eq $this.Api) {
            throw [System.InvalidOperationException]::new("OverlayConfig requires an Api to be set via SetApi() before Execute() is called.")
        }

        # No re-templating needed here: Step.InitializePlugin() already expands top-level string
        # parameters (including deferred/lazy-bound plugins) before SetParameters() is called.
        $sourcePluginName = [string]$this.parameters.SourcePluginName
        $uri = [string]$this.parameters.URI

        $sourcePlugin = [sourcePluginFactory]::GetPlugin($sourcePluginName, $uri)
        $loadedConfig = $sourcePlugin.Load()

        if ($null -ne $loadedConfig.variables) {
            $this.Api.Variables.SetMany($loadedConfig.variables)
        }

        $queuedSlugs = [System.Collections.Generic.List[string]]::new()

        # An overlay document's `root` is never inserted as a child - each entry (a single
        # config, or a list of them) is queued as an overlay targeting its own slug instead.
        # @(...) normalizes both shapes into a flat collection without unrolling a single
        # hashtable's own keys, matching Invoke-Forge's -Overlay handling.
        if ($null -ne $loadedConfig.root) {
            foreach ($overlayConfig in @($loadedConfig.root)) {
                $this.Api.Configuration.RequestOverlay($overlayConfig.slug, $overlayConfig)
                $queuedSlugs.Add($overlayConfig.slug)
            }
        }

        return @{
            uri          = $uri
            sourcePlugin = $sourcePluginName
            queuedSlugs  = $queuedSlugs
        }
    }
}

# Register the OverlayConfig plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([OverlayConfig])
