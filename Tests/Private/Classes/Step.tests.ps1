Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../../Helpers/ConsoleCapture.ps1')

    # Steps log through [System.Console]::Out, which Pester does not capture; discard it so
    # expected warnings and errors from these tests don't clutter the test output.
    $script:capture = Start-ConsoleCapture
}

AfterAll {
    [void] (Stop-ConsoleCapture $script:capture)
}


# Plugin whose RunTask() results are scripted by the test, so retry/error handling can be exercised
# without depending on a real plugin that can fail on demand.
class ScriptedTaskPlugin : TaskPluginInterface {
    [int] $Calls = 0
    [object[]] $Results = @()
    [bool] $ThrowOnRun = $false

    ScriptedTaskPlugin() : base() {}

    static [hashtable] PluginInfo() {
        return @{ name = 'ScriptedTaskPlugin'; version = '1.0.0' }
    }

    [void] ValidateParameters([object]$params) {}

    [object] RunTask() {
        $this.Calls++
        if ($this.ThrowOnRun) {
            throw [System.InvalidOperationException]::new('pre-flight failure')
        }

        $index = [Math]::Min($this.Calls, $this.Results.Count) - 1
        return $this.Results[$index]
    }
}

# Object whose string conversion fails, used to force template expansion errors.
class ThrowingToString {
    [string] ToString() {
        throw [System.InvalidOperationException]::new('cannot be rendered')
    }
}

