Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

BeforeAll {
    . (Join-Path $PSScriptRoot '../../Helpers/ConsoleCapture.ps1')

    # Steps log through [System.Console]::Out, which Pester does not capture; discard it so
    # expected warnings and errors from these tests don't clutter the test output.
    $script:capture = Start-ConsoleCapture
}

AfterAll {
    [void] (Stop-ConsoleCapture $script:capture)
}


Describe 'StepTree configuration overrides' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'replaces a matching step with the requested step configuration' {
        $rootConfig = @{
            type = 'section'
            name = 'Root'
            slug = 'root'
            items = @(
                @{
                    type = 'step'
                    name = 'Request replacement'
                    slug = 'request-replacement'
                    plugin = 'TextOutput'
                    parameters = @{ message = 'requesting replacement'; method = 'Info' }
                },
                @{
                    type = 'step'
                    name = 'Target'
                    slug = 'target'
                    plugin = 'TextOutput'
                    result = 'originalResult'
                    parameters = @{ message = 'original'; method = 'Info' }
                }
            )
        }
        $replacementConfig = @{
            type = 'step'
            name = 'Target'
            slug = 'target'
            plugin = 'TextOutput'
            result = 'replacementResult'
            parameters = @{ message = 'replacement'; method = 'Info' }
        }

        $tree = [StepTree]::new($rootConfig)
        $requestingStep = [Steps]::GetInstance().Get('request-replacement')
        $requestingStep.plugin.Api.Configuration.RequestOverride('target', $replacementConfig)

        $tree.Process() | Should -BeTrue

        $configuration = [Variables]::GetInstance()
        $configuration.HasKey('originalResult') | Should -BeFalse
        $configuration.Get('replacementResult').success | Should -BeTrue
        [Steps]::GetInstance().Get('target').config.parameters.message | Should -Be 'replacement'
    }
}

Describe 'StepTree tags' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'populates tags from the item config' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('a', 'b') })
        $tree.tags.GetTags() | Should -Contain 'a'
        $tree.tags.GetTags() | Should -Contain 'b'
    }

    It 'defaults to an empty tags collection when none are configured' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root' })
        $tree.tags.Count() | Should -Be 0
    }
}

Describe 'StepTree checkConditionals' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'runs when tags match neither include nor exclude' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('other') })
        [Variables]::GetInstance().AddIncludeTag('include')
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'skips when tags match exclude only' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('exclude') })
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeFalse
    }

    It 'runs when tags match include only' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('include') })
        [Variables]::GetInstance().AddIncludeTag('include')
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'runs when tags match both include and exclude and tagsPrecedence is unset' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'runs when tags match both include and exclude and tagsPrecedence is include' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        [Variables]::GetInstance().Set('tagsPrecedence', 'include')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'skips when tags match both include and exclude and tagsPrecedence is exclude' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        [Variables]::GetInstance().Set('tagsPrecedence', 'exclude')
        $tree.checkConditionals() | Should -BeFalse
    }
}

Describe 'StepTree construction' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; make sure the plugin these tests rely on exists.
        [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])
    }

    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'rejects an invalid slug: <Description>' -ForEach @(
        @{ Description = 'missing'; Slug = $null }
        @{ Description = 'empty'; Slug = '' }
        @{ Description = 'contains a space'; Slug = 'not valid' }
        @{ Description = 'not a string'; Slug = 5 }
    ) {
        $exceptionType = [System.ArgumentException]

        { [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = $Slug }) } | Should -Throw -ExceptionType $exceptionType
    }

    It 'stores the name and slug' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root' })

        $tree.name | Should -Be 'Root'
        $tree.slug | Should -Be 'root'
    }

    It 'leaves the name empty when none is configured' {
        [StepTree]::new(@{ type = 'section'; slug = 'root' }).name | Should -BeNullOrEmpty
    }

    It 'registers a Step for step nodes but not for sections' {
        $null = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @(
                @{ type = 'step'; name = 'Child'; slug = 'child'; plugin = 'TextOutput'; parameters = @{ message = 'hi'; method = 'Trace' } }
            )
        })

        [Steps]::GetInstance().Exists('child') | Should -BeTrue
        [Steps]::GetInstance().Exists('root') | Should -BeFalse
    }

    It 'builds nested children in order' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @(
                @{ type = 'section'; name = 'First'; slug = 'first'; items = @(@{ type = 'section'; name = 'Grandchild'; slug = 'grandchild' }) }
                @{ type = 'section'; name = 'Second'; slug = 'second' }
            )
        })

        $tree.Count() | Should -Be 2
        $tree.children[0].slug | Should -Be 'first'
        $tree.children[1].slug | Should -Be 'second'
        $tree.children[0].Count() | Should -Be 1
        $tree.children[0].children[0].slug | Should -Be 'grandchild'
    }

    It 'has no children when items are not configured' {
        [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root' }).Count() | Should -Be 0
    }
}

