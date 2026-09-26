Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'AsanaTaskPluginBase' {
    Context 'ValidateParameters' {
        It 'Should throw when parameters are null' {
            $plugin = [AsanaTaskPluginBase]::new()
            $exceptionType = [System.ArgumentException]

            { $plugin.ValidateParameters($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should delegate to ValidateAsanaParameters, which derived plugins must implement' {
            $plugin = [AsanaTaskPluginBase]::new()
            $exceptionType = [System.NotImplementedException]

            { $plugin.ValidateParameters(@{}) } | Should -Throw -ExceptionType $exceptionType
            { $plugin.ValidateAsanaParameters(@{}) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'ValidateRichText' {
        BeforeEach {
            $script:plugin = [AsanaTaskPluginBase]::new()
        }

        # Note: ValidateRichText declares its html parameter as [string], so PowerShell coerces $null to ''
        # before the method's own `$null -eq $html` check can run. Callers guard against $null themselves.

        It 'Should accept a body containing only universal tags' {
            $html = '<body>Plain <strong>bold</strong> <em>italic</em> <a href="https://example.com">link</a><ul><li>item</li></ul></body>'

            { $script:plugin.ValidateRichText('html_notes', $html, @()) } | Should -Not -Throw
        }

        It 'Should require the content to be wrapped in <body> tags' {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateRichText('html_notes', 'no body wrapper', @()) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should reject tags outside the supported set' {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateRichText('html_notes', '<body><h1>heading</h1></body>', @()) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should allow field-specific additional tags' {
            { $script:plugin.ValidateRichText('html_notes', '<body><h1>heading</h1></body>', @('h1')) } | Should -Not -Throw
        }

        It 'Should name the offending field in the error' {
            { $script:plugin.ValidateRichText('description', 'missing body', @()) } | Should -Throw "*'description'*"
        }
    }

    Context 'InvokeAsanaApi' {
        BeforeEach {
            [Variables]::Reset()
            [AsanaApiClient]::Reset()
            [Variables]::GetInstance().Set('Plugin_Asana_PAT', 'test-token')
        }

        AfterAll {
            [Variables]::Reset()
            [AsanaApiClient]::Reset()
        }

        It 'Should delegate the request to the shared AsanaApiClient' {
            Mock -ModuleName PrometheusForge -CommandName Invoke-RestMethod -MockWith { return @{ data = @{ gid = '42' } } }
            $plugin = [AsanaTaskPluginBase]::new()

            $result = $plugin.InvokeAsanaApi('POST', '/things', @{ name = 'thing' })

            $result.data.gid | Should -Be '42'
            Should -Invoke -ModuleName PrometheusForge -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*/things' -and ($Body | ConvertFrom-Json).data.name -eq 'thing'
            }
        }
    }
}
