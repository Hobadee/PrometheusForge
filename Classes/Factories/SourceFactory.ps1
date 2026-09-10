class SourceFactory {
    <#
    .SYNOPSIS
    Factory class for creating source items from configuration objects.

    .NOTES
    BURN THIS CLASS WITH FIRE!
    This is a temporary hack to get the source plugin system working.
    #>
    static [object] Create([pscustomobject]$config) {
            # TODO: Are these a bunch of dupe checks that are also done in the config loader? If so, we should remove them from here and just rely on the loader to validate the config.
            if ([string]::IsNullOrWhiteSpace($config.sourcePlugin)) {
                throw [System.ArgumentException]::new("Import items must include a sourcePlugin value.", 'sourcePlugin')
            }

            $configuration = [Variables]::GetInstance()
            $expandedUri = [TemplateEngine]::ExpandString([string]$config.uri, $configuration)

            if ([string]::IsNullOrWhiteSpace($config.uri)) {
                throw [System.ArgumentException]::new("Import items must include a uri value.", 'uri')
            }

            if ([string]::IsNullOrWhiteSpace($expandedUri)) {
                throw [System.ArgumentException]::new("Import items must include a uri value.", 'uri')
            }

            $plugin = [sourcePluginFactory]::GetPlugin($config.sourcePlugin, $expandedUri)
            $loadedConfig = $plugin.Load()

            $configuration.SetMany($loadedConfig.variables)

            $resolvedConfig = if ($null -ne $loadedConfig.root) { $loadedConfig.root } else { $loadedConfig }


            # Overly checky-AI code
            if ($resolvedConfig -is [System.Collections.IEnumerable] -and -not ($resolvedConfig -is [string]) -and -not ($resolvedConfig -is [System.Collections.IDictionary])) {
                $resolvedConfig = [pscustomobject]@{
                    name = if ($null -ne $config.name -and $config.name -is [string]) { $config.name } else { 'Imported section' }
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
                [Log]::Debug("[SourceFactory]::Create() - Wrapping imported step config '$($resolvedConfig.name)' in a synthetic section item.")
            }
            
            return [StepTree]::new($resolvedConfig)

            <#
            $children = [System.Collections.Generic.List[StepTree]]::new()
            
            if ($null -ne $resolvedConfig.items -and $resolvedConfig.items -is [System.Collections.IEnumerable]) {
                foreach ($stepConfig in $resolvedConfig.items) {
                    # We probably don't actually need to complicate things with a factory
                    #$this.Add([StepTreeFactory]::Create($itemConfig))
                    $children.Add([StepTree]::new($stepConfig))
                }
            }

            return $children
            #>

    }
}
