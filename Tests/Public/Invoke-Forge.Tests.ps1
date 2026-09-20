Using Module "../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    Remove-Module PrometheusForge -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\PrometheusForge\PrometheusForge.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-Forge' {
    BeforeEach {
        # Reset singleton instances before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        [Steps]::Instance = $null
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

