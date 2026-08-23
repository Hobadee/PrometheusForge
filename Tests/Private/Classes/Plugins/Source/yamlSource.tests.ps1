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

    It 'throws when the source file does not exist' {
        $missingPath = Join-Path $TestDrive 'missing.yaml'

        $exceptionType = [System.IO.FileNotFoundException]
        { [yamlSource]::new($missingPath) } | Should -Throw -ExceptionType $exceptionType
    }
}


<#
Need to test the following items:
- YAML by relative path
- YAML by absolute path
#>
