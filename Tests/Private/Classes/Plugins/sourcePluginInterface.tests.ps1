Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

class MockSourcePlugin : sourcePluginInterface {
    [bool] $UriValidated = $false
    [bool] $DoLoadCalled = $false
    [object] $ConfigToLoad = $null

    MockSourcePlugin([string] $URI) : base($URI) {
    }

    MockSourcePlugin([string] $URI, [object] $ConfigToLoad) : base($URI) {
        $this.ConfigToLoad = $ConfigToLoad
    }

    static [hashtable] PluginInfo() {
        return @{ Name = 'MockSourcePlugin'; Version = '1.0.0' }
    }

    [bool] ValidateURI() {
        $this.UriValidated = $true
        return $true
    }

    [bool] doLoad() {
        $this.DoLoadCalled = $true
        if ($null -ne $this.ConfigToLoad) {
            $this.setConfig($this.ConfigToLoad)
        }
        else {
            $this.setConfig(@{
                version = 1.0
                variables = @{ Source = 'validated' }
            })
        }
        return $true
    }
}

# Rejects any URI using the "invalid" scheme, so constructor validation failures can be exercised.
class SelectiveUriSourcePlugin : sourcePluginInterface {
    SelectiveUriSourcePlugin([string] $URI) : base($URI) {
    }

    [bool] ValidateURI() {
        return $this.URI.Scheme -ne 'invalid'
    }
}

# Validates URIs but leaves doLoad() to the base class.
class UnimplementedLoadSourcePlugin : sourcePluginInterface {
    UnimplementedLoadSourcePlugin([string] $URI) : base($URI) {
    }

    [bool] ValidateURI() {
        return $true
    }
}

# Implements doLoad() but forgets to populate LoadedConfig.
class EmptyLoadSourcePlugin : sourcePluginInterface {
    EmptyLoadSourcePlugin([string] $URI) : base($URI) {
    }

    [bool] ValidateURI() {
        return $true
    }

    [bool] doLoad() {
        return $true
    }
}

