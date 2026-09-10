class ImportConfig : TaskPluginInterface {
    <#
    .SYNOPSIS
    Task plugin that loads a configuration file via a source plugin and inserts it into the workflow.

    .DESCRIPTION
    Uses [sourcePluginFactory] to load a config document from a URI (same source plugin family used
    by StepTree's built-in "type: import" handling), applies any top-level 'variables' from the loaded
    document via $this.Api.Variables, then queues the loaded 'root' (or the whole document, if no
    'root' key) for insertion as a child of the current step via $this.Api.Configuration.Insert().

    Unlike the built-in "type: import" StepTree handling (which happens at tree-construction time),
    this plugin runs at execution time like any other task - so it can be conditional, retried, or
    templated the same way as any other step.
    #>

    ImportConfig() : base(){
        <#
        .SYNOPSIS
        Constructor for the ImportConfig plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "ImportConfig"
            version = "1.0.0"
        }
    }

    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates the parameters for the ImportConfig plugin.

        .DESCRIPTION
        Requires:
        - URI: the location to load, passed to the named source plugin.
        - SourcePluginName: the registered source plugin to use for loading (e.g. 'yamlSource').
        #>
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
        Loads the configured URI via the named source plugin and inserts it into the workflow.

        .OUTPUTS
        A hashtable describing what was loaded/inserted, for debugging/result inspection.
        #>
        if ($null -eq $this.Api) {
            throw [System.InvalidOperationException]::new("ImportConfig requires an Api to be set via SetApi() before Execute() is called.")
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

        $resolvedConfig = if ($null -ne $loadedConfig.root) { $loadedConfig.root } else { $loadedConfig }

        # A bare list of items and a bare "step" both need wrapping in a synthetic section,
        # matching the same normalization SourceFactory/ItemFactory apply for imports.
        if ($resolvedConfig -is [System.Collections.IEnumerable] -and -not ($resolvedConfig -is [string]) -and -not ($resolvedConfig -is [System.Collections.IDictionary])) {
            $resolvedConfig = [pscustomobject]@{
                name = 'Imported section'
                type = 'section'
                items = @($resolvedConfig)
            }
        }

        if ($resolvedConfig.type -eq 'step') {
            $resolvedConfig = [pscustomobject]@{
                name = if ($null -ne $resolvedConfig.name -and $resolvedConfig.name -is [string]) { $resolvedConfig.name } else { 'Imported section' }
                type = 'section'
                items = @($resolvedConfig)
            }
        }

        $this.Api.Configuration.Insert($resolvedConfig)

        return @{
            uri = $uri
            sourcePlugin = $sourcePluginName
            insertedName = $resolvedConfig.name
        }
    }
}

# Register the ImportConfig plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([ImportConfig])
