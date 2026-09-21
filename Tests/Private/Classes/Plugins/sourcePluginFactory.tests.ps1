Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

class FactoryMockPlugin : sourcePluginInterface {
    FactoryMockPlugin([string] $URI) : base($URI) {}

    static [hashtable] PluginInfo() {
        return @{ Name = 'FactoryMockPlugin'; Version = '1.0.0' }
    }

    [bool] ValidateURI() { return $true }

    [void] doLoad() {
        $this.LoadedConfig = @{ version = 1.0; variables = @{} }
    }
}

# These tests replace the sourcePluginRegistry singleton; restore the original afterwards so later test files still see the plugins registered at module load.
BeforeAll {
    $script:savedsourcePluginRegistry = [sourcePluginRegistry]::Instance
}
AfterAll {
    [sourcePluginRegistry]::Instance = $script:savedsourcePluginRegistry
}

Describe 'sourcePluginFactory' {
    BeforeEach {
        [sourcePluginRegistry]::Instance = $null
        [sourcePluginRegistry]::GetInstance().RegisterPlugin([FactoryMockPlugin])
    }
    AfterEach {
        [sourcePluginRegistry]::Instance = $null
    }

    Context 'GetPluginType' {
        It 'Should return the Type stored in the registry' {
            $type = [sourcePluginFactory]::GetPluginType('FactoryMockPlugin')
            $type | Should -BeOfType [Type]
            $type.Name | Should -Be 'FactoryMockPlugin'
        }

        It 'Should throw for an unknown plugin name' {
            $exType = [System.ArgumentException]
            { [sourcePluginFactory]::GetPluginType('NoSuchPlugin') } | Should -Throw -ExceptionType $exType
        }
    }

    Context 'GetPlugin' {
        It 'Should return a sourcePluginInterface instance of the correct type' {
            $plugin = [sourcePluginFactory]::GetPlugin('FactoryMockPlugin', 'fake://uri')
            ($plugin -is [sourcePluginInterface]) | Should -BeTrue
            $plugin.GetType().Name | Should -Be 'FactoryMockPlugin'
        }

        It 'Should construct the plugin with the provided URI' {
            $plugin = [sourcePluginFactory]::GetPlugin('FactoryMockPlugin', 'fake://uri')
            $plugin.URI.OriginalString | Should -Be 'fake://uri'
        }

        It 'Should throw for an unknown plugin name' {
            $exType = [System.ArgumentException]
            { [sourcePluginFactory]::GetPlugin('NoSuchPlugin', 'fake://uri') } | Should -Throw -ExceptionType $exType
        }
    }
}
