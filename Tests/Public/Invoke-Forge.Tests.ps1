Using Module "../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../Helpers/ConsoleCapture.ps1')
    Remove-Module PrometheusForge -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-Forge' {
    BeforeEach {
        # Reset singleton instances before each test
        [Variables]::Reset()
        [Steps]::Reset()
    }

    It 'runs the items when FilePath is an absolute YAML path' {
        $yamlPath = Join-Path $TestDrive 'workflow-absolute.yaml'
        @'
name: Test workflow absolute
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from absolute path
'@ | Set-Content -Path $yamlPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath
    }

    It 'runs the items when FilePath is a relative YAML path' {
        $yamlPath = Join-Path $TestDrive 'workflow-relative.yaml'
        @'
name: Test workflow relative
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from relative path
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $relativePath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $yamlPath)
        Invoke-Forge -FilePath $relativePath
    }

    It 'runs the items when FilePath is a relative YAML path from the invocation directory' {
        $workDir = Join-Path $TestDrive 'invocation-root'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null

        $yamlPath = Join-Path $workDir 'workflow-relative-from-cwd.yaml'
        @'
name: Test workflow relative from cwd
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from invocation directory
'@ | Set-Content -Path $yamlPath -Encoding utf8

        Push-Location $workDir
        try {
            Invoke-Forge -FilePath 'workflow-relative-from-cwd.yaml'
        }
        finally {
            Pop-Location
        }
    }

    It 'runs the items from a readable YAML file' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from lifecycle
'@ | Set-Content -Path $yamlPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath
    }

    It 'throws when the YAML file does not exist' {
        $missingPath = Join-Path $TestDrive 'missing.yaml'

        { Invoke-Forge -FilePath $missingPath } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
    }

    It 'loads base variables and applies overlays in provided order' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
variables:
  userName: base-user
  retries: 1
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from lifecycle
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $overlayOnePath = Join-Path $TestDrive 'overlay-1.yaml'
        @'
name: overlay one
version: 1.0
variables:
  userName: overlay-one-user
  department: IT
'@ | Set-Content -Path $overlayOnePath -Encoding utf8

        $overlayTwoPath = Join-Path $TestDrive 'overlay-2.yaml'
        @'
name: overlay two
version: 1.0
variables:
  userName: overlay-two-user
  retries: 3
'@ | Set-Content -Path $overlayTwoPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath -Overlay $overlayOnePath, $overlayTwoPath

        $configuration = [Variables]::GetInstance()
        $configuration.Get('userName') | Should -Be 'overlay-two-user'
        $configuration.Get('department') | Should -Be 'IT'
        $configuration.Get('retries') | Should -Be 3
    }

    It 'throws when an overlay YAML file does not exist' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Write output
        slug: write-output
        plugin: TextOutput
        parameters:
          message: hello from lifecycle
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $missingOverlayPath = Join-Path $TestDrive 'overlay-missing.yaml'

        {
            Invoke-Forge -FilePath $yamlPath -Overlay $missingOverlayPath
        } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
    }

    It 'expands templated step parameters using base and overlay variables' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
variables:
  userName: base-user
  department: base-department
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Templated output
        slug: templated-output
        plugin: TextOutput
        result: outputResult
        parameters:
          message: "User={{userName}} Department={{department}}"
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $overlayPath = Join-Path $TestDrive 'overlay.yaml'
        @'
name: overlay
version: 1.0
variables:
  userName: overlay-user
'@ | Set-Content -Path $overlayPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath -Overlay $overlayPath

        $configuration = [Variables]::GetInstance()
        $stepResult = $configuration.Get('outputResult')
        $stepResult.success | Should -BeTrue
        $stepResult.object.parameters.message | Should -Be 'User=overlay-user Department=base-department'
    }

    It 'expands templated step parameters when YAML parameters use the sample list syntax' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
