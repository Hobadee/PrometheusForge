Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

class ConcreteTaskPlugin : TaskPluginInterface {
    [object] $ExecuteResult = 'executed'
    [bool] $ThrowOnExecute = $false

    ConcreteTaskPlugin() : base() {}

    ConcreteTaskPlugin([object] $initialParameters) : base($initialParameters) {}

    static [hashtable] PluginInfo() {
        return @{ name = 'ConcreteTaskPlugin'; version = '1.0.0' }
    }

    [void] ValidateParameters([object] $params) {
        if ($params.reject -eq $true) {
            throw [System.ArgumentException]::new('parameters rejected')
        }
    }

    [object] Execute() {
        if ($this.ThrowOnExecute) {
            throw [System.InvalidOperationException]::new('execute failed')
        }
        return $this.ExecuteResult
    }
}

Describe 'TaskPluginInterface' {
    Context 'Construction' {
        It 'starts without parameters or an API' {
            $plugin = [ConcreteTaskPlugin]::new()

            $plugin.parameters | Should -BeNullOrEmpty
            $plugin.Api | Should -BeNullOrEmpty
        }

        It 'sets and validates initial parameters passed to the constructor' {
            $plugin = [ConcreteTaskPlugin]::new(@{ message = 'hi' })

            $plugin.parameters.message | Should -Be 'hi'
        }

        It 'throws when the initial parameters fail validation' {
            $exceptionType = [System.ArgumentException]

            { [ConcreteTaskPlugin]::new(@{ reject = $true }) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'SetApi' {
        It 'stores the injected API facade' {
            $plugin = [ConcreteTaskPlugin]::new()
            $api = [ForgeApi]::new()

            $plugin.SetApi($api)

            [object]::ReferenceEquals($plugin.Api, $api) | Should -BeTrue
        }
    }

    Context 'SetParameters' {
        It 'stores validated parameters' {
            $plugin = [ConcreteTaskPlugin]::new()

            $plugin.SetParameters(@{ message = 'stored' })

            $plugin.parameters.message | Should -Be 'stored'
        }

        It 'substitutes an empty hashtable for null parameters' {
            $plugin = [ConcreteTaskPlugin]::new()

            $plugin.SetParameters($null)

            $plugin.parameters | Should -BeOfType ([hashtable])
            $plugin.parameters.Count | Should -Be 0
        }

        It 'does not store parameters that fail validation' {
            $plugin = [ConcreteTaskPlugin]::new(@{ message = 'original' })
            $exceptionType = [System.ArgumentException]

            { $plugin.SetParameters(@{ reject = $true }) } | Should -Throw -ExceptionType $exceptionType

            $plugin.parameters.message | Should -Be 'original'
        }
    }

    Context 'Abstract members' {
        It 'requires derived plugins to implement ValidateParameters' {
            $exceptionType = [System.NotImplementedException]

            { [TaskPluginInterface]::new().ValidateParameters(@{}) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'fails SetParameters on a plugin that does not implement ValidateParameters' {
            $exceptionType = [System.NotImplementedException]

            { [TaskPluginInterface]::new().SetParameters(@{}) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'requires derived plugins to implement Execute' {
            $exceptionType = [System.NotImplementedException]

            { [TaskPluginInterface]::new().Execute() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'requires derived plugins to implement PluginInfo' {
            $exceptionType = [System.NotImplementedException]

            { [TaskPluginInterface]::PluginInfo() } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'RunTask' {
        It 'throws when parameters have not been set' {
            $plugin = [ConcreteTaskPlugin]::new()
            $exceptionType = [System.InvalidOperationException]

            { $plugin.RunTask() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'reports success with the Execute() result and timing metadata' {
            $plugin = [ConcreteTaskPlugin]::new(@{})
            $plugin.ExecuteResult = 'the result'

            $result = $plugin.RunTask()

            $result.success | Should -BeTrue
            $result.object | Should -Be 'the result'
            $result.error | Should -BeNullOrEmpty
            $result.startTime | Should -BeOfType ([datetime])
            $result.endTime | Should -BeOfType ([datetime])
            $result.endTime | Should -BeGreaterOrEqual $result.startTime
            $result.executionTime | Should -BeGreaterOrEqual 0
        }

        It 'captures an exception thrown by Execute() instead of propagating it' {
            $plugin = [ConcreteTaskPlugin]::new(@{})
            $plugin.ThrowOnExecute = $true

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
            $result.object | Should -BeNullOrEmpty
            $result.error.Exception.Message | Should -Be 'execute failed'
            $result.executionTime | Should -BeGreaterOrEqual 0
        }
    }
}
