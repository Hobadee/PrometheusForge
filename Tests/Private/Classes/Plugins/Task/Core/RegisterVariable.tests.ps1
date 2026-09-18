Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'RegisterVariable Plugin - Basic Functionality' {
    BeforeEach {
        [Variables]::Reset()
    }

    Context 'Constructor and Initialization' {
        It 'Should create a RegisterVariable instance' {
            $plugin = [RegisterVariable]::new()
            $plugin | Should -Not -BeNullOrEmpty
        }

        It 'Should inherit from TaskPluginInterface' {
            $plugin = [RegisterVariable]::new()
            $expectedType = [TaskPluginInterface]
            $plugin | Should -BeOfType $expectedType
        }
    }

    Context 'PluginInfo Static Method' {
        It 'Should return plugin information as hashtable' {
            $info = [RegisterVariable]::PluginInfo()
            $info | Should -Not -BeNullOrEmpty
            $info.GetType().Name | Should -Be "Hashtable"
        }

        It 'Should have correct plugin name' {
            $info = [RegisterVariable]::PluginInfo()
            $info['name'] | Should -Be "RegisterVariable"
        }

        It 'Should have version information' {
            $info = [RegisterVariable]::PluginInfo()
            $info['version'] | Should -Be "1.0.0"
        }
    }

    Context 'ValidateParameters' {
        It 'Should throw when name is missing' {
            $plugin = [RegisterVariable]::new()
            { $plugin.SetParameters(@{ value = 'someValue' }) } | Should -Throw
        }

        It 'Should throw when name is an empty string' {
            $plugin = [RegisterVariable]::new()
            { $plugin.SetParameters(@{ name = ''; value = 'someValue' }) } | Should -Throw
        }

        It 'Should throw when name is not a string' {
            $plugin = [RegisterVariable]::new()
            { $plugin.SetParameters(@{ name = @('not', 'a', 'string'); value = 'someValue' }) } | Should -Throw
        }

        It 'Should accept a valid name/value pair' {
            $plugin = [RegisterVariable]::new()
            { $plugin.SetParameters(@{ name = 'myVar'; value = 'myValue' }) } | Should -Not -Throw
            $plugin.name | Should -Be 'myVar'
            $plugin.value | Should -Be 'myValue'
        }

        It 'Should accept a $null value' {
            $plugin = [RegisterVariable]::new()
            { $plugin.SetParameters(@{ name = 'myVar'; value = $null }) } | Should -Not -Throw
            $plugin.value | Should -BeNullOrEmpty
        }
    }

    Context 'Execute' {
        It 'Registers the name/value pair into Variables' {
            $plugin = [RegisterVariable]::new()
            $plugin.SetParameters(@{ name = 'myVar'; value = 'myValue' })

            $plugin.Execute()

            [Variables]::GetInstance().Get('myVar') | Should -Be 'myValue'
        }

        It 'Returns a hashtable describing the registered name/value' {
            $plugin = [RegisterVariable]::new()
            $plugin.SetParameters(@{ name = 'myVar'; value = 'myValue' })

            $result = $plugin.Execute()

            $result['name'] | Should -Be 'myVar'
            $result['value'] | Should -Be 'myValue'
        }

        It 'Overwrites an existing value for the same name' {
            [Variables]::GetInstance().Set('myVar', 'originalValue')

            $plugin = [RegisterVariable]::new()
            $plugin.SetParameters(@{ name = 'myVar'; value = 'newValue' })
            $plugin.Execute()

            [Variables]::GetInstance().Get('myVar') | Should -Be 'newValue'
        }

        It 'Supports non-string values' {
            $plugin = [RegisterVariable]::new()
            $plugin.SetParameters(@{ name = 'myVar'; value = 42 })
            $plugin.Execute()

            [Variables]::GetInstance().Get('myVar') | Should -Be 42
        }
    }
}
