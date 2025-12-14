<#
.SYNOPSIS
Plugin helper: returns default plugin instances for engine.
#>
function New-Default-Plugins {
    [CmdletBinding()]
    param(
        [hashtable] $PluginSettings = @{}
    )
    $plugins = @{}
    $textSettings = $null
    if ($PluginSettings.ContainsKey('textOutput')) { $textSettings = $PluginSettings['textOutput'] }
    $plugins['textOutput'] = [TextOutputPlugin]::new($textSettings)
    return $plugins
}
