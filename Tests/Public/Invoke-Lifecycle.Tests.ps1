BeforeAll {
    Remove-Module Lifecycle -ErrorAction SilentlyContinue
    $modulePath = Join-Path $PSScriptRoot '..\..\build\Lifecycle\Lifecycle.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-Lifecycle' {
    It 'runs the items when FilePath is an absolute YAML path' {
        $yamlPath = Join-Path $TestDrive 'workflow-absolute.yaml'
        @'
name: Test workflow absolute
version: 1.0
root:
  - type: section
    name: Root section
    items:
      - type: step
        name: Write output
        plugin: TextOutput
        parameters:
          message: hello from absolute path
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath

        $result | Should -BeTrue
    }

    It 'runs the items when FilePath is a relative YAML path' {
        $yamlPath = Join-Path $TestDrive 'workflow-relative.yaml'
        @'
name: Test workflow relative
version: 1.0
root:
  - type: section
    name: Root section
    items:
      - type: step
        name: Write output
        plugin: TextOutput
        parameters:
          message: hello from relative path
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $relativePath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $yamlPath)
        $result = Invoke-Lifecycle -FilePath $relativePath

        $result | Should -BeTrue
    }

    It 'runs the items from a readable YAML file' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    items:
      - type: step
        name: Write output
        plugin: TextOutput
        parameters:
          message: hello from lifecycle
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath

        $result | Should -BeTrue
    }

    It 'throws when the YAML file does not exist' {
        $missingPath = Join-Path $TestDrive 'missing.yaml'

        { Invoke-Lifecycle -FilePath $missingPath } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
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
    items:
      - type: step
        name: Write output
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

        $result = Invoke-Lifecycle -FilePath $yamlPath -Overlay $overlayOnePath, $overlayTwoPath

        $result | Should -BeTrue

        $configuration = Test-Variables
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
    items:
      - type: step
        name: Write output
        plugin: TextOutput
        parameters:
          message: hello from lifecycle
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $missingOverlayPath = Join-Path $TestDrive 'overlay-missing.yaml'

        {
            Invoke-Lifecycle -FilePath $yamlPath -Overlay $missingOverlayPath
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
    items:
      - type: step
        name: Templated output
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

        $result = Invoke-Lifecycle -FilePath $yamlPath -Overlay $overlayPath

        $result | Should -BeTrue

        $configuration = Test-Variables
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
    items:
      - type: step
        name: Templated output
        plugin: TextOutput
        result: outputResult
        parameters:
          - message: "User={{fullName}}"
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath

        $result | Should -BeTrue

        $configuration = Test-Variables
        $stepResult = $configuration.Get('outputResult')
        $stepResult.success | Should -BeTrue
        $stepResult.object.parameters.message | Should -Be 'User=Ada Lovelace'
    }

    It 'imports another YAML file as a section item when the item type is import' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        $importedPath = Join-Path $TestDrive 'imported.yaml'
        @'
name: Imported workflow
version: 1.0
root:
  - type: section
    name: Imported section
    items:
      - type: step
        name: Imported step
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
    items:
      - type: import
        name: Imported workflow
        sourcePlugin: yamlSource
        uri: "$importUri"
      - type: step
        name: Tail step
        plugin: TextOutput
        result: tailResult
        parameters:
          message: trailing
"@ | Set-Content -Path $yamlPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath

        $result | Should -BeTrue

        $configuration = Test-Variables
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
'@ | Set-Content -Path $importedPath -Encoding utf8

        $importUri = [System.Uri]::new($importedPath).AbsoluteUri
        @"
name: Test workflow
version: 1.0
root:
  - type: section
    name: Root section
    items:
      - type: import
        name: Imported workflow
        sourcePlugin: yamlSource
        uri: "$importUri"
      - type: step
        name: Tail step
        plugin: TextOutput
        result: importedVariableResult
        parameters:
          message: "User={{importedUser}}"
"@ | Set-Content -Path $yamlPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath

        $result | Should -BeTrue

        $configuration = Test-Variables
        $configuration.Get('importedVariableResult').success | Should -BeTrue
        $configuration.Get('importedVariableResult').object.parameters.message | Should -Be 'User=Ada Lovelace'
    }
}

