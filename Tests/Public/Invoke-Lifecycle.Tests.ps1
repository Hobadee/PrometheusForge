BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\build\Lifecycle\Lifecycle.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-Lifecycle' {
    It 'runs the items from a readable YAML file' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
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
variables:
  userName: overlay-one-user
  department: IT
'@ | Set-Content -Path $overlayOnePath -Encoding utf8

        $overlayTwoPath = Join-Path $TestDrive 'overlay-2.yaml'
        @'
name: overlay two
variables:
  userName: overlay-two-user
  retries: 3
'@ | Set-Content -Path $overlayTwoPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath -Overlay $overlayOnePath, $overlayTwoPath

        $result | Should -BeTrue

        $configuration = Test-Configuration
        $configuration.Get('userName') | Should -Be 'overlay-two-user'
        $configuration.Get('department') | Should -Be 'IT'
        $configuration.Get('retries') | Should -Be 3
    }

    It 'throws when an overlay YAML file does not exist' {
        $yamlPath = Join-Path $TestDrive 'workflow.yaml'
        @'
name: Test workflow
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
variables:
  userName: overlay-user
'@ | Set-Content -Path $overlayPath -Encoding utf8

        $result = Invoke-Lifecycle -FilePath $yamlPath -Overlay $overlayPath

        $result | Should -BeTrue

        $configuration = Test-Configuration
        $stepResult = $configuration.Get('outputResult')
        $stepResult.success | Should -BeTrue
        $stepResult.object.parameters.message | Should -Be 'User=overlay-user Department=base-department'
    }
}
