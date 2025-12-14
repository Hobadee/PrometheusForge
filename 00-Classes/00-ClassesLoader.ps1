# Classes loader: explicitly dot-source class files in defined load order to avoid inheritance/compile-time ordering issues
$classFiles = @(
    '00-BaseEntity.ps1',
    '01-Tag.ps1',
    '02-Dependency.ps1',
    '03-Task.ps1',
    '04-Checklist.ps1',
    '05-Config.ps1',
    '06-ConfigOverride.ps1',
    '07-Run.ps1',
    '08-TaskPlugin.ps1',
    '09-TextOutputPlugin.ps1'
)

foreach ($f in $classFiles) {
    $path = Join-Path -Path $PSScriptRoot -ChildPath $f
    if (-not (Test-Path $path)) { throw "Missing class file: $path" }
    . $path
}
