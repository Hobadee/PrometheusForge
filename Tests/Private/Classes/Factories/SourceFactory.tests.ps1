Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'SourceFactory' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; make sure the plugin these tests rely on exists.
        [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])
        [sourcePluginRegistry]::GetInstance().RegisterPlugin([yamlSource])

        function New-SourceFile {
            # Writes a YAML document into TestDrive and returns its file URI.
            param([string] $Name, [string] $Content)
            $path = Join-Path $TestDrive $Name
            $Content | Set-Content -Path $path -Encoding utf8
            return [System.Uri]::new($path).AbsoluteUri
        }

        function New-SourceConfig {
            param([string] $Uri, [hashtable] $Extra = @{})
            $config = [ordered]@{ sourcePlugin = 'yamlSource'; uri = $Uri }
            foreach ($key in $Extra.Keys) { $config[$key] = $Extra[$key] }
            return [pscustomobject]$config
        }
    }

    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    AfterAll {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    Context 'Validation' {
        It 'throws when sourcePlugin is missing or blank: <Description>' -ForEach @(
            @{ Description = 'missing'; Config = [pscustomobject]@{ uri = 'file.yaml' } }
            @{ Description = 'empty'; Config = [pscustomobject]@{ sourcePlugin = ''; uri = 'file.yaml' } }
            @{ Description = 'whitespace'; Config = [pscustomobject]@{ sourcePlugin = '   '; uri = 'file.yaml' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { [SourceFactory]::Create($Config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when uri is missing or blank: <Description>' -ForEach @(
            @{ Description = 'missing'; Config = [pscustomobject]@{ sourcePlugin = 'yamlSource' } }
            @{ Description = 'empty'; Config = [pscustomobject]@{ sourcePlugin = 'yamlSource'; uri = '' } }
            @{ Description = 'whitespace'; Config = [pscustomobject]@{ sourcePlugin = 'yamlSource'; uri = '   ' } }
        ) {
            $exceptionType = [System.ArgumentException]

            { [SourceFactory]::Create($Config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when uri only expands to an empty string' {
            $config = [pscustomobject]@{ sourcePlugin = 'yamlSource'; uri = '{{ undefinedVariable }}' }
            $exceptionType = [System.ArgumentException]

            { [SourceFactory]::Create($config) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'throws when the source plugin is not registered' {
            $config = [pscustomobject]@{ sourcePlugin = 'noSuchSource'; uri = 'file.yaml' }
            $exceptionType = [System.ArgumentException]

            { [SourceFactory]::Create($config) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Loading a section' {
        BeforeEach {
            $script:sectionUri = New-SourceFile 'section.yaml' @'
version: 1.0
variables:
  importedName: Ada
root:
  type: section
  name: Imported root
  slug: imported-root
  items:
    - type: step
      name: Greet
      slug: greet
      plugin: TextOutput
      parameters:
        message: hello
        level: Trace
'@
        }

        It 'returns a StepTree built from the loaded root' {
            $tree = [SourceFactory]::Create((New-SourceConfig $script:sectionUri))

            ($tree -is [StepTree]) | Should -BeTrue
            $tree.slug | Should -Be 'imported-root'
            $tree.name | Should -Be 'Imported root'
            $tree.Count() | Should -Be 1
            [Steps]::GetInstance().Exists('greet') | Should -BeTrue
        }

        It 'merges the loaded variables into Variables' {
            [SourceFactory]::Create((New-SourceConfig $script:sectionUri)) | Out-Null

            [Variables]::GetInstance().Get('importedName') | Should -Be 'Ada'
        }

        It 'expands templates in the uri' {
            [Variables]::GetInstance().Set('importUri', $script:sectionUri)

            $tree = [SourceFactory]::Create((New-SourceConfig '{{ importUri }}'))

            $tree.slug | Should -Be 'imported-root'
        }
    }

    Context 'Wrapping imported content in a synthetic section' {
        It 'wraps a bare list of items using the import item''s name and slug' {
            $uri = New-SourceFile 'list.yaml' @'
version: 1.0
root:
  - type: step
    name: First
    slug: first
    plugin: TextOutput
    parameters:
      message: one
      level: Trace
  - type: step
    name: Second
    slug: second
    plugin: TextOutput
    parameters:
      message: two
      level: Trace
'@

            $tree = [SourceFactory]::Create((New-SourceConfig $uri @{ name = 'My import'; slug = 'my-import' }))

            $tree.name | Should -Be 'My import'
            $tree.slug | Should -Be 'my-import'
            $tree.Count() | Should -Be 2
            [Steps]::GetInstance().Exists('first') | Should -BeTrue
            [Steps]::GetInstance().Exists('second') | Should -BeTrue
        }

        It 'falls back to a default name and slug when wrapping a list without them' {
            $uri = New-SourceFile 'list-defaults.yaml' @'
version: 1.0
root:
  - type: section
    name: Child one
    slug: child-one
  - type: section
    name: Child two
    slug: child-two
'@

            $tree = [SourceFactory]::Create((New-SourceConfig $uri))

            $tree.name | Should -Be 'Imported section'
            $tree.slug | Should -Be 'imported-section'
            $tree.Count() | Should -Be 2
        }

        It 'ignores non-string name and slug values on the import item when wrapping a list' {
            $uri = New-SourceFile 'list-nonstring.yaml' @'
version: 1.0
root:
  - type: section
    name: Child one
    slug: child-one
  - type: section
    name: Child two
    slug: child-two
'@

            $tree = [SourceFactory]::Create((New-SourceConfig $uri @{ name = 42; slug = 7 }))

            $tree.name | Should -Be 'Imported section'
            $tree.slug | Should -Be 'imported-section'
        }

        It 'wraps a single step in a section named after the step' {
            $uri = New-SourceFile 'step.yaml' @'
version: 1.0
root:
  type: step
  name: Lone step
  slug: lone-step
  plugin: TextOutput
  parameters:
    message: alone
    level: Trace
'@

            $tree = [SourceFactory]::Create((New-SourceConfig $uri))

            $tree.name | Should -Be 'Lone step'
            $tree.slug | Should -Be 'lone-step'
            $tree.Count() | Should -Be 1
            [Steps]::GetInstance().Exists('lone-step') | Should -BeTrue
        }

        It 'falls back to a default name and slug when the wrapped step has neither' {
            $uri = New-SourceFile 'step-anonymous.yaml' @'
version: 1.0
root:
  type: step
  plugin: TextOutput
  parameters:
    message: anonymous
    level: Trace
'@

            # The wrapper section gets the defaults; the step inside still needs a valid slug of its own.
            $exceptionType = [System.ArgumentException]
            { [SourceFactory]::Create((New-SourceConfig $uri)) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Documents without a root' {
        It 'throws because the whole document is not a valid tree node' {
            $uri = New-SourceFile 'variables-only.yaml' @'
version: 1.0
variables:
  onlyVariables: true
'@
            $exceptionType = [System.ArgumentException]

            { [SourceFactory]::Create((New-SourceConfig $uri)) } | Should -Throw -ExceptionType $exceptionType
        }
    }
}
