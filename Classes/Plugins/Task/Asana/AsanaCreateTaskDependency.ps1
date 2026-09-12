class AsanaCreateTaskDependency : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that marks one Asana task as dependent on another.

    .DESCRIPTION
    Boilerplate only - no Asana API calls are implemented yet.
    #>

    AsanaCreateTaskDependency() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaCreateTaskDependency plugin class
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin
        #>
        return @{
            name = "AsanaCreateTaskDependency"
            version = "1.0.0"
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters required to create an Asana task dependency.

        .DESCRIPTION
        Expected parameters:
        - taskGid: The gid of the task that has a dependency (the dependent task). May be
          a literal gid or a { fromStep, path } reference (see AsanaTaskPluginBase.ResolveGid()).
        - dependsOnTaskGid: The gid of the task that must be completed first. May be a
          literal gid or a { fromStep, path } reference.
        #>
        if ($null -eq $params.taskGid) {
            throw [System.ArgumentException]::new("Parameters must include a 'taskGid' value.", 'taskGid')
        }

        if ($null -eq $params.dependsOnTaskGid) {
            throw [System.ArgumentException]::new("Parameters must include a 'dependsOnTaskGid' value.", 'dependsOnTaskGid')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Marks one Asana task as dependent on another.

        .NOTES
        Not implemented - boilerplate only.
        #>
        throw [System.NotImplementedException]::new("AsanaCreateTaskDependency.Execute() is not yet implemented")
    }
}

# Register the AsanaCreateTaskDependency plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateTaskDependency])
