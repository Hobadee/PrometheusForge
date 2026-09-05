class ForgeApi {
    <#
    .SYNOPSIS
    Top-level facade injected into plugins, namespaced by API category.

    .DESCRIPTION
    Plugins opt into calling these APIs; nothing here is required to implement a
    valid plugin. Add new categories as additional namespaced properties (e.g. Logging)
    rather than expanding an individual category class's own responsibilities.

    .NOTES
    Future stretch goal (see PROJECT_STATUS.md): permission plugins to only the
    API categories they declare in PluginInfo(), and reject calls to undeclared ones.
    #>

    [ForgeVariableApi] $Variables
    [ForgeConfigurationApi] $Configuration
    [ForgeTemplateApi] $Template

    ForgeApi() {
        $this.Variables = [ForgeVariableApi]::new()
        $this.Configuration = [ForgeConfigurationApi]::new()
        $this.Template = [ForgeTemplateApi]::new()
    }
}
