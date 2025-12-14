<#+
.SYNOPSIS
YamlHelper wraps ConvertFrom-Yaml and provides error handling.
#>
function ConvertFrom-FileYaml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $Path
    )
    if (-not (Test-Path $Path)) { throw [System.IO.FileNotFoundException]::new("Config file not found: $Path") }
    try {
        $text = Get-Content -Path $Path -Raw -ErrorAction Stop
        if (-not (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
            throw "Required module 'powershell-yaml' is not available. Install it with: Install-Module powershell-yaml"
        }
        return ConvertFrom-Yaml -Yaml $text
    }
    catch [System.Management.Automation.MethodInvocationException] {
        throw "YAML parse error in file ${Path}: $($_.Exception.Message)"
    }
    catch {
        throw
    }
}