Describe 'StepTree children and enumeration' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
        $script:tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @(
                @{ type = 'section'; name = 'One'; slug = 'one' }
                @{ type = 'section'; name = 'Two'; slug = 'two' }
                @{ type = 'section'; name = 'Three'; slug = 'three' }
            )
        })
    }

    Context 'Add' {
        It 'appends a child node' {
            $script:tree.Add([StepTree]::new(@{ type = 'section'; name = 'Four'; slug = 'four' }))

            $script:tree.Count() | Should -Be 4
            $script:tree.children[3].slug | Should -Be 'four'
        }

        It 'throws when the child is null' {
            $exceptionType = [System.ArgumentNullException]

            { $script:tree.Add($null) } | Should -Throw -ExceptionType $exceptionType
            $script:tree.Count() | Should -Be 3
        }
    }

    Context 'Enumeration' {
        It 'enumerates children in insertion order' {
            $slugs = foreach ($child in $script:tree) { $child.slug }

            $slugs | Should -Be @('one', 'two', 'three')
        }

        It 'returns an enumerator over the children' {
            $enumerator = $script:tree.GetEnumerator()

            $enumerator.MoveNext() | Should -BeTrue
            $enumerator.Current.slug | Should -Be 'one'
        }
    }

    Context 'GetCurrentItem / SetCurrentIndex' {
        It 'defaults to the first child' {
            $script:tree.GetCurrentItem().slug | Should -Be 'one'
        }

        It 'selects the child at the given index' {
            $script:tree.SetCurrentIndex(2)

            $script:tree.currentIndex | Should -Be 2
            $script:tree.GetCurrentItem().slug | Should -Be 'three'
        }

        It 'rejects an index of <Index>' -ForEach @(
            @{ Index = -1 }
            @{ Index = 3 }
            @{ Index = 100 }
        ) {
            $exceptionType = [System.ArgumentOutOfRangeException]

            { $script:tree.SetCurrentIndex($Index) } | Should -Throw -ExceptionType $exceptionType
            $script:tree.currentIndex | Should -Be 0
        }

        It 'throws from GetCurrentItem when there are no children' {
            $empty = [StepTree]::new(@{ type = 'section'; name = 'Empty'; slug = 'empty' })
            $exceptionType = [System.InvalidOperationException]

            { $empty.GetCurrentItem() } | Should -Throw -ExceptionType $exceptionType
        }
    }
}

