Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'ImportConfig Plugin' {
    BeforeAll {
        # Other test files replace the plugin registry singletons; make sure the plugins these tests rely on exist.
        [sourcePluginRegistry]::GetInstance().RegisterPlugin([yamlSource])

        function New-SourceFile {
            # Writes a YAML document into TestDrive and returns its file URI.
            param([string] $Name, [string] $Content)
            $path = Join-Path $TestDrive $Name
            $Content | Set-Content -Path $path -Encoding utf8
            return [System.Uri]::new($path).AbsoluteUri
        }

        function New-ImportPlugin {
            # Builds an ImportConfig plugin wired up with a ForgeApi, the way taskPluginRegistry does.
            param([string] $Uri)
            $plugin = [ImportConfig]::new()
            $plugin.SetApi([ForgeApi]::new())
            $plugin.SetParameters(@{ URI = $Uri; SourcePluginName = 'yamlSource' })
            return $plugin
        }
    }

    BeforeEach {
        [Variables]::Reset()
    }

    AfterAll {
        [Variables]::Reset()
    }

    Context 'Constructor and PluginInfo' {
        It 'Should inherit from TaskPluginInterface' {
            $expectedType = [TaskPluginInterface]

            [ImportConfig]::new() | Should -BeOfType $expectedType
        }

        It 'Should report its name and version' {
            $info = [ImportConfig]::PluginInfo()

            $info['name'] | Should -Be 'ImportConfig'
            $info['version'] | Should -Be '1.0.0'
        }

        It 'Should be registered in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([ImportConfig])

            $registry.PluginRegistry.ContainsKey('ImportConfig') | Should -BeTrue
        }
    }

    Context 'ValidateParameters' {
        BeforeEach {
            $script:plugin = [ImportConfig]::new()
        }

        It 'Should throw when parameters are null' {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw when URI is missing or blank: <Description>' -ForEach @(
            @{ Description = 'missing'; Params = @{ SourcePluginName = 'yamlSource' } }
            @{ Description = 'empty'; Params = @{ URI = ''; SourcePluginName = 'yamlSource' } }
            @{ Description = 'whitespace'; Params = @{ URI = '   '; SourcePluginName = 'yamlSource' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($Params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw when SourcePluginName is missing or blank: <Description>' -ForEach @(
            @{ Description = 'missing'; Params = @{ URI = 'file.yaml' } }
            @{ Description = 'empty'; Params = @{ URI = 'file.yaml'; SourcePluginName = '' } }
            @{ Description = 'whitespace'; Params = @{ URI = 'file.yaml'; SourcePluginName = '   ' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { $script:plugin.ValidateParameters($Params) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should accept both required parameters' {
            { $script:plugin.ValidateParameters(@{ URI = 'file.yaml'; SourcePluginName = 'yamlSource' }) } | Should -Not -Throw
        }
    }

    Context 'Execute' {
        It 'Should throw when no Api has been injected' {
            $plugin = [ImportConfig]::new()
            $plugin.SetParameters(@{ URI = 'file.yaml'; SourcePluginName = 'yamlSource' })
            $exceptionType = [System.InvalidOperationException]

            { $plugin.Execute() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should queue the loaded root for insertion and describe what it loaded' {
            $uri = New-SourceFile 'section.yaml' @'
version: 1.0
root:
  type: section
  name: Imported root
  slug: imported-root
'@
            $plugin = New-ImportPlugin $uri

            $result = $plugin.Execute()

            $result.uri | Should -Be $uri
            $result.sourcePlugin | Should -Be 'yamlSource'
            $result.insertedName | Should -Be 'Imported root'
            $inserts = $plugin.Api.Configuration.GetPendingInserts()
            $inserts.Count | Should -Be 1
            $inserts[0].slug | Should -Be 'imported-root'
        }

        It 'Should set the loaded variables through the Api' {
            $uri = New-SourceFile 'with-variables.yaml' @'
version: 1.0
variables:
  importedUser: Ada
root:
  type: section
  name: Imported root
  slug: imported-root
'@
            $plugin = New-ImportPlugin $uri

            $plugin.Execute() | Out-Null

            [Variables]::GetInstance().Get('importedUser') | Should -Be 'Ada'
        }

        It 'Should not require a variables section' {
            $uri = New-SourceFile 'no-variables.yaml' @'
version: 1.0
root:
  type: section
  name: Imported root
  slug: imported-root
'@
            $plugin = New-ImportPlugin $uri

            { $plugin.Execute() } | Should -Not -Throw
        }

        It 'Should insert the whole document when there is no root' {
            $uri = New-SourceFile 'no-root.yaml' @'
version: 1.0
name: Whole document
variables:
  fromDocument: yes
'@
            $plugin = New-ImportPlugin $uri

            $result = $plugin.Execute()

            $result.insertedName | Should -Be 'Whole document'
            $plugin.Api.Configuration.GetPendingInserts()[0].name | Should -Be 'Whole document'
        }

        It 'Should wrap a bare list of items in a synthetic section' {
            $uri = New-SourceFile 'list.yaml' @'
version: 1.0
root:
  - type: section
    name: First
    slug: first
  - type: section
    name: Second
    slug: second
'@
            $plugin = New-ImportPlugin $uri

            $result = $plugin.Execute()

            $result.insertedName | Should -Be 'Imported section'
            $inserted = $plugin.Api.Configuration.GetPendingInserts()[0]
            $inserted.slug | Should -Be 'imported-section'
            $inserted.type | Should -Be 'section'
            @($inserted.items).Count | Should -Be 2
        }

        It 'Should wrap a single step in a section named after the step' {
            $uri = New-SourceFile 'step.yaml' @'
version: 1.0
root:
  type: step
  name: Lone step
  slug: lone-step
  plugin: TextOutput
'@
            $plugin = New-ImportPlugin $uri

            $result = $plugin.Execute()

            $result.insertedName | Should -Be 'Lone step'
            $inserted = $plugin.Api.Configuration.GetPendingInserts()[0]
            $inserted.type | Should -Be 'section'
            $inserted.slug | Should -Be 'lone-step'
            @($inserted.items).Count | Should -Be 1
            $inserted.items[0].plugin | Should -Be 'TextOutput'
        }

        It 'Should use default names when wrapping a step that has none' {
            $uri = New-SourceFile 'step-anonymous.yaml' @'
version: 1.0
root:
  type: step
  plugin: TextOutput
'@
            $plugin = New-ImportPlugin $uri

            $result = $plugin.Execute()

            $result.insertedName | Should -Be 'Imported section'
            $plugin.Api.Configuration.GetPendingInserts()[0].slug | Should -Be 'imported-section'
        }

        It 'Should surface a failure to load the source through RunTask()' {
            $plugin = New-ImportPlugin (Join-Path $TestDrive 'missing.yaml')

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
            $result.error | Should -Not -BeNullOrEmpty
        }
    }
}
