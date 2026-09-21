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

Describe 'TemplateEngine edge cases' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; make sure the plugin these tests rely on exists.
        [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])

        function Add-TestStep {
            # Registers a step and gives it a result, as if it had already run.
            param([string] $Slug, [object] $Result)
            $step = [Step]::new(@{
                type       = 'step'
                name       = $Slug
                slug       = $Slug
                plugin     = 'TextOutput'
                parameters = @{ message = 'unused'; method = 'Trace' }
            })
            $step.result = $Result
            [Steps]::GetInstance().Add($step)
        }
    }

    BeforeEach {
        [Variables]::Reset()
        [Steps]::Reset()
    }

    AfterAll {
        [Variables]::Reset()
        [Steps]::Reset()
    }

    Context 'ExpandString' {
        It 'returns an empty string for an empty template' {
            [TemplateEngine]::ExpandString('', [Variables]::GetInstance()) | Should -Be ''
        }

        It 'returns an empty string for a null template' {
            [TemplateEngine]::ExpandString($null, [Variables]::GetInstance()) | Should -Be ''
        }

        It 'leaves text without tokens untouched' {
            [TemplateEngine]::ExpandString('no tokens here', [Variables]::GetInstance()) | Should -Be 'no tokens here'
        }
    }

    Context 'ExpandTopLevelValues' {
        It 'returns $null for a null input' {
            [TemplateEngine]::ExpandTopLevelValues($null, [Variables]::GetInstance()) | Should -BeNullOrEmpty
        }

        It 'expands a bare string' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('name', 'Ada')

            [TemplateEngine]::ExpandTopLevelValues('Hi {{ name }}', $configuration) | Should -Be 'Hi Ada'
        }

        It 'returns non-string scalars unchanged: <Description>' -ForEach @(
            @{ Description = 'integer'; Value = 42 }
            @{ Description = 'boolean'; Value = $true }
            @{ Description = 'datetime'; Value = [datetime]'2026-01-02' }
        ) {
            [TemplateEngine]::ExpandTopLevelValues($Value, [Variables]::GetInstance()) | Should -Be $Value
        }
    }

    Context 'ResolvePath' {
        It 'returns $null for an empty path' {
            [TemplateEngine]::ResolvePath('', [Variables]::GetInstance()) | Should -BeNullOrEmpty
        }

        It 'returns $null when no variables instance is supplied' {
            [TemplateEngine]::ResolvePath('anything', $null) | Should -BeNullOrEmpty
        }

        It 'returns $null when a path continues past a null value' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('nothing', $null)

            [TemplateEngine]::ResolvePath('nothing.child', $configuration) | Should -BeNullOrEmpty
        }

        It 'returns $null when a dictionary segment is missing' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('map', @{ present = 'yes' })

            [TemplateEngine]::ResolvePath('map.absent', $configuration) | Should -BeNullOrEmpty
            [TemplateEngine]::ResolvePath('map.present', $configuration) | Should -Be 'yes'
        }

        It 'returns $null when an object property segment is missing' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('obj', [pscustomobject]@{ present = 'yes' })

            [TemplateEngine]::ResolvePath('obj.absent', $configuration) | Should -BeNullOrEmpty
            [TemplateEngine]::ResolvePath('obj.present', $configuration) | Should -Be 'yes'
        }

        It 'returns $null when the path descends past a scalar value' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('scalar', 'text')

            [TemplateEngine]::ResolvePath('scalar.child.deeper', $configuration) | Should -BeNullOrEmpty
        }
    }

    Context 'step paths' {
        It 'returns $null for a bare "step" path' {
            [TemplateEngine]::ResolvePath('step', [Variables]::GetInstance()) | Should -BeNullOrEmpty
        }

        It 'returns $null for an unknown step slug' {
            [TemplateEngine]::ResolvePath('step.missing', [Variables]::GetInstance()) | Should -BeNullOrEmpty
        }

        It 'returns the whole result for step.<slug>' {
            Add-TestStep 'fetch' @{ success = $true; object = @{ value = 42 } }

            $result = [TemplateEngine]::ResolvePath('step.fetch', [Variables]::GetInstance())

            $result.success | Should -BeTrue
        }

        It 'traverses into the result for step.<slug>.<path>' {
            Add-TestStep 'fetch' @{ success = $true; object = @{ value = 42 } }
            $configuration = [Variables]::GetInstance()

            [TemplateEngine]::ResolvePath('step.fetch.success', $configuration) | Should -BeTrue
            [TemplateEngine]::ResolvePath('step.fetch.object.value', $configuration) | Should -Be 42
            [TemplateEngine]::ResolvePath('step.fetch.object.absent', $configuration) | Should -BeNullOrEmpty
        }

        It 'returns $null for a step that has not run yet' {
            Add-TestStep 'pending' $null

            [TemplateEngine]::ResolvePath('step.pending', [Variables]::GetInstance()) | Should -BeNullOrEmpty
            [TemplateEngine]::ResolvePath('step.pending.success', [Variables]::GetInstance()) | Should -BeNullOrEmpty
        }

        It 'does not resolve step paths from Variables' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('step', @{ fetch = 'from variables' })

            [TemplateEngine]::ResolvePath('step.fetch', $configuration) | Should -BeNullOrEmpty
        }

        It 'expands step results inside templates' {
            Add-TestStep 'fetch' @{ success = $true; object = @{ value = 42 } }

            $rendered = [TemplateEngine]::ExpandString('value={{ step.fetch.object.value }}', [Variables]::GetInstance())

            $rendered | Should -Be 'value=42'
        }
    }
}

