Using Module "../../../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'yamlSource' {
    It 'exposes metadata and stores a file URI' {
        $yamlPath = Join-Path $TestDrive 'metadata.yaml'
        'name: metadata-test' | Set-Content -Path $yamlPath -Encoding utf8

        $plugin = [yamlSource]::new(([uri]::new($yamlPath)).AbsoluteUri)
        $info = [yamlSource]::PluginInfo()

        $info.Name | Should -Be 'yamlSource'
        $info.Version | Should -Be '1.0.0'
        $info.Description | Should -Be 'Loads configuration data from YAML files'
        $info.Author | Should -Be 'Eric Kincl'
        $plugin.URI.IsFile | Should -BeTrue
        $plugin.URI.LocalPath | Should -Be $yamlPath
    }

    It 'loads YAML configuration data from a file URI' {
        $yamlPath = Join-Path $TestDrive 'config.yaml'
        @'
version: 1.0
name: source-config
value: 42
variables:
    region: us-east-1
root:
    name: root-node
nested:
  enabled: true
'@ | Set-Content -Path $yamlPath -Encoding utf8

        $plugin = [yamlSource]::new(([uri]::new($yamlPath)).AbsoluteUri)

        $result = $plugin.Load()

        $result | Should -BeOfType ([System.Collections.Hashtable])
        $result.version | Should -Be 1.0
        $result.name | Should -Be 'source-config'
        $result.value | Should -Be 42
        $result.variables.region | Should -Be 'us-east-1'
        $result.root.name | Should -Be 'root-node'
        $result.nested.enabled | Should -BeTrue
    }

    It 'loads YAML from a relative path using the current PowerShell working directory' {
        $cwd = Join-Path $TestDrive 'working-directory'
        New-Item -ItemType Directory -Path $cwd -Force | Out-Null

        $yamlPath = Join-Path $cwd 'relative-config.yaml'
        @'
version: 1.0
name: relative-config
variables:
    region: us-west-2
root:
    name: root-node
'@ | Set-Content -Path $yamlPath -Encoding utf8

        Push-Location $cwd
        try {
            $plugin = [yamlSource]::new('relative-config.yaml')
            $result = $plugin.Load()

            $result.name | Should -Be 'relative-config'
            $result.variables.region | Should -Be 'us-west-2'
            $result.root.name | Should -Be 'root-node'
        }
        finally {
            Pop-Location
        }
    }

    It 'throws when the source file does not exist' {
        $missingPath = Join-Path $TestDrive 'missing.yaml'

        $exceptionType = [System.IO.FileNotFoundException]
        { [yamlSource]::new($missingPath) } | Should -Throw -ExceptionType $exceptionType
    }
}