variables:
  fullName: Ada Lovelace
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Templated output
        slug: templated-output
        plugin: TextOutput
        result: outputResult
        parameters:
          message: "User={{fullName}}"
'@ | Set-Content -Path $yamlPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath

        $configuration = [Variables]::GetInstance()
        $stepResult = $configuration.Get('outputResult')
        $stepResult.success | Should -BeTrue
        $stepResult.object.parameters.message | Should -Be 'User=Ada Lovelace'
    }

    It 'imports another YAML file using the ImportConfig plugin' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        $importedPath = Join-Path $TestDrive 'imported.yaml'
        @'
name: Imported workflow
version: 1.0
root:
  - type: section
    name: Imported section
    slug: imported-section
    items:
      - type: step
        name: Imported step
        slug: imported-step
        plugin: TextOutput
        result: importedResult
        parameters:
          message: imported
'@ | Set-Content -Path $importedPath -Encoding utf8

        $importUri = [System.Uri]::new($importedPath).AbsoluteUri
        @"
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Imported workflow
        slug: imported-workflow
        plugin: ImportConfig
        parameters:
          sourcePluginName: yamlSource
          uri: "$importUri"
      - type: step
        name: Tail step
        slug: tail-step
        plugin: TextOutput
        result: tailResult
        parameters:
          message: trailing
"@ | Set-Content -Path $yamlPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath

        $configuration = [Variables]::GetInstance()
        $configuration.Get('importedResult').success | Should -BeTrue
        $configuration.Get('tailResult').success | Should -BeTrue
    }

    It 'loads variables from an imported YAML file before creating later sibling steps' {
        $yamlPath = Join-Path $TestDrive 'workflow-with-imported-variables.yaml'
        $importedPath = Join-Path $TestDrive 'imported-with-variables.yaml'
        @'
name: Imported workflow
version: 1.0
variables:
  importedUser: Ada Lovelace
root:
  type: section
  name: Imported section
  slug: imported-section
'@ | Set-Content -Path $importedPath -Encoding utf8

        $importUri = [System.Uri]::new($importedPath).AbsoluteUri
        @"
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    slug: root-section
    items:
      - type: step
        name: Imported workflow
        slug: imported-workflow
        plugin: ImportConfig
        parameters:
          sourcePluginName: yamlSource
          uri: "$importUri"
      - type: step
        name: Tail step
        slug: tail-step
        plugin: TextOutput
        result: importedVariableResult
        parameters:
          message: "User={{importedUser}}"
        defer_binding: true
"@ | Set-Content -Path $yamlPath -Encoding utf8

        Invoke-Forge -FilePath $yamlPath

        $configuration = [Variables]::GetInstance()
        $configuration.Get('importedVariableResult').success | Should -BeTrue
        $configuration.Get('importedVariableResult').object.parameters.message | Should -Be 'User=Ada Lovelace'
    }
}


Describe 'Invoke-Forge options' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; re-import so the built-in plugins are registered.
        Remove-Module PrometheusForge -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1') -Force

        function New-Workflow {
            param([string] $Name, [string] $Content)
            $path = Join-Path $TestDrive $Name
            $Content | Set-Content -Path $path -Encoding utf8
            return $path
        }

        $script:simpleWorkflow = New-Workflow 'simple.yaml' @'
name: Simple workflow
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Write output
      slug: write-output
      plugin: TextOutput
      parameters:
        message: hello
        method: Trace
