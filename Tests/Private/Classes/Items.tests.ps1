Using Module "../../../build/Lifecycle/Lifecycle.psd1"

class TestItemForItemSection : ItemInterface {
    [bool] $WasRun = $false
    [bool] $ReturnValue = $true

    TestItemForItemSection([object]$config) : base($config) {
    }

    [bool] DoItem() {
        $this.WasRun = $true
        return $this.ReturnValue
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
        It 'Should invoke DoItem on the current item (default index 0)' {
            $section = [ItemSection]::new([pscustomobject]@{ name = 'root'; type = 'section' })
            $first = [TestItemForItemSection]::new([pscustomobject]@{ name = 'first' })
            $second = [TestItemForItemSection]::new([pscustomobject]@{ name = 'second' })

            $section.Add($first)
            $section.Add($second)

            $result = $section.InvokeCurrentItem()

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

            $result = $section.InvokeCurrentItem()

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
            { $section.InvokeCurrentItem() } | Should -Throw -ExceptionType $exceptionType
        }
    }
}
