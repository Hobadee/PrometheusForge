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

Describe 'yamlSource error handling' {
    It 'throws when a relative path does not exist' {
        $exceptionType = [System.IO.FileNotFoundException]

        { [yamlSource]::new('relative-path-that-does-not-exist.yaml') } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws for a non-file URI scheme' {
        $exceptionType = [System.ArgumentException]

        { [yamlSource]::new('https://example.com/config.yaml') } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the file cannot be read' {
        $yamlPath = Join-Path $TestDrive 'unreadable.yaml'
        "version: 1.0`nvariables:`n  a: 1" | Set-Content -Path $yamlPath -Encoding utf8
        $plugin = [yamlSource]::new($yamlPath)
        Mock -ModuleName PrometheusForge -CommandName Get-Content -MockWith { throw [System.IO.IOException]::new('file is locked') }
        $exceptionType = [System.UnauthorizedAccessException]

        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the YAML document is empty' {
        $yamlPath = Join-Path $TestDrive 'empty.yaml'
        '# only a comment' | Set-Content -Path $yamlPath -Encoding utf8
        $plugin = [yamlSource]::new($yamlPath)
        $exceptionType = [System.InvalidOperationException]

        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the loaded YAML has no version' {
        $yamlPath = Join-Path $TestDrive 'no-version.yaml'
        "name: no version here`nvariables:`n  a: 1" | Set-Content -Path $yamlPath -Encoding utf8
        $plugin = [yamlSource]::new($yamlPath)
        $exceptionType = [System.InvalidOperationException]

        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }

    It 'throws when the YAML is not a mapping' {
        $yamlPath = Join-Path $TestDrive 'list.yaml'
        "- one`n- two" | Set-Content -Path $yamlPath -Encoding utf8
        $plugin = [yamlSource]::new($yamlPath)
        $exceptionType = [System.InvalidOperationException]

        { $plugin.Load() } | Should -Throw -ExceptionType $exceptionType
    }
}
