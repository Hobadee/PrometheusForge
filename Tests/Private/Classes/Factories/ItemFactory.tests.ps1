Using Module "../../../../build/PrometheusForge/PrometheusForge.psd1"

class ItemFactoryImportTemplateSource : sourcePluginInterface {
    static [string] $LastUri = $null

    ItemFactoryImportTemplateSource([string] $uri) : base($uri) {
        [ItemFactoryImportTemplateSource]::LastUri = $uri
    }

    static [hashtable] PluginInfo() {
        return @{
            Name = 'ItemFactoryImportTemplateSource'
            Version = '1.0.0'
            Description = 'Test source plugin for ItemFactory import URI templating'
        }
    }

    [bool] ValidateURI() {
        return $true
    }

    [void] doLoad() {
        $this.LoadedConfig = @{
            version = '1.0'
            root = @{
                type = 'section'
                name = 'imported section'
            }
        }
    }
}

class ItemFactoryImportVariablesSource : sourcePluginInterface {
    ItemFactoryImportVariablesSource([string] $uri) : base($uri) {
    }

    static [hashtable] PluginInfo() {
        return @{
            Name = 'ItemFactoryImportVariablesSource'
            Version = '1.0.0'
            Description = 'Test source plugin for imported variables'
        }
    }

    [bool] ValidateURI() {
        return $true
    }

    [void] doLoad() {
        $this.LoadedConfig = @{
            version = '1.0'
            variables = @{
                importedUser = 'Ada'
                importedSettings = @{
                    department = 'Research'
                }
            }
            root = @{
                type = 'section'
                name = 'imported section with variables'
            }
        }
    }
}

Describe 'ItemFactory' {
    BeforeEach {
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        [ItemFactoryImportTemplateSource]::LastUri = $null

        $registry = [sourcePluginRegistry]::GetInstance()
        if (-not $registry.IsRegistered('ItemFactoryImportTemplateSource')) {
            $registry.RegisterPlugin([ItemFactoryImportTemplateSource])
        }
        if (-not $registry.IsRegistered('ItemFactoryImportVariablesSource')) {
            $registry.RegisterPlugin([ItemFactoryImportVariablesSource])
        }
    }

    It 'expands templated import URIs before loading the source plugin' {
        $configuration = [Variables]::GetInstance()
        $sourceUri = ([uri]::new((Join-Path $TestDrive 'template-expanded-path.yaml'))).AbsoluteUri
        $configuration.Set('importPath', $sourceUri)

        $config = [pscustomobject]@{
            type = 'import'
            name = 'templated import'
            sourcePlugin = 'ItemFactoryImportTemplateSource'
            uri = '{{importPath}}'
        }

        [ItemFactory]::Create($config) | Out-Null
        [ItemFactoryImportTemplateSource]::LastUri | Should -Be $sourceUri
    }

    It 'loads imported variables into Variables before returning the imported item' {
        $configuration = [Variables]::GetInstance()

        $config = [pscustomobject]@{
            type = 'import'
            name = 'variable import'
            sourcePlugin = 'ItemFactoryImportVariablesSource'
            uri = 'memory://import-variables'
        }

        { [ItemFactory]::Create($config) | Out-Null } | Should -Not -Throw
        $configuration.Get('importedUser') | Should -Be 'Ada'
        $configuration.Get('importedSettings').department | Should -Be 'Research'
    }
}

