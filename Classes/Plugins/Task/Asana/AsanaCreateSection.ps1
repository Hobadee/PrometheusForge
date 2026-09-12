class AsanaCreateSection : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana section within a project.

    .DESCRIPTION
    Boilerplate only - no Asana API calls are implemented yet.
    #>

    AsanaCreateSection() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaCreateSection plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "AsanaCreateSection"
            version = "1.0.0"
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters required to create an Asana section.

        .DESCRIPTION
        Expected parameters:
        - name: The name of the section to create.
        - projectGid: The gid of the project to create the section in. May be a literal
          gid or a { fromStep, path } reference (see AsanaTaskPluginBase.ResolveGid()),
          typically pointing at the result of an earlier AsanaCreateProject step.
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ($null -eq $params.projectGid) {
            throw [System.ArgumentException]::new("Parameters must include a 'projectGid' value.", 'projectGid')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Creates a new Asana section within a project.

        .NOTES
        Not implemented - boilerplate only.
        #>
        throw [System.NotImplementedException]::new("AsanaCreateSection.Execute() is not yet implemented")
    }
}

# Register the AsanaCreateSection plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateSection])
