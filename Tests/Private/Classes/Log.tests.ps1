Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'Log' {
    BeforeEach {
        [Log]::Instance = $null
        [Variables]::Reset()
    }

    It 'returns the same singleton instance' {
        $first = [Log]::GetInstance()
        $second = [Log]::GetInstance()

        $first | Should -Be $second
    }

    It 'writes the level and message to the terminal' {
        $writer = [System.IO.StringWriter]::new()
        $originalWriter = [System.Console]::Out
        $originalColor = [System.Console]::ForegroundColor

        try {
            [System.Console]::SetOut($writer)
            [Log]::Warning('configuration warning')

            $writer.ToString() | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[WARNING\] configuration warning\r?\n$'
            [System.Console]::ForegroundColor | Should -Be $originalColor
        }
        finally {
            [System.Console]::SetOut($originalWriter)
            $writer.Dispose()
        }
    }

    It 'maps log levels to console colors' {
        [Log]::GetColor([LogLevel]::Emergency) | Should -Be ([System.ConsoleColor]::DarkRed)
        [Log]::GetColor([LogLevel]::Error) | Should -Be ([System.ConsoleColor]::Red)
        [Log]::GetColor([LogLevel]::Warning) | Should -Be ([System.ConsoleColor]::Yellow)
        [Log]::GetColor([LogLevel]::Notice) | Should -Be ([System.ConsoleColor]::Cyan)
        [Log]::GetColor([LogLevel]::Info) | Should -Be ([System.ConsoleColor]::Green)
        [Log]::GetColor([LogLevel]::Debug) | Should -Be ([System.ConsoleColor]::Gray)
    }

    It 'filters messages below the configured terminal level' {
        $writer = [System.IO.StringWriter]::new()
        $originalWriter = [System.Console]::Out

        try {
            [System.Console]::SetOut($writer)
            [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Error)
            [Log]::Info('hidden message')

            $writer.ToString() | Should -Be ''
        }
        finally {
            [System.Console]::SetOut($originalWriter)
            $writer.Dispose()
        }
    }

    It 'allows messages at or above the configured terminal level' {
        $writer = [System.IO.StringWriter]::new()
        $originalWriter = [System.Console]::Out

        try {
            [System.Console]::SetOut($writer)
            [Variables]::GetInstance().Set('logTerminalLevel', [LogLevel]::Warning)
            [Log]::Warning('visible warning')

            $writer.ToString() | Should -Match '\[WARNING\] visible warning'
        }
        finally {
            [System.Console]::SetOut($originalWriter)
            $writer.Dispose()
        }
    }
}
