Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

class TestItemForItemSection : ItemInterface {
    [bool] $WasRun = $false
    [bool] $ReturnValue = $true

    TestItemForItemSection([object]$config) : base($config) {
    }

    [object] Process() {
        $this.WasRun = $true
        return $this.ReturnValue
    }

    [object] ProcessCurrentItem() {
        return $this.Process()
    }

    [object] ProcessAllItems() {
        return $this.Process()
    }
}

Describe 'ItemSection - Collection Behavior' {
    Context 'Add and Count' {
        It 'Should add ItemInterface implementations to the collection' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $first = [TestItemForItemSection]::new([pscustomobject]@{ name = 'first' })
            $second = [TestItemForItemSection]::new([pscustomobject]@{ name = 'second' })

            $section.Add($first)
            $section.Add($second)

            $section.Count() | Should -Be 2
        }

        It 'Should throw when adding a null item' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $exceptionType = [System.ArgumentNullException]
            { $section.Add($null) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Iterable support' {
        It 'Should provide a working enumerator' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $section.Add([TestItemForItemSection]::new([pscustomobject]@{ name = 'first' }))
            $section.Add([TestItemForItemSection]::new([pscustomobject]@{ name = 'second' }))

            $names = @()
            $enumerator = $section.GetEnumerator()
            while ($enumerator.MoveNext()) {
                $names += $enumerator.Current.name
            }

            $names.Count | Should -Be 2
            $names[0] | Should -Be 'first'
            $names[1] | Should -Be 'second'
        }
    }

    Context 'Current item execution' {
        It 'Should invoke Process on the current item (default index 0)' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $first = [TestItemForItemSection]::new([pscustomobject]@{ name = 'first' })
            $second = [TestItemForItemSection]::new([pscustomobject]@{ name = 'second' })

            $section.Add($first)
            $section.Add($second)

            $result = $section.ProcessCurrentItem()

            $result | Should -BeTrue
            $first.WasRun | Should -BeTrue
            $second.WasRun | Should -BeFalse
        }

        It 'Should execute the selected current item after SetCurrentIndex' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $first = [TestItemForItemSection]::new([pscustomobject]@{ name = 'first' })
            $second = [TestItemForItemSection]::new([pscustomobject]@{ name = 'second' })

            $section.Add($first)
            $section.Add($second)
            $section.SetCurrentIndex(1)

            $result = $section.ProcessCurrentItem()

            $result | Should -BeTrue
            $first.WasRun | Should -BeFalse
            $second.WasRun | Should -BeTrue
        }

        It 'Should throw when current index is out of range' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $section.Add([TestItemForItemSection]::new([pscustomobject]@{ name = 'only-item' }))

            $exceptionType = [System.ArgumentOutOfRangeException]
            { $section.SetCurrentIndex(2) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw when invoking current item on an empty collection' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })

            $exceptionType = [System.InvalidOperationException]
            { $section.ProcessCurrentItem() } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Full section execution' {
        It 'Should invoke all child items in order' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $first = [TestItemForItemSection]::new([pscustomobject]@{ name = 'first' })
            $second = [TestItemForItemSection]::new([pscustomobject]@{ name = 'second' })

            $section.Add($first)
            $section.Add($second)

            $result = $section.ProcessAllItems()

            $result | Should -BeTrue
            $first.WasRun | Should -BeTrue
            $second.WasRun | Should -BeTrue
        }
    }
}

Describe 'ItemStep - Template Expansion' {
    BeforeEach {
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
    }

    Context 'Constructor Parameter Expansion' {
        It 'expands top-level string parameters before plugin validation' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('userName', 'Ada')

            $stepConfig = @{
                type = 'step'
                name = 'templated output'
                plugin = 'TextOutput'
                parameters = @{
                    message = 'Hello {{userName}}'
                }
            }

            $step = [ItemStep]::new($stepConfig)

            $step.plugin.parameters.message | Should -Be 'Hello Ada'
        }

        It 'expands nested path tokens in top-level string parameters' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('pin', @{
                object = [pscustomobject]@{
                    generatedPassword = 'A1!'
                }
            })

            $stepConfig = @{
                type = 'step'
                name = 'nested template output'
                plugin = 'TextOutput'
                parameters = @{
                    message = 'Generated: {{pin.object.generatedPassword}}'
                }
            }

            $step = [ItemStep]::new($stepConfig)

            $step.plugin.parameters.message | Should -Be 'Generated: A1!'
        }

        It 'maps missing variables to empty strings' {
            [Variables]::GetInstance() | Out-Null

            $stepConfig = @{
                type = 'step'
                name = 'missing template output'
                plugin = 'TextOutput'
                parameters = @{
                    message = 'User={{missingUser}}'
                }
            }

            $step = [ItemStep]::new($stepConfig)

            $step.plugin.parameters.message | Should -Be 'User='
        }

        It 'does not recurse into nested parameter objects in MVP mode' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('department', 'IT')

            $stepConfig = @{
                type = 'step'
                name = 'non-recursive expansion'
                plugin = 'TextOutput'
                parameters = @{
                    message = 'Department {{department}}'
                    nested = @{
                        label = '{{department}}'
                    }
                }
            }

            $step = [ItemStep]::new($stepConfig)

            $step.plugin.parameters.message | Should -Be 'Department IT'
            $step.plugin.parameters.nested.label | Should -Be '{{department}}'
        }

        It 'preserves non-string top-level parameters' {
            $configuration = [Variables]::GetInstance()
            $configuration.Set('passwordLength', '24')

            $stepConfig = @{
                type = 'step'
                name = 'password config'
                plugin = 'PasswordGenerator'
                parameters = @{
                    length = 24
                    includeSpecial = $true
                }
            }

            $step = [ItemStep]::new($stepConfig)

            $step.plugin.parameters.length | Should -Be 24
            $step.plugin.parameters.includeSpecial | Should -BeTrue
        }
    }
}

