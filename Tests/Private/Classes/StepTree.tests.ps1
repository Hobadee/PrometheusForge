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


Describe 'StepTree configuration overlays' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
        [PendingOverlays]::Reset()
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
                    parameters = @{ message = 'requesting replacement'; level = 'Info' }
                },
                @{
                    type = 'step'
                    name = 'Target'
                    slug = 'target'
                    plugin = 'TextOutput'
                    result = 'originalResult'
                    parameters = @{ message = 'original'; level = 'Info' }
                }
            )
        }
        $replacementConfig = @{
            type = 'step'
            name = 'Target'
            slug = 'target'
            plugin = 'TextOutput'
            result = 'replacementResult'
            parameters = @{ message = 'replacement'; level = 'Info' }
        }

        $tree = [StepTree]::new($rootConfig)
        $requestingStep = [Steps]::GetInstance().Get('request-replacement')
        $requestingStep.plugin.Api.Configuration.RequestOverlay('target', $replacementConfig)

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
        [PendingOverlays]::Reset()
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
        [PendingOverlays]::Reset()
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
        [PendingOverlays]::Reset()
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
                @{ type = 'step'; name = 'Child'; slug = 'child'; plugin = 'TextOutput'; parameters = @{ message = 'hi'; level = 'Trace' } }
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
        [PendingOverlays]::Reset()
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
                parameters = @{ message = "message from $Slug"; level = 'Trace' }
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
        [PendingOverlays]::Reset()
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

    Context 'requested overlays' {
        BeforeEach {
            $script:tree = [StepTree]::new(@{
                type  = 'section'
                name  = 'Root'
                slug  = 'root'
                items = @((New-OutputStep 'requester' 'requesterResult'), (New-OutputStep 'target' 'targetResult'))
            })
            $script:api = [Steps]::GetInstance().Get('requester').plugin.Api
        }

        It 'rejects a null overlay value' {
            $exceptionType = [System.ArgumentNullException]

            { $script:api.Configuration.RequestOverlay('target', $null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'rejects an overlay whose slug differs from the requested key' {
            $exceptionType = [System.ArgumentException]

            { $script:api.Configuration.RequestOverlay('target', (New-OutputStep 'different' 'differentResult')) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'leaves an overlay queued, without throwing, when its target slug is never visited' {
            $script:api.Configuration.RequestOverlay('ghost', (New-OutputStep 'ghost' 'ghostResult'))

            $script:tree.Process() | Should -BeTrue

            [PendingOverlays]::GetInstance().HasOverlay('ghost') | Should -BeTrue
        }

        It 'applies a [Step]-shaped overlay in place and clears it once applied' {
            $script:api.Configuration.RequestOverlay('target', (New-OutputStep 'target' 'replacedResult'))

            $script:tree.Process() | Should -BeTrue

            [PendingOverlays]::GetInstance().HasOverlay('target') | Should -BeFalse
            [Variables]::GetInstance().HasKey('targetResult') | Should -BeFalse
            [Variables]::GetInstance().Get('replacedResult').success | Should -BeTrue
        }

        It 'applies a [StepTree]-shaped overlay, replacing the target subtree' {
            $script:tree.children[1].Add([StepTree]::new((New-OutputStep 'target-child-old' 'targetChildOldResult')))

            $script:api.Configuration.RequestOverlay('target', @{
                    type  = 'section'
                    name  = 'Replacement target'
                    slug  = 'target'
                    tags  = @('replaced')
                    items = @((New-OutputStep 'target-child-new' 'targetChildNewResult'))
                })

            $script:tree.Process() | Should -BeTrue

            [PendingOverlays]::GetInstance().HasOverlay('target') | Should -BeFalse
            [Steps]::GetInstance().Exists('target-child-old') | Should -BeFalse
            [Variables]::GetInstance().HasKey('targetChildOldResult') | Should -BeFalse
            [Variables]::GetInstance().Get('targetChildNewResult').success | Should -BeTrue

            $target = $script:tree.children[1]
            $target.name | Should -Be 'Replacement target'
            $target.tags.HasTag('replaced') | Should -BeTrue
            $target.Count() | Should -Be 1
            $target.children[0].slug | Should -Be 'target-child-new'
        }

        It 'applies a [StepTree]-shaped overlay that reuses one of the old subtree''s own child slugs' {
            # This is the common overlay case: keep a child's slug, just change its config.
            # Building the overlay eagerly (before the old subtree is unregistered) would
            # collide with the still-registered 'target-child' slug; construction is deferred
            # until after Remove() clears it (see StepTree.ApplyPendingOverlay()).
            $script:tree.children[1].Add([StepTree]::new((New-OutputStep 'target-child' 'targetChildOldResult')))

            $script:api.Configuration.RequestOverlay('target', @{
                    type  = 'section'
                    name  = 'Replacement target'
                    slug  = 'target'
                    items = @((New-OutputStep 'target-child' 'targetChildNewResult'))
                })

            $script:tree.Process() | Should -BeTrue

            [Steps]::GetInstance().Exists('target-child') | Should -BeTrue
            [Variables]::GetInstance().HasKey('targetChildOldResult') | Should -BeFalse
            [Variables]::GetInstance().Get('targetChildNewResult').success | Should -BeTrue
        }
    }
}


Describe 'StepTree StartAtSlug' {
    BeforeAll {
        [taskPluginRegistry]::GetInstance().RegisterPlugin([TextOutput])

        function New-StartAtStep {
            param([string] $Slug)
            return @{
                type       = 'step'
                name       = "Step $Slug"
                slug       = $Slug
                plugin     = 'TextOutput'
                parameters = @{ message = "message from $Slug"; level = 'Trace' }
            }
        }

        # root
        # |- a
        # |- sec1
        # |  |- b
        # |  |- sec2
        # |  |  |- c
        # |  |  |- d
        # |  |- e
        # |- f
        function New-StartAtTree {
            return [StepTree]::new(@{
                    type  = 'section'; name = 'Root'; slug = 'root'
                    items = @(
                        (New-StartAtStep 'a')
                        @{
                            type  = 'section'; name = 'Sec1'; slug = 'sec1'
                            items = @(
                                (New-StartAtStep 'b')
                                @{
                                    type  = 'section'; name = 'Sec2'; slug = 'sec2'
                                    items = @((New-StartAtStep 'c'), (New-StartAtStep 'd'))
                                }
                                (New-StartAtStep 'e')
                            )
                        }
                        (New-StartAtStep 'f')
                    )
                })
        }

        function Get-ProcessedSlugs {
            return @('a', 'b', 'c', 'd', 'e', 'f') | Where-Object { [Steps]::GetInstance().IsProcessed($_) }
        }
    }

    BeforeEach {
        [Log]::Reset()
        [Steps]::Reset()
        [Variables]::Reset()
        [PendingOverlays]::Reset()
        $script:tree = New-StartAtTree
    }

    It 'runs every step when no start-at slug is set' {
        $script:tree.Process() | Should -BeTrue

        Get-ProcessedSlugs | Should -Be @('a', 'b', 'c', 'd', 'e', 'f')
    }

    It 'skips steps before a top-level start-at slug' {
        [ForgeProcessApi]::new().SetStartAtSlug('f')

        $script:tree.Process() | Should -BeTrue

        Get-ProcessedSlugs | Should -Be @('f')
    }

    It 'runs everything when the start-at slug is the first step' {
        [ForgeProcessApi]::new().SetStartAtSlug('a')

        $script:tree.Process() | Out-Null

        Get-ProcessedSlugs | Should -Be @('a', 'b', 'c', 'd', 'e', 'f')
    }

    It 'finds a start-at slug nested inside sections and runs everything after it' {
        [ForgeProcessApi]::new().SetStartAtSlug('d')

        $script:tree.Process() | Should -BeTrue

        Get-ProcessedSlugs | Should -Be @('d', 'e', 'f')
    }

    It 'runs the start-at step itself' {
        [ForgeProcessApi]::new().SetStartAtSlug('c')

        $script:tree.Process() | Out-Null

        [Steps]::GetInstance().IsProcessed('c') | Should -BeTrue
        [Steps]::GetInstance().IsProcessed('b') | Should -BeFalse
    }

    It 'clears the pending start-at slug once it is reached' {
        $api = [ForgeProcessApi]::new()
        $api.SetStartAtSlug('c')

        $script:tree.Process() | Out-Null

        $api.HasStartAtSlug() | Should -BeFalse
    }

    It 'leaves the start-at slug pending and runs nothing if it is never reached' {
        [Variables]::GetInstance().AddExcludeTag('skipme')
        [Steps]::Reset()
        $tree = [StepTree]::new(@{
                type  = 'section'; name = 'Root'; slug = 'root'
                items = @(
                    (New-StartAtStep 'a')
                    @{
                        type  = 'section'; name = 'Excluded'; slug = 'excluded'; tags = @('skipme')
                        items = @((New-StartAtStep 'd'))
                    }
                )
            })
        $api = [ForgeProcessApi]::new()
        $api.SetStartAtSlug('d')

        $tree.Process() | Out-Null

        $api.HasStartAtSlug() | Should -BeTrue
        [Steps]::GetInstance().IsProcessed('a') | Should -BeFalse
        [Steps]::GetInstance().IsProcessed('d') | Should -BeFalse
    }

    It 'honors conditionals once processing has resumed' {
        [Variables]::GetInstance().AddExcludeTag('skipme')
        [Steps]::Reset()
        $tree = [StepTree]::new(@{
                type  = 'section'; name = 'Root'; slug = 'root'
                items = @(
                    (New-StartAtStep 'a')
                    (New-StartAtStep 'b')
                    @{
                        type  = 'section'; name = 'Excluded'; slug = 'excluded'; tags = @('skipme')
                        items = @((New-StartAtStep 'c'))
                    }
                    (New-StartAtStep 'd')
                )
            })
        [ForgeProcessApi]::new().SetStartAtSlug('b')

        $tree.Process() | Out-Null

        [Steps]::GetInstance().IsProcessed('a') | Should -BeFalse
        [Steps]::GetInstance().IsProcessed('b') | Should -BeTrue
        [Steps]::GetInstance().IsProcessed('c') | Should -BeFalse
        [Steps]::GetInstance().IsProcessed('d') | Should -BeTrue
    }

    It 'applies a structural overlay on a section that is only being walked through' {
        [ForgeProcessApi]::new().SetStartAtSlug('d')
        [ForgeConfigurationApi]::new().RequestOverlay('sec2', @{
                type  = 'section'; name = 'Sec2 overlay'; slug = 'sec2'
                items = @((New-StartAtStep 'c'), (New-StartAtStep 'd'))
            })

        $script:tree.Process() | Out-Null

        [PendingOverlays]::GetInstance().HasOverlay('sec2') | Should -BeFalse
        Get-ProcessedSlugs | Should -Be @('d', 'e', 'f')
    }

    It 'does not count skipped steps as failures' {
        [ForgeProcessApi]::new().SetStartAtSlug('f')

        $script:tree.Process() | Should -BeTrue
    }
}
