Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaCreateProject Plugin - Basic Functionality' {
    Context 'Constructor and Initialization' {
        It 'Should create an AsanaCreateProject instance' {
            $plugin = [AsanaCreateProject]::new()
            $plugin | Should -Not -BeNullOrEmpty
        }

        It 'Should inherit from AsanaTaskPluginBase' {
            $plugin = [AsanaCreateProject]::new()
            $expectedType = [AsanaTaskPluginBase]
            $plugin | Should -BeOfType $expectedType
        }

        It 'Should inherit from TaskPluginInterface' {
            $plugin = [AsanaCreateProject]::new()
            $expectedType = [TaskPluginInterface]
            $plugin | Should -BeOfType $expectedType
        }
    }

    Context 'PluginInfo Static Method' {
        It 'Should return plugin information as hashtable' {
            $info = [AsanaCreateProject]::PluginInfo()
            $info | Should -Not -BeNullOrEmpty
            $info.GetType().Name | Should -Be "Hashtable"
        }

        It 'Should have correct plugin name' {
            $info = [AsanaCreateProject]::PluginInfo()
            $info['name'] | Should -Be "AsanaCreateProject"
        }

        It 'Should have version information' {
            $info = [AsanaCreateProject]::PluginInfo()
            $info['version'] | Should -Not -BeNullOrEmpty
            $info['version'] | Should -Be "1.0.0"
        }
    }

    Context 'Plugin Registration' {
        It 'Should register in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([AsanaCreateProject])
            $registry.PluginRegistry.ContainsKey("AsanaCreateProject") | Should -Be $true
        }
    }
}

Describe 'AsanaCreateProject Plugin - Parameter Validation' {
    BeforeEach {
        $plugin = [AsanaCreateProject]::new()
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
                workspaceGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when name is empty string' {
            $params = @{
                name         = ''
                workspaceGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when name is whitespace' {
            $params = @{
                name         = '   '
                workspaceGid = '12345'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Workspace Validation' {
        It 'Should throw ArgumentException when workspaceGid is missing' {
            $params = @{
                name = 'Test Project'
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when workspaceGid is empty string' {
            $params = @{
                name         = 'Test Project'
                workspaceGid = ''
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw ArgumentException when workspaceGid is whitespace' {
            $params = @{
                name         = 'Test Project'
                workspaceGid = '   '
            }
            $exceptionType = [System.ArgumentException]
            { $plugin.ValidateParameters($params) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Valid Parameters' {
        It 'Should pass validation when required fields are provided with workspaceGid' {
            $params = @{
                name         = 'Test Project'
                workspaceGid = '12345'
            }
            { $plugin.ValidateParameters($params) } | Should -Not -Throw
        }

        It 'Should pass validation with all optional fields' {
            $params = @{
                name                 = 'Test Project'
                workspaceGid         = '12345'
                notes                = 'Some notes'
                html_notes           = '<body>Some html notes</body>'
                privacy_setting      = 'public_to_workspace'
                default_access_level = 'editor'
                color                = 'dark-pink'
                icon                 = 'list'
                default_view         = 'board'
            }
            { $plugin.ValidateParameters($params) } | Should -Not -Throw
        }
    }
}

Describe 'AsanaCreateProject Plugin - Execution' {
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
        It 'Should send POST to /projects with required fields' {
            $mockResponse = @{
                data = @{
                    gid  = '99999'
                    name = 'My New Project'
                }
            }

            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $Method | Should -Be 'POST'
                $Uri | Should -Be 'https://app.asana.com/api/1.0/projects'
                $Headers['Authorization'] | Should -Be 'Bearer test-personal-access-token'
                $ContentType | Should -Be 'application/json'

                $parsedBody = $Body | ConvertFrom-Json
                $parsedBody.data.name | Should -Be 'My New Project'
                $parsedBody.data.workspace | Should -Be '123456789'

                return $mockResponse
            }

            $plugin = [AsanaCreateProject]::new()
            $plugin.SetParameters(@{
                name         = 'My New Project'
                workspaceGid = '123456789'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '99999'
            $result.data.name | Should -Be 'My New Project'
        }

        It 'Should include all optional fields in payload when provided' {
            $mockResponse = @{
                data = @{
                    gid                  = '88888'
                    name                 = 'Full Project'
                    notes                = 'Project notes'
                    html_notes           = '<body>Project notes</body>'
                    privacy_setting      = 'public_to_workspace'
                    default_access_level = 'editor'
                    color                = 'dark-pink'
                    icon                 = 'list'
                    default_view         = 'board'
                }
            }

            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $parsedBody = $Body | ConvertFrom-Json
                $parsedBody.data.name | Should -Be 'Full Project'
                $parsedBody.data.workspace | Should -Be '123456789'
                $parsedBody.data.notes | Should -Be 'Project notes'
                $parsedBody.data.html_notes | Should -Be '<body>Project notes</body>'
                $parsedBody.data.privacy_setting | Should -Be 'public_to_workspace'
                $parsedBody.data.default_access_level | Should -Be 'editor'
                $parsedBody.data.color | Should -Be 'dark-pink'
                $parsedBody.data.icon | Should -Be 'list'
                $parsedBody.data.default_view | Should -Be 'board'

                return $mockResponse
            }

            $plugin = [AsanaCreateProject]::new()
            $plugin.SetParameters(@{
                name                 = 'Full Project'
                workspaceGid         = '123456789'
                notes                = 'Project notes'
                html_notes           = '<body>Project notes</body>'
                privacy_setting      = 'public_to_workspace'
                default_access_level = 'editor'
                color                = 'dark-pink'
                icon                 = 'list'
                default_view         = 'board'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '88888'
        }

        It 'Should omit optional fields from payload when not provided' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                param($Method, $Uri, $Headers, $ContentType, $Body)
                $parsedBody = $Body | ConvertFrom-Json
                $dataProps = $parsedBody.data.PSObject.Properties.Name
                $dataProps | Should -Contain 'name'
                $dataProps | Should -Contain 'workspace'
                $dataProps | Should -Not -Contain 'notes'
                $dataProps | Should -Not -Contain 'html_notes'
                $dataProps | Should -Not -Contain 'privacy_setting'
                $dataProps | Should -Not -Contain 'default_access_level'
                $dataProps | Should -Not -Contain 'color'
                $dataProps | Should -Not -Contain 'icon'
                $dataProps | Should -Not -Contain 'default_view'

                return @{ data = @{ gid = '77777' } }
            }

            $plugin = [AsanaCreateProject]::new()
            $plugin.SetParameters(@{
                name         = 'Minimal Project'
                workspaceGid = '123456789'
            })

            $result = $plugin.Execute()
            $result.data.gid | Should -Be '77777'
        }

        It 'Should execute successfully via RunTask()' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                return @{ data = @{ gid = '66666'; name = 'RunTask Project' } }
            }

            $plugin = [AsanaCreateProject]::new()
            $plugin.SetParameters(@{
                name         = 'RunTask Project'
                workspaceGid = '123456789'
            })

            $runResult = $plugin.RunTask()
            $runResult.success | Should -Be $true
            $runResult.object.data.gid | Should -Be '66666'
            $runResult.error | Should -BeNullOrEmpty
        }
    }
}
