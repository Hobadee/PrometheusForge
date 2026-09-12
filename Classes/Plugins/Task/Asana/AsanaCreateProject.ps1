class AsanaCreateProject : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana project.

    .DESCRIPTION
    Boilerplate only - no Asana API calls are implemented yet.
    #>

    AsanaCreateProject() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaCreateProject plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "AsanaCreateProject"
            version = "1.0.0"
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters required to create an Asana project.

        .DESCRIPTION
        Expected parameters:
        - name: The name of the project to create.
        - workspaceGid: The gid of the workspace to create the project in. May be a literal
          gid or a { fromStep, path } reference (see AsanaTaskPluginBase.ResolveGid()).
        - team (optional): The gid of the team to associate the project with.
        - notes (optional): Free-form notes/description for the project.
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ($null -eq $params.workspaceGid) {
            throw [System.ArgumentException]::new("Parameters must include a 'workspaceGid' value.", 'workspaceGid')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Creates a new Asana project.

        .NOTES
        Not implemented - boilerplate only.
        #>
        throw [System.NotImplementedException]::new("AsanaCreateProject.Execute() is not yet implemented")
    }
}

# Register the AsanaCreateProject plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateProject])
