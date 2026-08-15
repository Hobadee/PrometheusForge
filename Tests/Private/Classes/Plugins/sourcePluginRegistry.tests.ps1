Using Module "../../../../build/Lifecycle/Lifecycle.psd1"

class RegistryMockPlugin : sourcePluginInterface {
    RegistryMockPlugin([string] $URI) : base($URI) {}

    static [hashtable] PluginInfo() {
        return @{ Name = 'RegistryMockPlugin'; Version = '1.0.0' }
    }

    [bool] ValidateURI() { return $true }

    [void] doLoad() {
        $this.LoadedConfig = @{ version = 1.0; variables = @{} }
    }
}

class RegistryMockPlugin2 : sourcePluginInterface {
    RegistryMockPlugin2([string] $URI) : base($URI) {}

    static [hashtable] PluginInfo() {
        return @{ Name = 'RegistryMockPlugin2'; Version = '1.0.0' }
    }

    [bool] ValidateURI() { return $true }

    [void] doLoad() {
        $this.LoadedConfig = @{ version = 1.0; variables = @{} }
    }
}

class RegistryMockPluginNoName : sourcePluginInterface {
    RegistryMockPluginNoName([string] $URI) : base($URI) {}

    static [hashtable] PluginInfo() {
        return @{ Name = ''; Version = '1.0.0' }
    }

    [bool] ValidateURI() { return $true }

    [void] doLoad() {
        $this.LoadedConfig = @{ version = 1.0; variables = @{} }
    }
}

Describe 'sourcePluginRegistry Auto-Registration' {
    # Reset and re-register to simulate the effect of module load regardless of test run order.
    BeforeAll {
        [sourcePluginRegistry]::Instance = $null
        [sourcePluginRegistry]::GetInstance().RegisterPlugin([yamlSource])
    }
    AfterAll {
        [sourcePluginRegistry]::Instance = $null
    }

    It 'yamlSource should be registered after module import' {
        [sourcePluginRegistry]::GetInstance().IsRegistered('yamlSource') | Should -BeTrue
    }

    It 'yamlSource should be retrievable as the correct type' {
        $type = [sourcePluginFactory]::GetPluginType('yamlSource')
        $type.Name | Should -Be 'yamlSource'
    }
}

Describe 'sourcePluginRegistry Singleton Pattern' {
    BeforeEach {
        [sourcePluginRegistry]::Instance = $null
    }

    Context 'GetInstance' {
        It 'Should create a new instance on first call' {
            $instance = [sourcePluginRegistry]::GetInstance()
            $instance | Should -Not -BeNullOrEmpty
        }

        It 'Should return the same instance on subsequent calls' {
            $instance1 = [sourcePluginRegistry]::GetInstance()
            $instance2 = [sourcePluginRegistry]::GetInstance()
            $instance1 | Should -Be $instance2
        }

        It 'Should initialize PluginRegistry as an empty dictionary' {
            [sourcePluginRegistry]::GetInstance() | Out-Null
            $expectedType = [System.Collections.Generic.Dictionary[string, [Type]]]
            [sourcePluginRegistry]::Instance.PluginRegistry | Should -BeOfType $expectedType
            [sourcePluginRegistry]::Instance.PluginRegistry.Count | Should -Be 0
        }
    }
}

Describe 'sourcePluginRegistry Plugin Registration' {
    BeforeEach {
        [sourcePluginRegistry]::Instance = $null
        $registry = [sourcePluginRegistry]::GetInstance()
    }

    Context 'RegisterPlugin' {
        It 'Should register a valid plugin' {
            $registry.RegisterPlugin([RegistryMockPlugin])
            $registry.PluginRegistry.Count | Should -Be 1
            $registry.PluginRegistry['RegistryMockPlugin'] | Should -BeOfType [Type]
        }

        It 'Should register multiple plugins' {
            $registry.RegisterPlugin([RegistryMockPlugin])
            $registry.RegisterPlugin([RegistryMockPlugin2])
            $registry.PluginRegistry.Count | Should -Be 2
            $registry.PluginRegistry.ContainsKey('RegistryMockPlugin') | Should -BeTrue
            $registry.PluginRegistry.ContainsKey('RegistryMockPlugin2') | Should -BeTrue
        }

        It 'Should throw when registering a type that does not extend sourcePluginInterface' {
            $exType = [System.ArgumentException]
            { $registry.RegisterPlugin([System.String]) } | Should -Throw -ExceptionType $exType
        }

        It 'Should throw when registering a plugin with an empty name' {
            $exType = [System.ArgumentException]
            { $registry.RegisterPlugin([RegistryMockPluginNoName]) } | Should -Throw -ExceptionType $exType
        }

        It 'Should throw when registering a duplicate plugin name' {
            $registry.RegisterPlugin([RegistryMockPlugin])
            $exType = [System.ArgumentException]
            { $registry.RegisterPlugin([RegistryMockPlugin]) } | Should -Throw -ExceptionType $exType
        }

        It 'Should throw when registering a null type' {
            $exType = [System.ArgumentNullException]
            { $registry.RegisterPlugin($null) } | Should -Throw -ExceptionType $exType
        }
    }

    Context 'IsRegistered' {
        It 'Should return $true for a registered plugin' {
            $registry.RegisterPlugin([RegistryMockPlugin])
            $registry.IsRegistered('RegistryMockPlugin') | Should -BeTrue
        }

        It 'Should return $false for an unregistered plugin name' {
            $registry.IsRegistered('NonExistentPlugin') | Should -BeFalse
        }
    }
}


