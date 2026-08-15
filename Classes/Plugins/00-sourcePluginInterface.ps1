class sourcePluginInterface {
    <#
    .SYNOPSIS
    Base class for source plugins that load configuration data from an external source.

    .DESCRIPTION
    sourcePluginInterface provides the concrete validation/load workflow shared by all source plugins.
    Derived source plugins are responsible for implementing URI validation, configuration validation,
    and plugin metadata.

    .NOTES
    Source plugins are intended to be instantiated directly with a URI and then loaded via Load().
    #>

    [string] $Name = $null
    [string] $Version = $null
    [URI] $URI = $null
    [object] $LoadedConfig = $null
    [bool] $IsValidatedURI = $false
    [bool] $IsLoaded = $false


    sourcePluginInterface([string] $URI) {
        <#
        .SYNOPSIS
        Initializes a source plugin with its target URI.

        .PARAMETER URI
        The URI or path used to locate configuration data.
        #>
        if ($null -eq $URI -or [string]::IsNullOrWhiteSpace($URI)) {
            throw [System.ArgumentNullException]::new('URI', 'URI cannot be null or empty')
        }

        $this.URI = [URI]::new($URI, [System.UriKind]::RelativeOrAbsolute)

        if (-not $this.ValidateURI()) {
            throw [System.ArgumentException]::new('URI is not valid', 'URI')
        }
    }


    [object] getConfig(){
        <#
        .SYNOPSIS
        Returns the configuration object
        #>
        return $this.LoadedConfig
    }


    [void] setConfig([object] $config){
        <#
        .SYNOPSIS
        Sets the configuration object

        .PARAMETER config
        The configuration object to be set.
        #>
        if($null -eq $config){
            throw [System.ArgumentNullException]::new('config', 'Variables object cannot be null')
        }

        if($null -ne $this.LoadedConfig){
            throw [System.InvalidOperationException]::new('Variables object has already been set and cannot be overwritten.')
        }

        $this.LoadedConfig = $config
    }


    [object] Load() {
        <#
        .SYNOPSIS
        Loads configuration data from the source plugin.

        .DESCRIPTION
        Calls doLoad() to perform the actual loading of configuration data.  Derived plugins
        must implement doLoad() to populate the LoadedConfig property.  After loading,
        ValidateConfig() is called to ensure the configuration data is valid.  If the
        configuration data is not valid, an exception is thrown.
        #>
        if($null -eq $this.LoadedConfig){
            $this.doLoad()
            if ($null -eq $this.LoadedConfig) {
                throw [System.InvalidOperationException]::new('Source plugins must populate LoadedConfig during doLoad().')
            }
            $this.IsLoaded = $this.ValidateConfig()
        }

        return $this.getConfig()

    }


    [bool] ValidateURI() {
        <#
        .SYNOPSIS
        Validates the URI.
        
        .DESCRIPTION
        Derived source plugins must implement this method to perform URI validation.
        #>
        throw [System.NotImplementedException]::new('ValidateURI must be implemented by derived source plugins')
    }


    [bool] ValidateConfig() {
        <#
        .SYNOPSIS
        Validates the loaded configuration.

        .DESCRIPTION
        Confirms the loaded configuration is suitable for downstream processing.
        Validation currently enforces all of the following rules:
        - LoadedConfig must be populated (not $null).
        - LoadedConfig must be dictionary-based (implementing System.Collections.IDictionary).
        - A version key must exist and contain a non-empty value.
        - The version value must be parseable as a System.Version value.
        - The parsed version must be 1.0 or greater.
        - At least one top-level section must exist: variables and/or root.

        .NOTES
        Concrete method!
        #>

        if ($null -eq $this.LoadedConfig) {
            throw [System.InvalidOperationException]::new("The source '$($this.URI)' did not produce a configuration object.")
        }

        $config = $this.LoadedConfig

        if ($config -isnot [System.Collections.IDictionary]) {
            throw [System.InvalidOperationException]::new("The source '$($this.URI)' must produce a dictionary-based configuration object.")
        }

        $hasVersion = $config.Contains('version')
        $versionValue = $null
        if ($hasVersion) {
            $versionValue = $config['version']
        }

        if (-not $hasVersion -or [string]::IsNullOrWhiteSpace([string]$versionValue)) {
            throw [System.InvalidOperationException]::new("The source '$($this.URI)' must include version 1.0 or later.")
        }

        $versionString = [string]$versionValue
        if ($versionString -notmatch '\.') {
            $versionString = "$versionString.0"
        }

        try {
            $configVersion = [version]::Parse($versionString)
        }
        catch {
            throw [System.ArgumentException]::new("The source '$($this.URI)' has an invalid version value '$versionValue'.", 'version')
        }

        if ($configVersion -lt [version]'1.0') {
            throw [System.InvalidOperationException]::new("The source '$($this.URI)' must include version 1.0 or later.")
        }

        $hasVariables = $config.Contains('variables')
        $hasRoot = $config.Contains('root')

        if (-not ($hasVariables -or $hasRoot)) {
            throw [System.InvalidOperationException]::new("The source '$($this.URI)' must include a variables section and/or a root section.")
        }

        return $true
    }


    [bool] doLoad() {
        <#
        .SYNOPSIS
        Loads the configuration data from the source plugin.

        .DESCRIPTION
        Derived plugins must implement this method to populate the LoadedConfig property.

        .NOTES
        Populate the LoadedConfig property using the setConfig() method
        #>
        throw [System.NotImplementedException]::new('doLoad() must be implemented by derived source plugins')
    }


    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Provides metadata about the source plugin.

        .NOTES
        MUST be implemented by derived source plugins.  Should return a hashtable with the following keys:
        - Name: The name of the source plugin.
        - Version: The version of the source plugin.

        MAY return additional keys such as Description, Author, etc.  The keys and values are up to the derived plugin.

        .OUTPUTS
        A hashtable containing metadata about the source plugin.
        #>
        throw [System.NotImplementedException]::new('PluginInfo must be implemented by derived source plugins')
    }
}

