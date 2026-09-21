Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'TemplateEngine' {
    BeforeEach {
        [Variables]::Reset()
    }

    Context 'ExpandString' {
        It 'expands a single token' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('userName', 'ada')

            $result = [TemplateEngine]::ExpandString('hello {{userName}}', $configuration)

            $result | Should -Be 'hello ada'
        }

        It 'expands multiple tokens in one string' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('firstName', 'Ada')
            $configuration.Set('lastName', 'Lovelace')

            $result = [TemplateEngine]::ExpandString('{{firstName}} {{lastName}}', $configuration)

            $result | Should -Be 'Ada Lovelace'
        }

        It 'expands nested paths from mixed hashtable and object values' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('pin', @{
                object = [pscustomobject]@{
                    generatedPassword = 'P@55'
                }
            })

            $result = [TemplateEngine]::ExpandString('password={{pin.object.generatedPassword}}', $configuration)

            $result | Should -Be 'password=P@55'
        }

        It 'replaces missing values with empty strings' {
            $configuration = [Variables]::GetInstance()

            $result = [TemplateEngine]::ExpandString('missing={{doesNotExist}}', $configuration)

            $result | Should -Be 'missing='
        }

        It 'preserves the default string representation of hashtables' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('payload', @{ name = 'Ada' })

            $result = [TemplateEngine]::ExpandString('payload={{payload}}', $configuration)

            $result | Should -Be 'payload=System.Collections.Hashtable'
        }

        It 'renders hashtables as compact JSON when configured' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('templateHashtableFormat', 'json')
            $configuration.Set('payload', @{ name = 'Ada' })

            $result = [TemplateEngine]::ExpandString('payload={{payload}}', $configuration)

            $result | Should -Be 'payload={"name":"Ada"}'
        }
    }

    Context 'ExpandTopLevelValues' {
        It 'expands only top-level string values in hashtables' {
            $configuration = [Variables]::GetInstance()
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

        It 'expands string items in top-level hashtable arrays' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('userName', 'ada')
            $configuration.Set('role', 'developer')

            $parameters = @{
                items = @('{{userName}}', '{{role}}')
            }

            $expanded = [TemplateEngine]::ExpandTopLevelValues($parameters, $configuration)

            $expanded.items | Should -Be @('ada', 'developer')
        }

        It 'expands only top-level string properties in pscustomobjects' {
            $configuration = [Variables]::GetInstance()
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

        It 'expands string items in top-level pscustomobject arrays' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('firstName', 'Ada')
            $configuration.Set('lastName', 'Lovelace')

            $parameters = [pscustomobject]@{
                items = @('{{firstName}}', '{{lastName}}')
            }

            $expanded = [TemplateEngine]::ExpandTopLevelValues($parameters, $configuration)

            $expanded.items | Should -Be @('Ada', 'Lovelace')
        }

        It 'expands top-level string values inside sample-style parameter lists' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('fullName', 'Ada Lovelace')

            $parameters = [System.Collections.Generic.List[object]]::new()
            $parameters.Add([pscustomobject]@{
                message = 'Hello {{fullName}}'
                nested = [pscustomobject]@{
                    label = '{{fullName}}'
                }
            })

            $expanded = [TemplateEngine]::ExpandTopLevelValues($parameters, $configuration)

            $expanded.Count | Should -Be 1
            $expanded[0].message | Should -Be 'Hello Ada Lovelace'
            $expanded[0].nested.label | Should -Be '{{fullName}}'
        }
    }
}