Describe 'Step' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; make sure the plugins these tests rely on exist.
        $registry = [taskPluginRegistry]::GetInstance()
        $registry.RegisterPlugin([TextOutput])
        $registry.RegisterPlugin([CurrentTime])
        $registry.RegisterPlugin([PasswordGenerator])

        function New-StepConfig {
            param([hashtable] $Override = @{})
            $config = @{
                type       = 'step'
                name       = 'Test step'
                slug       = 'test-step'
                plugin     = 'TextOutput'
                parameters = @{ message = 'hello'; method = 'Trace' }
            }
            foreach ($key in $Override.Keys) { $config[$key] = $Override[$key] }
            return $config
        }

        function New-ScriptedStep {
            # Builds a step whose plugin is swapped for a ScriptedTaskPlugin after construction.
            param([hashtable] $Override = @{}, [object[]] $Results, [switch] $ThrowOnRun)
            $step = [Step]::new((New-StepConfig $Override))
            $plugin = [ScriptedTaskPlugin]::new()
            $plugin.Results = $Results
            $plugin.ThrowOnRun = $ThrowOnRun.IsPresent
            $step.plugin = $plugin
            return $step
        }
    }

    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
        [Log]::Reset()
    }

    AfterAll {
        [Steps]::Reset()
        [Variables]::Reset()
        [Log]::Reset()
    }

    Context 'Constructor' {
        It 'stores the name, slug and config and binds the plugin immediately' {
            $config = New-StepConfig
            $step = [Step]::new($config)

            $step.name | Should -Be 'Test step'
            $step.slug | Should -Be 'test-step'
            $step.config | Should -Be $config
            $step.plugin | Should -BeOfType ([TextOutput])
            $step.plugin.parameters.message | Should -Be 'hello'
        }

        It 'leaves the name empty when none is configured' {
            $config = New-StepConfig
            $config.Remove('name')

            [Step]::new($config).name | Should -BeNullOrEmpty
        }

        It 'rejects an invalid slug: <Description>' -ForEach @(
            @{ Description = 'missing'; Slug = $null }
            @{ Description = 'empty'; Slug = '' }
            @{ Description = 'contains a space'; Slug = 'not valid' }
            @{ Description = 'contains a symbol'; Slug = 'bad!slug' }
            @{ Description = 'not a string'; Slug = 5 }
        ) {
            $config = New-StepConfig @{ slug = $Slug }
            $exceptionType = [System.ArgumentException]

            { [Step]::new($config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'accepts a step without parameters when the plugin does not need any' {
            $config = New-StepConfig @{ plugin = 'CurrentTime' }
            $config.Remove('parameters')

            $step = [Step]::new($config)

            $step.plugin | Should -BeOfType ([CurrentTime])
        }

        It 'defers plugin binding when defer_binding is true' {
            $step = [Step]::new((New-StepConfig @{ defer_binding = $true }))

            $step.plugin | Should -BeNullOrEmpty
        }
    }

    Context 'InitializePlugin' {
        It 'throws when the step has no plugin name' {
            $config = New-StepConfig
            $config.Remove('plugin')
            $exceptionType = [System.ArgumentException]

            { [Step]::new($config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when the plugin name is not a string' {
            $config = New-StepConfig @{ plugin = 42 }
            $exceptionType = [System.ArgumentException]

            { [Step]::new($config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when the plugin is not registered' {
            $config = New-StepConfig @{ plugin = 'NoSuchPlugin' }

            { [Step]::new($config) } | Should -Throw "*NoSuchPlugin*"
        }

        It 'expands templates in the plugin name' {
            [Variables]::GetInstance().Set('pluginName', 'CurrentTime')

            $step = [Step]::new((New-StepConfig @{ plugin = '{{ pluginName }}' }))

            $step.plugin | Should -BeOfType ([CurrentTime])
            $step.config.plugin | Should -Be 'CurrentTime'
        }

        It 'wraps failures expanding the plugin name' {
            [Variables]::GetInstance().Set('unrenderable', [ThrowingToString]::new())

            { [Step]::new((New-StepConfig @{ plugin = '{{ unrenderable }}' })) } |
                Should -Throw '*Failed to set plugin name*'
        }

        It 'expands templates in top-level parameters' {
            [Variables]::GetInstance().Set('who', 'Ada')

            $step = [Step]::new((New-StepConfig @{ parameters = @{ message = 'Hello {{ who }}'; method = 'Trace' } }))

            $step.plugin.parameters.message | Should -Be 'Hello Ada'
        }

        It 'wraps plugin parameter validation failures' {
            $config = New-StepConfig @{ plugin = 'PasswordGenerator'; parameters = @{ length = 0 } }

            { [Step]::new($config) } | Should -Throw '*Failed to set parameters for plugin PasswordGenerator*'
        }
    }

    Context 'IsProcessed / GetResult' {
        It 'is not processed and has no result before running' {
            $step = [Step]::new((New-StepConfig))

            $step.IsProcessed() | Should -BeFalse
            $step.GetResult() | Should -BeNullOrEmpty
        }

        It 'is processed and exposes its result after running' {
            $step = [Step]::new((New-StepConfig))
            $step.Process() | Should -BeTrue

            $step.IsProcessed() | Should -BeTrue
            $step.GetResult().success | Should -BeTrue
            $step.GetResult().object | Should -BeOfType ([TextOutput])
        }
    }

    Context 'Process' {
        BeforeEach {
            Mock -ModuleName PrometheusForge -CommandName Start-Sleep -MockWith {}
        }

        It 'returns true and stores the result when the plugin succeeds' {
            $step = New-ScriptedStep -Results @(@{ success = $true; object = 'done' })

            $step.Process() | Should -BeTrue

            $step.result.object | Should -Be 'done'
            $step.plugin.Calls | Should -Be 1
            Should -Invoke -ModuleName PrometheusForge -CommandName Start-Sleep -Times 0 -Exactly
        }

        It 'stores the full result in Variables when a result name is configured' {
            $step = New-ScriptedStep @{ result = 'myResult' } -Results @(@{ success = $true; object = 'done' })

            $step.Process() | Should -BeTrue

            [Variables]::GetInstance().Get('myResult').object | Should -Be 'done'
        }

        It 'does not store a result in Variables when no result name is configured' {
            $step = New-ScriptedStep -Results @(@{ success = $true })

            $step.Process() | Out-Null

            [Variables]::GetInstance().HasKey('myResult') | Should -BeFalse
        }

        It 'retries until the plugin succeeds' {
            $step = New-ScriptedStep @{ retry = @{ retries = 5; delay = 2 } } -Results @(
                @{ success = $false }, @{ success = $false }, @{ success = $true }
            )

            $step.Process() | Should -BeTrue

            $step.plugin.Calls | Should -Be 3
            Should -Invoke -ModuleName PrometheusForge -CommandName Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 2 }
        }

        It 'defaults to 3 attempts with a 1 second delay' {
            $step = New-ScriptedStep -Results @(@{ success = $false })

            $step.Process() | Should -BeFalse

            $step.plugin.Calls | Should -Be 3
            Should -Invoke -ModuleName PrometheusForge -CommandName Start-Sleep -Times 3 -Exactly -ParameterFilter { $Seconds -eq 1 }
        }

        It 'honours a configured retry count' {
            $step = New-ScriptedStep @{ retry = @{ retries = 2 } } -Results @(@{ success = $false })

            $step.Process() | Should -BeFalse

            $step.plugin.Calls | Should -Be 2
        }

        It 'ignores retry values that are not integers' {
            $step = New-ScriptedStep @{ retry = @{ retries = 'many'; delay = 'long' } } -Results @(@{ success = $false })

            $step.Process() | Should -BeFalse

            $step.plugin.Calls | Should -Be 3
            Should -Invoke -ModuleName PrometheusForge -CommandName Start-Sleep -Times 3 -Exactly -ParameterFilter { $Seconds -eq 1 }
        }

        It 'returns false and records the failure by default when retries are exhausted' {
            $step = New-ScriptedStep @{ result = 'failed' } -Results @(@{ success = $false; error = 'nope' })

            $step.Process() | Should -BeFalse

            $step.IsProcessed() | Should -BeTrue
            $step.result.error | Should -Be 'nope'
            [Variables]::GetInstance().Get('failed').success | Should -BeFalse
        }

        It 'returns false when onError is "fail"' {
            $step = New-ScriptedStep @{ onError = 'fail'; retry = @{ retries = 1 } } -Results @(@{ success = $false })

            { $step.Process() } | Should -Not -Throw
            $step.IsProcessed() | Should -BeTrue
        }

        It 'throws when onError is "abort" and retries are exhausted' {
            $step = New-ScriptedStep @{ onError = 'abort'; retry = @{ retries = 2 } } -Results @(@{ success = $false; error = 'boom' })

            { $step.Process() } | Should -Throw '*Test step aborting after 2 attempts*'
            $step.plugin.Calls | Should -Be 2
        }

        It 'treats an exception thrown by RunTask as a failed attempt' {
            $step = New-ScriptedStep @{ retry = @{ retries = 2 } } -ThrowOnRun

            $step.Process() | Should -BeFalse

            $step.plugin.Calls | Should -Be 2
            $step.result.success | Should -BeFalse
            $step.result.error.Exception.Message | Should -Be 'pre-flight failure'
        }

        It 'aborts with the exception details when RunTask throws and onError is "abort"' {
            $step = New-ScriptedStep @{ onError = 'abort'; retry = @{ retries = 1 } } -ThrowOnRun

            { $step.Process() } | Should -Throw '*pre-flight failure*'
        }

        It 'binds a deferred plugin at execution time' {
            [Variables]::GetInstance().Set('late', 'bound value')
            $step = [Step]::new((New-StepConfig @{
                defer_binding = $true
                result        = 'lateResult'
                parameters    = @{ message = '{{ late }}'; method = 'Trace' }
            }))
            $step.plugin | Should -BeNullOrEmpty

            $step.Process() | Should -BeTrue

            $step.plugin | Should -BeOfType ([TextOutput])
            [Variables]::GetInstance().Get('lateResult').object.parameters.message | Should -Be 'bound value'
        }
    }
}
