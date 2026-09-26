Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaCreateTaskDependency Plugin - Basic Functionality' {
    Context 'Constructor and Initialization' {
        It 'Should create an AsanaCreateTaskDependency instance' {
            [AsanaCreateTaskDependency]::new() | Should -Not -BeNullOrEmpty
        }

        It 'Should inherit from AsanaTaskPluginBase' {
            $expectedType = [AsanaTaskPluginBase]

            [AsanaCreateTaskDependency]::new() | Should -BeOfType $expectedType
        }

        It 'Should inherit from TaskPluginInterface' {
            $expectedType = [TaskPluginInterface]

            [AsanaCreateTaskDependency]::new() | Should -BeOfType $expectedType
        }
    }

    Context 'PluginInfo Static Method' {
        It 'Should report its name and version' {
            $info = [AsanaCreateTaskDependency]::PluginInfo()

            $info['name'] | Should -Be 'AsanaCreateTaskDependency'
            $info['version'] | Should -Be '1.0.0'
        }
    }

    Context 'Plugin Registration' {
        It 'Should register in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([AsanaCreateTaskDependency])

            $registry.PluginRegistry.ContainsKey('AsanaCreateTaskDependency') | Should -BeTrue
        }
    }
}

Describe 'AsanaCreateTaskDependency Plugin - Parameter Validation' {
    BeforeEach {
        $script:plugin = [AsanaCreateTaskDependency]::new()
    }

    Context 'Null Parameters' {
        It 'Should throw ArgumentException when parameters is null' {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($null) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'taskGid Validation' {
        It 'Should throw ArgumentException when taskGid is <Description>' -ForEach @(
            @{ Description = 'missing'; Params = @{ relatedTaskGids = @('2'); relation = 'predecessor' } }
            @{ Description = 'empty'; Params = @{ taskGid = ''; relatedTaskGids = @('2'); relation = 'predecessor' } }
            @{ Description = 'whitespace'; Params = @{ taskGid = '   '; relatedTaskGids = @('2'); relation = 'predecessor' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($Params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'relatedTaskGids Validation' {
        It 'Should throw ArgumentException when relatedTaskGids is <Description>' -ForEach @(
            @{ Description = 'missing'; Params = @{ taskGid = '1'; relation = 'predecessor' } }
            @{ Description = 'a single string'; Params = @{ taskGid = '1'; relatedTaskGids = '2'; relation = 'predecessor' } }
            @{ Description = 'not a collection'; Params = @{ taskGid = '1'; relatedTaskGids = 2; relation = 'predecessor' } }
            @{ Description = 'an empty array'; Params = @{ taskGid = '1'; relatedTaskGids = @(); relation = 'predecessor' } }
            @{ Description = 'an array with a blank entry'; Params = @{ taskGid = '1'; relatedTaskGids = @('2', ' '); relation = 'predecessor' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($Params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'relation Validation' {
        It 'Should throw ArgumentException when relation is <Description>' -ForEach @(
            @{ Description = 'missing'; Params = @{ taskGid = '1'; relatedTaskGids = @('2') } }
            @{ Description = 'unsupported'; Params = @{ taskGid = '1'; relatedTaskGids = @('2'); relation = 'sibling' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($Params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Valid Parameters' {
        It 'Should pass validation for relation "<Relation>"' -ForEach @(
            @{ Relation = 'predecessor' }
            @{ Relation = 'successor' }
        ) {
            $params = @{ taskGid = '1'; relatedTaskGids = @('2', '3'); relation = $Relation }

            { $script:plugin.ValidateParameters($params) } | Should -Not -Throw
        }
    }
}

Describe 'AsanaCreateTaskDependency Plugin - Execution' {
    BeforeEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
        $variables = [Variables]::GetInstance()
        $variables.Set('Plugin.Asana.PAT', 'test-personal-access-token')
        $variables.Set('Plugin.Asana.BaseUri', 'https://app.asana.com/api/1.0')
    }

    AfterEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
    }

    Context 'Execute Method' {
        It 'Should POST related tasks to addDependencies for the predecessor relation' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{} } }
            $plugin = [AsanaCreateTaskDependency]::new()
            $plugin.SetParameters(@{ taskGid = '111'; relatedTaskGids = @('222', '333'); relation = 'predecessor' })

            $plugin.Execute() | Out-Null

            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq 'https://app.asana.com/api/1.0/tasks/111/addDependencies' -and
                (($Body | ConvertFrom-Json).data.dependencies -join ',') -eq '222,333'
            }
        }

        It 'Should POST related tasks to addDependents for the successor relation' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{} } }
            $plugin = [AsanaCreateTaskDependency]::new()
            $plugin.SetParameters(@{ taskGid = '111'; relatedTaskGids = @('222', '333'); relation = 'successor' })

            $plugin.Execute() | Out-Null

            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq 'https://app.asana.com/api/1.0/tasks/111/addDependents' -and
                (($Body | ConvertFrom-Json).data.dependents -join ',') -eq '222,333'
            }
        }

        It 'Should return the Asana response' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{ marker = 'from-asana' } } }
            $plugin = [AsanaCreateTaskDependency]::new()
            $plugin.SetParameters(@{ taskGid = '111'; relatedTaskGids = @('222'); relation = 'predecessor' })

            $plugin.Execute().data.marker | Should -Be 'from-asana'
        }

        It 'Should report an API failure as an unsuccessful RunTask()' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { throw [System.InvalidOperationException]::new('boom') }
            $plugin = [AsanaCreateTaskDependency]::new()
            $plugin.SetParameters(@{ taskGid = '111'; relatedTaskGids = @('222'); relation = 'predecessor' })

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
            $result.error.Exception.Message | Should -BeLike '*Asana API request failed*'
        }
    }
}
