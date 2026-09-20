Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaAddTasksToSection Plugin - Parameter Validation' {
    BeforeEach {
        $plugin = [AsanaAddTasksToSection]::new()
    }

    It 'requires a non-empty section GID' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ taskGids = @('12345') }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ sectionGid = ' '; taskGids = @('12345') }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'requires a non-empty array of task GIDs' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ sectionGid = '99999' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ sectionGid = '99999'; taskGids = '12345' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ sectionGid = '99999'; taskGids = @() }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ sectionGid = '99999'; taskGids = @('12345', '') }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'accepts a section GID and array of task GIDs' {
        { $plugin.ValidateParameters(@{ sectionGid = '99999'; taskGids = @('12345', '67890') }) } | Should -Not -Throw
    }
}

Describe 'AsanaAddTasksToSection Plugin - Execution' {
    BeforeEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
        [Variables]::GetInstance().Set('Plugin_Asana_PAT', 'test-personal-access-token')
        [Variables]::GetInstance().Set('Plugin_Asana_BaseUri', 'https://app.asana.com/api/1.0')
    }

    AfterEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
    }

    It 'sends one request per task GID to the target section' {
        Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
            param($Method, $Uri, $Headers, $ContentType, $Body)
            $Method | Should -Be 'POST'
            $Uri | Should -Be 'https://app.asana.com/api/1.0/sections/99999/addTask'
            $Headers.Authorization | Should -Be 'Bearer test-personal-access-token'
            $ContentType | Should -Be 'application/json'
            return @{ data = @{} }
        }

        $plugin = [AsanaAddTasksToSection]::new()
        $plugin.SetParameters(@{
            sectionGid = '99999'
            taskGids   = @('12345', '67890')
        })

        $result = @($plugin.Execute())
        $result.Count | Should -Be 2
        Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
            (($Body | ConvertFrom-Json).data.task -in @('12345', '67890'))
        }
    }
}
