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
