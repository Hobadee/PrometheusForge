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
                    parameters = @{ message = 'requesting replacement'; method = 'Verbose' }
                },
                @{
                    type = 'step'
                    name = 'Target'
                    plugin = 'TextOutput'
                    result = 'originalResult'
                    parameters = @{ message = 'original'; method = 'Verbose' }
                }
            )
        }
        $replacementConfig = @{
            type = 'step'
            name = 'Target'
            plugin = 'TextOutput'
            result = 'replacementResult'
            parameters = @{ message = 'replacement'; method = 'Verbose' }
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
