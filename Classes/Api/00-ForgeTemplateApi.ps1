class ForgeTemplateApi {
    <#
    .SYNOPSIS
    Curated access to template expansion for plugins.

    .DESCRIPTION
    Wraps [TemplateEngine]'s static helpers, supplying the current Variables singleton so
    plugins don't need to know how the engine resolves its variable source.

    .NOTES
    Step parameters are already expanded once at StepTree-construction time (before any
    processing runs), against whatever Variables existed then. Re-expanding via this API at
    Execute()-time picks up variables set since then (e.g. by an earlier step, or via
    ForgeConfigurationApi.Insert()-driven dynamic steps) - it is not merely redundant.
    #>

    hidden [Variables] $variables

    ForgeTemplateApi() {
        $this.variables = [Variables]::GetInstance()
    }

    [string] ExpandString([string] $template) {
        <#
        .SYNOPSIS
        Expands template tokens within a single string.
        #>
        return [TemplateEngine]::ExpandString($template, $this.variables)
    }

    [object] ExpandTopLevelValues([object] $inputObject) {
        <#
        .SYNOPSIS
        Expands templated top-level string values in an object (see TemplateEngine for supported shapes).
        #>
        return [TemplateEngine]::ExpandTopLevelValues($inputObject, $this.variables)
    }
}