Describe 'StepTree Process' {
    BeforeAll {
        # Other test files reset the plugin registry singleton; make sure the plugins these tests rely on exists.
        $registry = [taskPluginRegistry]::GetInstance()
        $registry.RegisterPlugin([TextOutput])
        $registry.RegisterPlugin([ImportConfig])

        function New-OutputStep {
            param([string] $Slug, [string] $Result)
            return @{
                type       = 'step'
                name       = "Output $Slug"
                slug       = $Slug
                plugin     = 'TextOutput'
                result     = $Result
                parameters = @{ message = "message from $Slug"; method = 'Trace' }
            }
        }

        function New-FailingStep {
            # ImportConfig fails at execution time because the source file does not exist.
            param([string] $Slug, [string] $Result)
            return @{
                type       = 'step'
                name       = "Failing $Slug"
                slug       = $Slug
                plugin     = 'ImportConfig'
                result     = $Result
                retry      = @{ retries = 1; delay = 0 }
                parameters = @{ URI = (Join-Path $TestDrive 'does-not-exist.yaml'); SourcePluginName = 'yamlSource' }
            }
        }
    }

    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'succeeds for a section without a step of its own' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; slug = 'root' })

        $tree.Process() | Should -BeTrue
    }

    It 'runs child steps and reports success' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @((New-OutputStep 'a' 'resultA'), (New-OutputStep 'b' 'resultB'))
        })

        $tree.Process() | Should -BeTrue

        [Variables]::GetInstance().Get('resultA').success | Should -BeTrue
        [Variables]::GetInstance().Get('resultB').success | Should -BeTrue
    }

    It 'skips the node and all of its children when conditionals are not met' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @(
                @{ type = 'section'; name = 'Skipped'; slug = 'skipped'; tags = @('skip'); items = @((New-OutputStep 'inner' 'innerResult')) }
                (New-OutputStep 'outer' 'outerResult')
            )
        })
        [Variables]::GetInstance().AddExcludeTag('skip')

        $tree.Process() | Should -BeTrue

        [Variables]::GetInstance().HasKey('innerResult') | Should -BeFalse
        [Variables]::GetInstance().Get('outerResult').success | Should -BeTrue
    }

    It 'reports failure when the node''s own step fails' {
        $tree = [StepTree]::new((New-FailingStep 'broken' 'brokenResult'))

        $tree.Process() | Should -BeFalse

        [Variables]::GetInstance().Get('brokenResult').success | Should -BeFalse
    }

    It 'reports failure when a child step fails, but still runs its siblings' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @((New-FailingStep 'broken' 'brokenResult'), (New-OutputStep 'after' 'afterResult'))
        })

        $tree.Process() | Should -BeFalse

        [Variables]::GetInstance().Get('afterResult').success | Should -BeTrue
    }

    It 'propagates a nested failure up through every parent section' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @(
                @{ type = 'section'; name = 'Inner'; slug = 'inner'; items = @((New-FailingStep 'broken' 'brokenResult')) }
            )
        })

        $tree.Process() | Should -BeFalse
    }

    It 'adds API-requested inserts as children and runs them in the same pass' {
        $tree = [StepTree]::new(@{
            type  = 'section'
            name  = 'Root'
            slug  = 'root'
            items = @((New-OutputStep 'requester' 'requesterResult'))
        })
        $requester = [Steps]::GetInstance().Get('requester')
        $requester.plugin.Api.Configuration.Insert((New-OutputStep 'inserted' 'insertedResult'))

        $tree.Process() | Should -BeTrue

        [Variables]::GetInstance().Get('insertedResult').success | Should -BeTrue
        [Steps]::GetInstance().Exists('inserted') | Should -BeTrue
        $requester.plugin.Api.Configuration.GetPendingInserts().Count | Should -Be 0
    }

    Context 'requested overrides' {
        BeforeEach {
            $script:tree = [StepTree]::new(@{
                type  = 'section'
                name  = 'Root'
                slug  = 'root'
                items = @((New-OutputStep 'requester' 'requesterResult'), (New-OutputStep 'target' 'targetResult'))
            })
            $script:api = [Steps]::GetInstance().Get('requester').plugin.Api
        }

        It 'rejects an override that is not a step configuration: <Description>' -ForEach @(
            @{ Description = 'null'; Config = $null }
            @{ Description = 'a section'; Config = @{ type = 'section'; name = 'Target'; slug = 'target' } }
        ) {
            $script:api.Configuration.RequestOverride('target', $Config)
            $exceptionType = [System.NotSupportedException]

            { $script:tree.Process() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'rejects an override whose slug differs from the requested key' {
            $script:api.Configuration.RequestOverride('target', (New-OutputStep 'different' 'differentResult'))
            $exceptionType = [System.ArgumentException]

            { $script:tree.Process() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'rejects an override for a step that does not exist' {
            $script:api.Configuration.RequestOverride('ghost', (New-OutputStep 'ghost' 'ghostResult'))
            $exceptionType = [System.ArgumentException]

            { $script:tree.Process() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'clears the pending overrides once they are applied' {
            $script:api.Configuration.RequestOverride('target', (New-OutputStep 'target' 'replacedResult'))

            $script:tree.Process() | Should -BeTrue

            $script:api.Configuration.GetPendingOverrides().Count | Should -Be 0
            [Variables]::GetInstance().Get('replacedResult').success | Should -BeTrue
        }
    }
}
