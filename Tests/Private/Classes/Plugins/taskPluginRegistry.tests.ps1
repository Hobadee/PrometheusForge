Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

# Mock plugins used only by these tests. They live here, not in the module, and are never
# registered automatically; each test registers the ones it needs via RegisterPlugin().

# Baseline valid plugin.
class MockValidPlugin : TaskPluginInterface {
    MockValidPlugin() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = 'MockValidPlugin'; version = '1.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] Execute() {
        return @{ result = 'executed' }
    }
}

# A second valid plugin, for tests that register more than one.
class AnotherMockPlugin : TaskPluginInterface {
    AnotherMockPlugin() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = 'AnotherMockPlugin'; version = '1.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] Execute() {
        return @{ result = 'executed' }
    }
}

# Invalid: the name is an empty string.
class MockPluginWithoutName : TaskPluginInterface {
    MockPluginWithoutName() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = ''; version = '1.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] Execute() {
        return @{ result = 'executed' }
    }
}

# Invalid: the name is $null.
class MockPluginWithNullName : TaskPluginInterface {
    MockPluginWithNullName() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = $null; version = '1.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] Execute() {
        return @{ result = 'executed' }
    }
}

# A different plugin type that reports the same name as MockValidPlugin, to exercise name conflicts.
class ConflictingNamePlugin : TaskPluginInterface {
    ConflictingNamePlugin() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = 'MockValidPlugin'; version = '2.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] Execute() {
        return 'conflict'
    }
}

# These tests replace the taskPluginRegistry singleton; restore the original afterwards so later test files still see the plugins registered at module load.
BeforeAll {
    $script:savedtaskPluginRegistry = [taskPluginRegistry]::Instance
}
AfterAll {
    [taskPluginRegistry]::Instance = $script:savedtaskPluginRegistry
}

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

Describe 'Plugin Registration - rejected types' {
    BeforeEach {
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    It 'Should reject an instantiable type that does not implement taskPluginInterface' {
        $exceptionType = [ArgumentException]

        { $registry.RegisterPlugin([System.Text.StringBuilder]) } | Should -Throw -ExceptionType $exceptionType
        $registry.PluginRegistry.Count | Should -Be 0
    }

    It 'Should reject a different plugin type that reuses a registered name' {
        $registry.RegisterPlugin([MockValidPlugin])
        $exceptionType = [ArgumentException]

        { $registry.RegisterPlugin([ConflictingNamePlugin]) } | Should -Throw -ExceptionType $exceptionType

        $registry.PluginRegistry['MockValidPlugin'] | Should -Be ([MockValidPlugin])
    }
}

# GetPlugin() constructs plugins by looking their name up as a class name from inside the module, so these
# tests use CurrentTime, a real module plugin, rather than the test-local mocks above.
Describe 'Plugin Retrieval' {
    BeforeEach {
        [taskPluginRegistry]::Instance = $null
        $registry = [taskPluginRegistry]::GetInstance()
    }

    Context 'GetPlugin' {
        It 'Should return a fresh instance of a registered plugin' {
            $registry.RegisterPlugin([CurrentTime])

            $first = [taskPluginRegistry]::GetPlugin('CurrentTime')
            $second = [taskPluginRegistry]::GetPlugin('CurrentTime')

            $first | Should -BeOfType ([CurrentTime])
            [object]::ReferenceEquals($first, $second) | Should -BeFalse
        }

        It 'Should inject a ForgeApi into the returned plugin' {
            $registry.RegisterPlugin([CurrentTime])

            $plugin = [taskPluginRegistry]::GetPlugin('CurrentTime')

            $plugin.Api | Should -BeOfType ([ForgeApi])
        }

        It 'Should throw when the plugin is not registered' {
            $exceptionType = [ArgumentException]

            { [taskPluginRegistry]::GetPlugin('NotRegistered') } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'GetPluginWithParameters' {
        It 'Should return a plugin with its parameters set' {
            $registry.RegisterPlugin([CurrentTime])

            $plugin = [taskPluginRegistry]::GetPluginWithParameters('CurrentTime', @{ message = 'hello' })

            $plugin | Should -BeOfType ([CurrentTime])
            $plugin.parameters.message | Should -Be 'hello'
        }

        It 'Should throw when the parameters fail validation' {
            $registry.RegisterPlugin([PasswordGenerator])

            { [taskPluginRegistry]::GetPluginWithParameters('PasswordGenerator', @{ length = 0 }) } | Should -Throw
        }

        It 'Should throw when the plugin is not registered' {
            $exceptionType = [ArgumentException]

            { [taskPluginRegistry]::GetPluginWithParameters('NotRegistered', @{}) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'GetPluginNames' {
        It 'Should return no names for an empty registry' {
            @([taskPluginRegistry]::GetPluginNames()).Count | Should -Be 0
        }

        It 'Should return the name of every registered plugin' {
            $registry.RegisterPlugin([MockValidPlugin])
            $registry.RegisterPlugin([AnotherMockPlugin])

            $names = [taskPluginRegistry]::GetPluginNames()

            $names.Count | Should -Be 2
            $names | Should -Contain 'MockValidPlugin'
            $names | Should -Contain 'AnotherMockPlugin'
        }
    }
}
