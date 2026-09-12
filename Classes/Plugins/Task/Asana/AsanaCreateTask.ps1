class AsanaCreateTask : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana task.

    .DESCRIPTION
    Boilerplate only - no Asana API calls are implemented yet.
    #>

    AsanaCreateTask() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaCreateTask plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "AsanaCreateTask"
            version = "1.0.0"
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters required to create an Asana task.

        .DESCRIPTION
        Expected parameters:
        - name: The name of the task to create.
        - workspaceGid: The gid of the workspace the task belongs to. May be a literal
          gid or a { fromStep, path } reference (see AsanaTaskPluginBase.ResolveGid()).
        - projectGid (optional): The gid of the project to add the task to.
        - sectionGid (optional): The gid of the section to add the task to.
        - notes (optional): Free-form notes/description for the task.
        - assignee (optional): The gid or email of the user to assign the task to.
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
        Creates a new Asana task.

        .NOTES
        Not implemented - boilerplate only.
        #>
        throw [System.NotImplementedException]::new("AsanaCreateTask.Execute() is not yet implemented")
    }
}

# Register the AsanaCreateTask plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateTask])
