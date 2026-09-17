Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaCreateTask Plugin - Parameter Validation' {
    BeforeEach {
        $plugin = [AsanaCreateTask]::new()
    }

    It 'requires a name and a workspace, project, or parent' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ workspace = '12345' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task' }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'accepts a workspace, projects, or parent as the task location' {
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345' }) } | Should -Not -Throw
        { $plugin.ValidateParameters(@{ name = 'Task'; projects = @('12345') }) } | Should -Not -Throw
        { $plugin.ValidateParameters(@{ name = 'Task'; parent = '12345' }) } | Should -Not -Throw
    }

    It 'rejects invalid enum and Boolean fields' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; resource_subtype = 'invalid' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; approval_status = 'invalid' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; completed = 'true' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; approval_status = 'pending'; completed = $true }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'rejects invalid dates and incompatible date fields' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; due_at = '2026-09-17' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; due_on = '2026-02-30' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; due_at = '2026-09-17T12:00:00Z'; due_on = '2026-09-17' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; start_at = '2026-09-17T12:00:00Z' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; resource_subtype = 'milestone'; due_on = '2026-09-17'; start_on = '2026-09-16' }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'rejects projects that are not a non-empty array of gids' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ name = 'Task'; projects = '12345' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; projects = @() }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; projects = @('') }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'validates html_notes as Asana rich text' {
        $exceptionType = [System.ArgumentException]
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; html_notes = 'Details' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; html_notes = '<body><script>bad</script></body>' }) } | Should -Throw -ExceptionType $exceptionType
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; html_notes = '<body><strong>Details</strong></body>' }) } | Should -Not -Throw
        { $plugin.ValidateParameters(@{ name = 'Task'; workspace = '12345'; html_notes = '<body><h1>Title</h1><img/><hr/></body>' }) } | Should -Not -Throw
    }
}

Describe 'AsanaCreateTask Plugin - Execution' {
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

    It 'sends every supported field to POST /tasks' {
        Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
            param($Method, $Uri, $Headers, $ContentType, $Body)
            $Method | Should -Be 'POST'
            $Uri | Should -Be 'https://app.asana.com/api/1.0/tasks'
            $Headers.Authorization | Should -Be 'Bearer test-personal-access-token'
            $ContentType | Should -Be 'application/json'

            $data = ($Body | ConvertFrom-Json).data
            $data.name | Should -Be 'Ship task plugin'
            $data.resource_subtype | Should -Be 'approval'
            $data.approval_status | Should -Be 'pending'
            $data.completed | Should -BeFalse
            $data.due_at.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') | Should -Be '2026-09-18T12:00:00Z'
            $data.html_notes | Should -Be '<body>Details</body>'
            $data.notes | Should -Be 'Details'
            $data.start_at.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') | Should -Be '2026-09-17T12:00:00Z'
            $data.assignee | Should -Be 'me'
            $data.parent | Should -Be '98765'
            $data.projects | Should -Be @('12345', '67890')
            $data.workspace | Should -Be '24680'
            return @{ data = @{ gid = '99999' } }
        }

        $plugin = [AsanaCreateTask]::new()
        $plugin.SetParameters(@{
            name             = 'Ship task plugin'
            resource_subtype = 'approval'
            approval_status  = 'pending'
            completed        = $false
            due_at           = '2026-09-18T12:00:00Z'
            html_notes       = '<body>Details</body>'
            notes            = 'Details'
            start_at         = '2026-09-17T12:00:00Z'
            assignee         = 'me'
            parent           = '98765'
            projects         = @('12345', '67890')
            workspace        = '24680'
        })

        $plugin.Execute().data.gid | Should -Be '99999'
    }
}
