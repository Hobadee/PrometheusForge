Using Module "../../../build/Lifecycle/Lifecycle.psd1"

Describe 'TemplateEngine' {
    BeforeEach {
        [Configuration]::Instance = $null
        [Configuration]::KeyValueStore = $null
        [Configuration]::IncludeTags = $null
        [Configuration]::ExcludeTags = $null
    }

    Context 'ExpandString' {
        It 'expands a single token' {
            $configuration = [Configuration]::GetInstance()
            $configuration.Set('userName', 'ada')

            $result = [TemplateEngine]::ExpandString('hello {{userName}}', $configuration)

            $result | Should -Be 'hello ada'
        }

        It 'expands multiple tokens in one string' {
            $configuration = [Configuration]::GetInstance()
            $configuration.Set('firstName', 'Ada')
            $configuration.Set('lastName', 'Lovelace')

            $result = [TemplateEngine]::ExpandString('{{firstName}} {{lastName}}', $configuration)

            $result | Should -Be 'Ada Lovelace'
        }

        It 'expands nested paths from mixed hashtable and object values' {
            $configuration = [Configuration]::GetInstance()
            $configuration.Set('pin', @{
                object = [pscustomobject]@{
                    generatedPassword = 'P@55'
                }
            })

            $result = [TemplateEngine]::ExpandString('password={{pin.object.generatedPassword}}', $configuration)

            $result | Should -Be 'password=P@55'
        }

        It 'replaces missing values with empty strings' {
            $configuration = [Configuration]::GetInstance()

            $result = [TemplateEngine]::ExpandString('missing={{doesNotExist}}', $configuration)

            $result | Should -Be 'missing='
        }
    }

    Context 'ExpandTopLevelValues' {
        It 'expands only top-level string values in hashtables' {
            $configuration = [Configuration]::GetInstance()
            $configuration.Set('userName', 'ada')

            $parameters = @{
                message = 'hello {{userName}}'
                length = 20
                nested = @{
                    note = '{{userName}}'
                }
            }

            $expanded = [TemplateEngine]::ExpandTopLevelValues($parameters, $configuration)

            $expanded.message | Should -Be 'hello ada'
            $expanded.length | Should -Be 20
            $expanded.nested.note | Should -Be '{{userName}}'
        }

        It 'expands only top-level string properties in pscustomobjects' {
            $configuration = [Configuration]::GetInstance()
            $configuration.Set('department', 'IT')

            $parameters = [pscustomobject]@{
                message = 'Dept {{department}}'
                retries = 3
                nested = [pscustomobject]@{
                    label = '{{department}}'
                }
            }

            $expanded = [TemplateEngine]::ExpandTopLevelValues($parameters, $configuration)

            $expanded.message | Should -Be 'Dept IT'
            $expanded.retries | Should -Be 3
            $expanded.nested.label | Should -Be '{{department}}'
        }
    }
}