Describe 'sourcePluginInterface' {
    It 'stores the provided URI and validates URI during construction' {
        $plugin = [MockSourcePlugin]::new('memory://source')

        $plugin.UriValidated | Should -BeTrue
        $plugin.URI | Should -BeOfType ([System.Uri])
        $plugin.URI.Scheme | Should -Be 'memory'
        $plugin.URI.Host | Should -Be 'source'
    }

    It 'loads configuration through doLoad and returns the loaded config' {
        $plugin = [MockSourcePlugin]::new('memory://source')

        $result = $plugin.Load()

        $plugin.DoLoadCalled | Should -BeTrue
        $result.version | Should -Be 1.0
        $result.variables.Source | Should -Be 'validated'
    }

    It 'does not reload configuration when Load() is called again' {
        $plugin = [MockSourcePlugin]::new('memory://source')

        $first = $plugin.Load()
        $plugin.DoLoadCalled = $false
        $second = $plugin.Load()

        $plugin.DoLoadCalled | Should -BeFalse
        $first.variables.Source | Should -Be 'validated'
        $second.variables.Source | Should -Be 'validated'
    }

    It 'accepts a config with version and variables only' {
        $config = @{ version = 1.0; variables = @{ name = 'value' } }

        $plugin = [MockSourcePlugin]::new('memory://source', $config)

        $result = $plugin.Load()

        $plugin.DoLoadCalled | Should -BeTrue
        $result.version | Should -Be 1.0
        $result.variables.name | Should -Be 'value'
    }

    It 'accepts a config with version and root only' {
        $config = @{ version = 1.0; root = @{ name = 'root-node' } }

        $plugin = [MockSourcePlugin]::new('memory://source', $config)

        $result = $plugin.Load()

        $plugin.DoLoadCalled | Should -BeTrue
        $result.version | Should -Be 1.0
        $result.root.name | Should -Be 'root-node'
    }

    It 'rejects configs without version 1.0 or later' {
        $config = @{ variables = @{ name = 'value' } }

        $plugin = [MockSourcePlugin]::new('memory://source', $config)

        $exceptionType = [System.InvalidOperationException]
        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'rejects configs without variables or root sections' {
        $config = @{ version = 1.0; metadata = @{ author = 'Eric' } }

        $plugin = [MockSourcePlugin]::new('memory://source', $config)

        $exceptionType = [System.InvalidOperationException]
        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }
}

Describe 'sourcePluginInterface construction' {
    It 'rejects an empty or whitespace URI: <Description>' -ForEach @(
        @{ Description = 'null'; Uri = $null }
        @{ Description = 'empty'; Uri = '' }
        @{ Description = 'whitespace'; Uri = '   ' }
    ) {
        $exceptionType = [System.ArgumentNullException]

        { [MockSourcePlugin]::new($Uri) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'rejects a URI that the derived plugin reports as invalid' {
        $exceptionType = [System.ArgumentException]

        { [SelectiveUriSourcePlugin]::new('invalid://source') } | Should -Throw -ExceptionType $exceptionType
        { [SelectiveUriSourcePlugin]::new('memory://source') } | Should -Not -Throw
    }

    It 'requires derived plugins to implement ValidateURI' {
        $exceptionType = [System.NotImplementedException]

        { [sourcePluginInterface]::new('memory://source') } | Should -Throw -ExceptionType $exceptionType
    }
}

Describe 'sourcePluginInterface abstract members' {
    It 'requires derived plugins to implement doLoad' {
        $plugin = [UnimplementedLoadSourcePlugin]::new('memory://source')
        $exceptionType = [System.NotImplementedException]

        { $plugin.doLoad() } | Should -Throw -ExceptionType $exceptionType
        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'requires derived plugins to implement PluginInfo' {
        $exceptionType = [System.NotImplementedException]

        { [sourcePluginInterface]::PluginInfo() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'requires doLoad to populate LoadedConfig' {
        $plugin = [EmptyLoadSourcePlugin]::new('memory://source')
        $exceptionType = [System.InvalidOperationException]

        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
        $plugin.IsLoaded | Should -BeFalse
    }
}

Describe 'sourcePluginInterface config accessors' {
    BeforeEach {
        $script:plugin = [MockSourcePlugin]::new('memory://source')
    }

    It 'returns $null from getConfig() before anything is loaded' {
        $script:plugin.getConfig() | Should -BeNullOrEmpty
    }

    It 'stores the config passed to setConfig()' {
        $config = @{ version = 1.0; variables = @{} }

        $script:plugin.setConfig($config)

        $script:plugin.getConfig() | Should -Be $config
    }

    It 'rejects a null config' {
        $exceptionType = [System.ArgumentNullException]

        { $script:plugin.setConfig($null) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'refuses to overwrite a config that has already been set' {
        $script:plugin.setConfig(@{ version = 1.0; variables = @{} })
        $exceptionType = [System.InvalidOperationException]

        { $script:plugin.setConfig(@{ version = 2.0; variables = @{} }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'marks the plugin as loaded after a successful Load()' {
        $script:plugin.IsLoaded | Should -BeFalse

        $script:plugin.Load() | Out-Null

        $script:plugin.IsLoaded | Should -BeTrue
    }
}

Describe 'sourcePluginInterface ValidateConfig' {
    BeforeEach {
        $script:plugin = [MockSourcePlugin]::new('memory://source')
    }

    It 'throws when no configuration has been loaded' {
        $exceptionType = [System.InvalidOperationException]

        { $script:plugin.ValidateConfig() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the configuration is not dictionary-based: <Description>' -ForEach @(
        @{ Description = 'string'; Config = 'just text' }
        @{ Description = 'array'; Config = @(1, 2, 3) }
    ) {
        $script:plugin.LoadedConfig = $Config
        $exceptionType = [System.InvalidOperationException]

        { $script:plugin.ValidateConfig() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the version is missing or blank: <Description>' -ForEach @(
        @{ Description = 'missing'; Config = @{ variables = @{} } }
        @{ Description = 'empty'; Config = @{ version = ''; variables = @{} } }
        @{ Description = 'whitespace'; Config = @{ version = '   '; variables = @{} } }
    ) {
        $script:plugin.LoadedConfig = $Config
        $exceptionType = [System.InvalidOperationException]

        { $script:plugin.ValidateConfig() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the version cannot be parsed' {
        $script:plugin.LoadedConfig = @{ version = 'banana'; variables = @{} }
        $exceptionType = [System.ArgumentException]

        { $script:plugin.ValidateConfig() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the version is below 1.0' {
        $script:plugin.LoadedConfig = @{ version = 0.9; variables = @{} }
        $exceptionType = [System.InvalidOperationException]

        { $script:plugin.ValidateConfig() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'accepts a supported version: <Version>' -ForEach @(
        @{ Version = 1 }
        @{ Version = 1.0 }
        @{ Version = '1.0.0' }
        @{ Version = '2.5' }
    ) {
        $script:plugin.LoadedConfig = @{ version = $Version; variables = @{} }

        $script:plugin.ValidateConfig() | Should -BeTrue
    }
}
