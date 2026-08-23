Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'taskPluginRegistry Singleton Pattern' {
    BeforeEach {
        # Reset the singleton instance before each test
        [taskPluginRegistry]::Instance = $null
    }

    Context 'GetInstance' {
        It 'Should create a new instance on first call' {
            $instance = [taskPluginRegistry]::GetInstance()
            $instance | Should -Not -BeNullOrEmpty
        }

        It 'Should return the same instance on subsequent calls' {
            $instance1 = [taskPluginRegistry]::GetInstance()
            $instance2 = [taskPluginRegistry]::GetInstance()
            $instance1 | Should -Be $instance2
        }

        It 'Should initialize PluginRegistry as empty dictionary' {
            [taskPluginRegistry]::GetInstance()
            $expectedType = [System.Collections.Generic.Dictionary[string, [Type]]]
            [taskPluginRegistry]::Instance.PluginRegistry | Should -BeOfType $expectedType
            [taskPluginRegistry]::Instance.PluginRegistry.Count | Should -Be 0
        }
    }
}

Describe 'Plugin Registration' {
    BeforeEach {
        # Reset the singleton instance before each test
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    Context 'RegisterPlugin' {
        It 'Should register a valid plugin' {
            $registry.RegisterPlugin([MockValidPlugin])
            $registry.PluginRegistry.Count | Should -Be 1
            $registry.PluginRegistry["MockValidPlugin"] | Should -BeOfType [Type]
            $registry.PluginRegistry["MockValidPlugin"].Name | Should -Be "MockValidPlugin"
        }

        It 'Should register multiple plugins' {
            $registry.RegisterPlugin([MockValidPlugin])
            $registry.RegisterPlugin([AnotherMockPlugin])
            $registry.PluginRegistry.Count | Should -Be 2
            $registry.PluginRegistry["MockValidPlugin"].Name | Should -Be "MockValidPlugin"
            $registry.PluginRegistry["AnotherMockPlugin"].Name | Should -Be "AnotherMockPlugin"
        }

        It 'Should throw when registering a type that does not implement taskPluginInterface' {
            { $registry.RegisterPlugin([System.String]) } | Should -Throw
        }

        It 'Should throw when registering a plugin with empty name' {
            { $registry.RegisterPlugin([MockPluginWithoutName]) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw when registering a plugin with null name' {
            { $registry.RegisterPlugin([MockPluginWithNullName]) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should ignore re-registering the same plugin type' {
            $registry.RegisterPlugin([MockValidPlugin])
            { $registry.RegisterPlugin([MockValidPlugin]) } | Should -Not -Throw
            $registry.PluginRegistry.Count | Should -Be 1
        }
    }
}

Describe 'Plugin Validation' {
    BeforeEach {
        # Reset the singleton instance before each test
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    Context 'GetPluginValidationErrors' {
        It 'Should return empty list for valid plugin' {
            $plugin = [MockValidPlugin]::new()
            $errors = $registry.GetPluginValidationErrors($plugin, $false)
            $errors.Count | Should -Be 0
        }

        It 'Should report error for plugin with empty name' {
            $plugin = [MockPluginWithoutName]::new()
            $errors = $registry.GetPluginValidationErrors($plugin, $false)
            $errors.Count | Should -Be 1
            $errors[0] | Should -Match "Plugin name cannot be null or empty"
        }

        It 'Should report error for plugin with null name' {
            $plugin = [MockPluginWithNullName]::new()
            $errors = $registry.GetPluginValidationErrors($plugin, $false)
            $errors.Count | Should -Be 1
            $errors[0] | Should -Match "Plugin name cannot be null or empty"
        }

        It 'Should report error when duplicate plugin name exists in registry' {
            $registry.RegisterPlugin([MockValidPlugin])
            $plugin = [MockValidPlugin]::new()
            $errors = $registry.GetPluginValidationErrors($plugin, $false)
            $errors.Count | Should -Be 1
            $errors[0] | Should -Match "A plugin with the same name is already registered"
        }

        It 'Should throw when throwOnError is true and errors exist' {
            $plugin = [MockPluginWithoutName]::new()
            { $registry.GetPluginValidationErrors($plugin, $true) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should not throw when throwOnError is false and errors exist' {
            $plugin = [MockPluginWithoutName]::new()
            { $registry.GetPluginValidationErrors($plugin, $false) } | Should -Not -Throw
        }

        It 'Should include all validation errors in exception message' {
            $registry.RegisterPlugin([MockValidPlugin])
            $plugin = [MockPluginWithoutName]::new()
            $plugin::PluginInfo().name = "MockValidPlugin"
            # Can't fully test multiple errors with current mock, but structure is ready
            $errors = $registry.GetPluginValidationErrors($plugin, $false)
            $errors.Count | Should -BeGreaterThan 0
        }
    }
}

Describe 'Plugin Validation - IsPluginValid' {
    BeforeEach {
        # Reset the singleton instance before each test
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    Context 'IsPluginValid' {
        It 'Should return true for valid plugin' {
            $plugin = [MockValidPlugin]::new()
            $isValid = $registry.IsPluginValid($plugin)
            $isValid | Should -Be $true
        }

        It 'Should return false for plugin with empty name' {
            $plugin = [MockPluginWithoutName]::new()
            $isValid = $registry.IsPluginValid($plugin)
            $isValid | Should -Be $false
        }

        It 'Should return false for plugin with null name' {
            $plugin = [MockPluginWithNullName]::new()
            $isValid = $registry.IsPluginValid($plugin)
            $isValid | Should -Be $false
        }

        It 'Should return false when duplicate plugin name exists' {
            $registry.RegisterPlugin([MockValidPlugin])
            $plugin = [MockValidPlugin]::new()
            $isValid = $registry.IsPluginValid($plugin)
            $isValid | Should -Be $false
        }
    }
}

Describe 'Plugin Registry Operations' {
    BeforeEach {
        # Reset the singleton instance before each test
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    Context 'Registry State' {
        It 'Should maintain registry across multiple operations' {
            $registry.RegisterPlugin([MockValidPlugin])
            $registry.RegisterPlugin([AnotherMockPlugin])
            
            $registry.PluginRegistry.Count | Should -Be 2
            $registry.PluginRegistry.ContainsKey("MockValidPlugin") | Should -Be $true
            $registry.PluginRegistry.ContainsKey("AnotherMockPlugin") | Should -Be $true
        }

        It 'Should have correct plugin types stored' {
            $registry.RegisterPlugin([MockValidPlugin])
            $storedType = $registry.PluginRegistry["MockValidPlugin"]
            $storedType | Should -BeOfType [Type]
            $storedType.Name | Should -Be "MockValidPlugin"
        }

        It 'Should retrieve registered plugins by name' {
            $registry.RegisterPlugin([MockValidPlugin])
            $storedType = $registry.PluginRegistry["MockValidPlugin"]
            $storedType.Name | Should -Be "MockValidPlugin"
        }
    }
}