'@
    }

    BeforeEach {
        [Variables]::Reset()
        [Steps]::Reset()

        # Keep terminal log output from leaking into the Pester output.
        $script:writer = Start-ConsoleCapture
    }

    AfterEach {
        [void] (Stop-ConsoleCapture $script:writer)
    }

    AfterAll {
        [Variables]::Reset()
        [Steps]::Reset()
        [Log]::Reset()
    }

    Context 'Logging switches' {
        It 'leaves the terminal log level unset by default' {
            Invoke-Forge -FilePath $script:simpleWorkflow

            [Variables]::GetInstance().HasKey('logTerminalLevel') | Should -BeFalse
        }

        It 'uses the Info level for -Verbose' {
            Invoke-Forge -FilePath $script:simpleWorkflow -Verbose 4>$null

            [Variables]::GetInstance().Get('logTerminalLevel') | Should -Be 'Info'
        }

        It 'uses the Debug level for -Debug' {
            Invoke-Forge -FilePath $script:simpleWorkflow -Debug 5>$null

            [Variables]::GetInstance().Get('logTerminalLevel') | Should -Be 'Debug'
        }

        It 'uses the Trace level for -Verbose together with -Debug' {
            Invoke-Forge -FilePath $script:simpleWorkflow -Verbose -Debug 4>$null 5>$null

            [Variables]::GetInstance().Get('logTerminalLevel') | Should -Be 'Trace'
        }

        It 'writes log entries at the selected level to the terminal' {
            Invoke-Forge -FilePath $script:simpleWorkflow -Verbose 4>$null

            $script:writer.ToString() | Should -Match '\[INFO\] Loading configuration from'
        }
    }

    Context 'OutputLogs' {
        It 'returns nothing by default' {
            Invoke-Forge -FilePath $script:simpleWorkflow | Should -BeNullOrEmpty
        }

        It 'returns the recorded log entries when -OutputLogs is set' {
            $entries = @(Invoke-Forge -FilePath $script:simpleWorkflow -OutputLogs)

            $entries.Count | Should -BeGreaterThan 0
            $messages = $entries | ForEach-Object { $_.GetMessage() }
            $messages | Should -Contain "Loading configuration from '$script:simpleWorkflow'."
        }
    }

    Context 'Configuration handling' {
        It 'throws when the workflow has no root section' {
            $path = New-Workflow 'no-root.yaml' @'
name: No root
version: 1.0
variables:
  onlyVariables: true
'@
            $exceptionType = [System.ArgumentException]

            { Invoke-Forge -FilePath $path } | Should -Throw -ExceptionType $exceptionType
        }

        It 'gives -Variables precedence over the workflow and overlay variables' {
            $path = New-Workflow 'precedence.yaml' @'
name: Precedence
version: 1.0
variables:
  level: from-workflow
  onlyInWorkflow: kept
root:
  type: section
  name: Root section
  slug: root-section
'@
            $overlay = New-Workflow 'precedence-overlay.yaml' @'
name: Overlay
version: 1.0
variables:
  level: from-overlay
'@

            Invoke-Forge -FilePath $path -Overlay $overlay -Variables @{ level = 'from-parameter' }

            [Variables]::GetInstance().Get('level') | Should -Be 'from-parameter'
            [Variables]::GetInstance().Get('onlyInWorkflow') | Should -Be 'kept'
        }

        It 'resets state left over from a previous run' {
            [Variables]::GetInstance().Set('leftover', 'from previous run')

            Invoke-Forge -FilePath $script:simpleWorkflow

            [Variables]::GetInstance().HasKey('leftover') | Should -BeFalse
        }

        It 'skips steps whose tags match tagsExclude' {
            $path = New-Workflow 'tags.yaml' @'
name: Tags
version: 1.0
root:
  type: section
  name: Root section
  slug: root-section
  items:
    - type: step
      name: Always runs
      slug: always-runs
      plugin: TextOutput
      result: alwaysResult
      parameters:
        message: always
        method: Trace
    - type: step
      name: Skipped
      slug: skipped
      plugin: TextOutput
      result: skippedResult
      tags: [skipme]
      parameters:
        message: skipped
        method: Trace
'@

            Invoke-Forge -FilePath $path -Variables @{ tagsExclude = @('skipme') }

            [Variables]::GetInstance().HasKey('alwaysResult') | Should -BeTrue
            [Variables]::GetInstance().HasKey('skippedResult') | Should -BeFalse
        }
    }
}
