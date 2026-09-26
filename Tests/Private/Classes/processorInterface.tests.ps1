Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'processorInterface' {
    It 'requires concrete processors to implement Process' {
        $exceptionType = [System.NotImplementedException]

        { [processorInterface]::new().Process() } | Should -Throw -ExceptionType $exceptionType
    }
}
