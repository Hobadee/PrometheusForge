Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaApiClient' {
    BeforeEach {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
        [Log]::Reset()
    }

    AfterAll {
        [Variables]::Reset()
        [AsanaApiClient]::Reset()
        [Log]::Reset()
    }

    Context 'Singleton' {
        It 'returns the same instance on repeated calls' {
            $first = [AsanaApiClient]::GetInstance()
            $second = [AsanaApiClient]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeTrue
        }

        It 'returns a fresh instance after Reset()' {
            $first = [AsanaApiClient]::GetInstance()
            $first.bearerToken = 'stale-token'

            [AsanaApiClient]::Reset()
            $second = [AsanaApiClient]::GetInstance()

            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            $second.bearerToken | Should -BeNullOrEmpty
        }

        It 'defaults to the public Asana API base URI' {
            [AsanaApiClient]::GetInstance().baseUri | Should -Be 'https://app.asana.com/api/1.0'
        }
    }

    Context 'Configure' {
        It 'throws when no authentication is configured' {
            $exceptionType = [System.InvalidOperationException]

            { [AsanaApiClient]::GetInstance().Configure() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'reads the PAT from the <Description> variable' -ForEach @(
            @{ Description = 'underscore-style'; Key = 'Plugin_Asana_PAT' }
            @{ Description = 'dotted-style'; Key = 'Plugin.Asana.PAT' }
        ) {
            [Variables]::GetInstance().Set($Key, 'pat-from-variables')
            $client = [AsanaApiClient]::GetInstance()

            $client.Configure()

            $client.bearerToken | Should -Be 'pat-from-variables'
        }

        It 'overrides the base URI from the <Description> variable' -ForEach @(
            @{ Description = 'underscore-style'; Key = 'Plugin_Asana_BaseUri' }
            @{ Description = 'dotted-style'; Key = 'Plugin.Asana.BaseUri' }
        ) {
            $variables = [Variables]::GetInstance()
            $variables.Set('Plugin_Asana_PAT', 'token')
            $variables.Set($Key, 'https://asana.test/api')
            $client = [AsanaApiClient]::GetInstance()

            $client.Configure()

            $client.baseUri | Should -Be 'https://asana.test/api'
        }

        It 'keeps the default base URI when none is configured' {
            [Variables]::GetInstance().Set('Plugin_Asana_PAT', 'token')
            $client = [AsanaApiClient]::GetInstance()

            $client.Configure()

            $client.baseUri | Should -Be 'https://app.asana.com/api/1.0'
        }

        It 'reports OAuth as not implemented when a username is configured: <Description>' -ForEach @(
            @{ Description = 'without a PAT'; WithPat = $false }
            @{ Description = 'even alongside a PAT'; WithPat = $true }
        ) {
            $variables = [Variables]::GetInstance()
            $variables.Set('Plugin_Asana_Username', 'someone')
            if ($WithPat) { $variables.Set('Plugin_Asana_PAT', 'token') }
            $exceptionType = [System.NotImplementedException]

            { [AsanaApiClient]::GetInstance().Configure() } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'InvokeApi' {
        BeforeEach {
            $variables = [Variables]::GetInstance()
            $variables.Set('Plugin_Asana_PAT', 'test-token')
            $variables.Set('Plugin_Asana_BaseUri', 'https://asana.test/api/')
        }

        It 'configures itself lazily on first use' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{} } }
            $client = [AsanaApiClient]::GetInstance()
            $client.bearerToken | Should -BeNullOrEmpty

            $client.InvokeApi('GET', '/users/me', $null) | Out-Null

            $client.bearerToken | Should -Be 'test-token'
        }

        It 'sends an authenticated request and joins the base URI and path cleanly' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{ gid = '1' } } }

            $result = [AsanaApiClient]::GetInstance().InvokeApi('GET', '/users/me', $null)

            $result.data.gid | Should -Be '1'
            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $Uri -eq 'https://asana.test/api/users/me' -and
                $Headers['Authorization'] -eq 'Bearer test-token' -and
                $ContentType -eq 'application/json'
            }
        }

        It 'omits the body when none is given' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{} } }

            [AsanaApiClient]::GetInstance().InvokeApi('GET', 'projects', $null) | Out-Null

            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $null -eq $Body }
        }

        It 'wraps the body in a top-level data property' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{} } }

            [AsanaApiClient]::GetInstance().InvokeApi('POST', '/projects', @{ name = 'Project' }) | Out-Null

            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).data.name -eq 'Project'
            }
        }

        It 'surfaces the Asana error messages from a JSON error response' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                $record = [System.Management.Automation.ErrorRecord]::new(
                    [System.Net.Http.HttpRequestException]::new('Response status code does not indicate success: 400'),
                    'AsanaBadRequest',
                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                    $null
                )
                $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"errors":[{"message":"name: Missing input"},{"message":"workspace: Not a recognized ID"}]}')
                throw $record
            }

            { [AsanaApiClient]::GetInstance().InvokeApi('POST', '/projects', @{}) } |
                Should -Throw '*Asana API request failed: POST /projects - name: Missing input; workspace: Not a recognized ID*'
        }

        It 'reports the underlying failure when the error response is not JSON' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith {
                $record = [System.Management.Automation.ErrorRecord]::new(
                    [System.Net.Http.HttpRequestException]::new('Bad gateway'),
                    'AsanaBadGateway',
                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                    $null
                )
                $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('<html>502 Bad Gateway</html>')
                throw $record
            }

            { [AsanaApiClient]::GetInstance().InvokeApi('GET', '/projects', $null) } |
                Should -Throw '*Asana API request failed: GET /projects*'
        }

        It 'falls back to the exception message when there are no error details' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { throw [System.InvalidOperationException]::new('connection refused') }

            { [AsanaApiClient]::GetInstance().InvokeApi('GET', '/projects', $null) } |
                Should -Throw '*Asana API request failed: GET /projects - connection refused*'
        }

        It 'keeps the original exception as the inner exception' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { throw [System.InvalidOperationException]::new('connection refused') }

            $thrown = $null
            try { [AsanaApiClient]::GetInstance().InvokeApi('GET', '/projects', $null) } catch { $thrown = $_ }

            $thrown | Should -Not -BeNullOrEmpty
            $thrown.Exception.InnerException.Message | Should -Be 'connection refused'
        }
    }
}
