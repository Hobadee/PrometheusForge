Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'StepTree configuration overrides' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'replaces a matching step with the requested step configuration' {
        $rootConfig = @{
            type = 'section'
            name = 'Root'
            items = @(
                @{
                    type = 'step'
                    name = 'Request replacement'
                    plugin = 'TextOutput'
                    parameters = @{ message = 'requesting replacement'; method = 'Info' }
                },
                @{
                    type = 'step'
                    name = 'Target'
                    plugin = 'TextOutput'
                    result = 'originalResult'
                    parameters = @{ message = 'original'; method = 'Info' }
                }
            )
        }
        $replacementConfig = @{
            type = 'step'
            name = 'Target'
            plugin = 'TextOutput'
            result = 'replacementResult'
            parameters = @{ message = 'replacement'; method = 'Info' }
        }

        $tree = [StepTree]::new($rootConfig)
        $requestingStep = [Steps]::GetInstance().Get('Request replacement')
        $requestingStep.plugin.Api.Configuration.RequestOverride('Target', $replacementConfig)

        $tree.Process() | Should -BeTrue

        $configuration = [Variables]::GetInstance()
        $configuration.HasKey('originalResult') | Should -BeFalse
        $configuration.Get('replacementResult').success | Should -BeTrue
        [Steps]::GetInstance().Get('Target').config.parameters.message | Should -Be 'replacement'
    }
}

Describe 'StepTree tags' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'populates tags from the item config' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('a', 'b') })
        $tree.tags.GetTags() | Should -Contain 'a'
        $tree.tags.GetTags() | Should -Contain 'b'
    }

    It 'defaults to an empty tags collection when none are configured' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root' })
        $tree.tags.Count() | Should -Be 0
    }
}

Describe 'StepTree checkConditionals' {
    BeforeEach {
        [Steps]::Reset()
        [Variables]::Reset()
    }

    It 'runs when tags match neither include nor exclude' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('other') })
        [Variables]::GetInstance().AddIncludeTag('include')
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'skips when tags match exclude only' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('exclude') })
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeFalse
    }

    It 'runs when tags match include only' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('include') })
        [Variables]::GetInstance().AddIncludeTag('include')
        [Variables]::GetInstance().AddExcludeTag('exclude')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'runs when tags match both include and exclude and tagsPrecedence is unset' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'runs when tags match both include and exclude and tagsPrecedence is include' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        [Variables]::GetInstance().Set('tagsPrecedence', 'include')
        $tree.checkConditionals() | Should -BeTrue
    }

    It 'skips when tags match both include and exclude and tagsPrecedence is exclude' {
        $tree = [StepTree]::new(@{ type = 'section'; name = 'Root'; tags = @('shared') })
        [Variables]::GetInstance().AddIncludeTag('shared')
        [Variables]::GetInstance().AddExcludeTag('shared')
        [Variables]::GetInstance().Set('tagsPrecedence', 'exclude')
        $tree.checkConditionals() | Should -BeFalse
    }
}
