Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaCreateSection Plugin - Basic Functionality' {
    Context 'Constructor and Initialization' {
        It 'Should create an AsanaCreateSection instance' {
            $plugin = [AsanaCreateSection]::new()
            $plugin | Should -Not -BeNullOrEmpty
        }

        It 'Should inherit from AsanaTaskPluginBase' {
            $plugin = [AsanaCreateSection]::new()
            $expectedType = [AsanaTaskPluginBase]
            $plugin | Should -BeOfType $expectedType
        }

        It 'Should inherit from TaskPluginInterface' {
            $plugin = [AsanaCreateSection]::new()
            $expectedType = [TaskPluginInterface]
            $plugin | Should -BeOfType $expectedType
        }
    }

    Context 'PluginInfo Static Method' {
        It 'Should return plugin information as hashtable' {
            $info = [AsanaCreateSection]::PluginInfo()
            $info | Should -Not -BeNullOrEmpty
            $info.GetType().Name | Should -Be "Hashtable"
        }

        It 'Should have correct plugin name' {
            $info = [AsanaCreateSection]::PluginInfo()
            $info['name'] | Should -Be "AsanaCreateSection"
        }

        It 'Should have version information' {
            $info = [AsanaCreateSection]::PluginInfo()
            $info['version'] | Should -Not -BeNullOrEmpty
            $info['version'] | Should -Be "1.0.0"
        }
    }

    Context 'Plugin Registration' {
        It 'Should register in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([AsanaCreateSection])
            $registry.PluginRegistry.ContainsKey("AsanaCreateSection") | Should -Be $true
        }
    }
}

Describe 'AsanaCreateSection Plugin - Parameter Validation' {
    BeforeEach {
        $plugin = [AsanaCreateSection]::new()
    }

    Context 'Null Parameters' {
        It 'Should throw ArgumentException when parameters is null' {
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($null) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Name Validation' {
        It 'Should throw ArgumentException when name is missing' {
            $params = @{
                projectGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when name is empty string' {
            $params = @{
                name       = ''
                projectGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when name is whitespace' {
            $params = @{
                name       = '   '
                projectGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'ProjectGid Validation' {
        It 'Should throw ArgumentException when projectGid is missing' {
            $params = @{
                name = 'Next Actions'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Insert Before/After Validation' {
        It 'Should throw ArgumentException when both insert_before and insert_after are provided' {
            $params = @{
                name          = 'Next Actions'
                projectGid    = '12345'
                insert_before = '111'
                insert_after  = '222'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Valid Parameters' {
        It 'Should pass validation when required fields are provided' {
            $params = @{
                name       = 'Next Actions'
                projectGid = '12345'
            }
            { $plugin.ValidateParameters($params) } | Should -Not -Throw
        }

        It 'Should pass validation with insert_before' {
            $params = @{
                name          = 'Next Actions'
                projectGid    = '12345'
                insert_before = '111'
            }
            { $plugin.ValidateParameters($params) } | Should -Not -Throw
        }

        It 'Should pass validation with insert_after' {
            $params = @{
                name         = 'Next Actions'
                projectGid   = '12345'
                insert_after = '222'
            }
            { $plugin.ValidateParameters($params) } | Should -Not -Throw
        }
    }
}

Describe 'AsanaCreateSection Plugin - Execution' {
    BeforeEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
        $variables = [Variables]::GetInstance()
        $variables.Set('Plugin_Asana_PAT', 'test-personal-access-token')
        $variables.Set('Plugin_Asana_BaseUri', 'https://app.asana.com/api/1.0')
    }

    AfterEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
    }

    Context 'Execute Method' {
        It 'Should send POST to /projects/{project_gid}/sections with required fields' {
            $mockResponse = @{
                data = @{
                    gid  = '99999'
                    name = 'Next Actions'
                }
            }

            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $Method | Should -Be 'POST'
                $Uri | Should -Be 'https://app.asana.com/api/1.0/projects/123456789/sections'
                $Headers['Authorization'] | Should -Be 'Bearer test-personal-access-token'
                $ContentType | Should -Be 'application/json'

                $parsedBody = $Body | ConvertFrom-Json
                $parsedBody.data.name | Should -Be 'Next Actions'

                return $mockResponse
            }

            $plugin = [AsanaCreateSection]::new()
            $plugin.SetParameters(@{
                name       = 'Next Actions'
                projectGid = '123456789'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '99999'
            $result.data.name | Should -Be 'Next Actions'
        }

        It 'Should include insert_before and insert_after in payload when provided' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $parsedBody = $Body | ConvertFrom-Json
                $parsedBody.data.insert_before | Should -Be '111'

                return @{ data = @{ gid = '88888' } }
            }

            $plugin = [AsanaCreateSection]::new()
            $plugin.SetParameters(@{
                name          = 'Next Actions'
                projectGid    = '123456789'
                insert_before = '111'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '88888'
        }

        It 'Should omit insert_before/insert_after from payload when not provided' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $parsedBody = $Body | ConvertFrom-Json
                $dataProps = $parsedBody.data.PSObject.Properties.Name
                $dataProps | Should -Contain 'name'
                $dataProps | Should -Not -Contain 'insert_before'
                $dataProps | Should -Not -Contain 'insert_after'

                return @{ data = @{ gid = '77777' } }
            }

            $plugin = [AsanaCreateSection]::new()
            $plugin.SetParameters(@{
                name       = 'Minimal Section'
                projectGid = '123456789'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '77777'
        }

        It 'Should execute successfully via RunTask()' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                return @{ data = @{ gid = '66666'; name = 'RunTask Section' } }
            }

            $plugin = [AsanaCreateSection]::new()
            $plugin.SetParameters(@{
                name       = 'RunTask Section'
                projectGid = '123456789'
            })

            $runResult = $plugin.RunTask()
            $runResult.success | Should -Be $true
            $runResult.object.data.gid | Should -Be '66666'
            $runResult.error | Should -BeNullOrEmpty
        }
    }
}
