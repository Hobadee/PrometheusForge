Using Module "../../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'OverlayConfig Plugin' {
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

        function New-OverlayPlugin {
            # Builds an OverlayConfig plugin wired up with a ForgeApi, the way taskPluginRegistry does.
            param([string] $Uri)
            $plugin = [OverlayConfig]::new()
            $plugin.SetApi([ForgeApi]::new())
            $plugin.SetParameters(@{ URI = $Uri; SourcePluginName = 'yamlSource' })
            return $plugin
        }
    }

    BeforeEach {
        [Variables]::Reset()
        [Steps]::Reset()
        [PendingOverlays]::Reset()
    }

    AfterAll {
        [Variables]::Reset()
        [Steps]::Reset()
        [PendingOverlays]::Reset()
    }

    Context 'Constructor and PluginInfo' {
        It 'Should inherit from TaskPluginInterface' {
            $expectedType = [TaskPluginInterface]

            [OverlayConfig]::new() | Should -BeOfType $expectedType
        }

        It 'Should report its name and version' {
            $info = [OverlayConfig]::PluginInfo()

            $info['name'] | Should -Be 'OverlayConfig'
            $info['version'] | Should -Be '1.0.0'
        }

        It 'Should be registered in taskPluginRegistry' {
            $registry = [taskPluginRegistry]::GetInstance()
            $registry.RegisterPlugin([OverlayConfig])

            $registry.PluginRegistry.ContainsKey('OverlayConfig') | Should -BeTrue
        }
    }

    Context 'ValidateParameters' {
        BeforeEach {
            $script:plugin = [OverlayConfig]::new()
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
            $plugin = [OverlayConfig]::new()
            $plugin.SetParameters(@{ URI = 'file.yaml'; SourcePluginName = 'yamlSource' })
            $exceptionType = [System.InvalidOperationException]

            { $plugin.Execute() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should queue a single root entry as an overlay and describe what it queued' {
            $uri = New-SourceFile 'single.yaml' @'
version: 1.0
root:
  type: step
  name: Replacement step
  slug: target
  plugin: TextOutput
  parameters:
    message: replaced
'@
            $plugin = New-OverlayPlugin $uri

            $result = $plugin.Execute()

            $result.uri | Should -Be $uri
            $result.sourcePlugin | Should -Be 'yamlSource'
            $result.queuedSlugs | Should -Contain 'target'

            $pendingOverlays = [PendingOverlays]::GetInstance()
            $pendingOverlays.HasOverlay('target') | Should -BeTrue
            $pendingOverlays.Drain('target').parameters.message | Should -Be 'replaced'
        }

        It 'Should queue every entry when root is a list' {
            $uri = New-SourceFile 'list.yaml' @'
version: 1.0
root:
  - type: step
    name: First
    slug: first
    plugin: TextOutput
  - type: step
    name: Second
    slug: second
    plugin: TextOutput
'@
            $plugin = New-OverlayPlugin $uri

            $result = $plugin.Execute()

            $result.queuedSlugs | Should -Contain 'first'
            $result.queuedSlugs | Should -Contain 'second'

            $pendingOverlays = [PendingOverlays]::GetInstance()
            $pendingOverlays.HasOverlay('first') | Should -BeTrue
            $pendingOverlays.HasOverlay('second') | Should -BeTrue
        }

        It 'Should set the loaded variables through the Api' {
            $uri = New-SourceFile 'with-variables.yaml' @'
version: 1.0
variables:
  overlaidUser: Ada
'@
            $plugin = New-OverlayPlugin $uri

            $plugin.Execute() | Out-Null

            [Variables]::GetInstance().Get('overlaidUser') | Should -Be 'Ada'
        }

        It 'Should not require a root section' {
            $uri = New-SourceFile 'variables-only.yaml' @'
version: 1.0
variables:
  onlyVariable: yes
'@
            $plugin = New-OverlayPlugin $uri

            { $plugin.Execute() } | Should -Not -Throw
            [PendingOverlays]::GetInstance().Count() | Should -Be 0
        }

        It 'Should not require a variables section' {
            $uri = New-SourceFile 'root-only.yaml' @'
version: 1.0
root:
  type: step
  name: Replacement step
  slug: target
  plugin: TextOutput
'@
            $plugin = New-OverlayPlugin $uri

            { $plugin.Execute() } | Should -Not -Throw
        }

        It 'Should not insert anything - only queue overlays' {
            $uri = New-SourceFile 'no-insert.yaml' @'
version: 1.0
root:
  type: step
  name: Replacement step
  slug: target
  plugin: TextOutput
'@
            $plugin = New-OverlayPlugin $uri

            $plugin.Execute() | Out-Null

            $plugin.Api.Configuration.GetPendingInserts().Count | Should -Be 0
        }

        It 'Should surface a failure to load the source through RunTask()' {
            $plugin = New-OverlayPlugin (Join-Path $TestDrive 'missing.yaml')

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
            $result.error | Should -Not -BeNullOrEmpty
        }

        It 'Should surface a mismatched/missing slug through RunTask() rather than throwing directly' {
            $uri = New-SourceFile 'no-slug.yaml' @'
version: 1.0
root:
  type: step
  name: No slug here
  plugin: TextOutput
'@
            $plugin = New-OverlayPlugin $uri

            $result = $plugin.RunTask()

            $result.success | Should -BeFalse
            $result.error | Should -Not -BeNullOrEmpty
        }
    }
}
