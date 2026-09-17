class AsanaCreateTaskDependency : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that links Asana tasks as predecessors or successors of an anchor task.

    .DESCRIPTION
    Wraps both POST /tasks/{task_gid}/addDependencies and POST /tasks/{task_gid}/addDependents,
    which are functionally identical aside from which side of the relationship taskGid sits on.
    The 'relation' parameter picks the direction, using 'predecessor'/'successor' terminology
    instead of Asana's 'dependency'/'dependent' (too easy to mix up) since it makes plain which
    task must complete first:
    - 'predecessor': relatedTaskGids must be completed before taskGid can start (addDependencies).
    - 'successor': relatedTaskGids happen after taskGid is completed (addDependents).
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
        Validates parameters required to link Asana tasks as predecessors/successors.

        .DESCRIPTION
        Expected parameters:
        - taskGid: The gid of the anchor task, as a string.
        - relatedTaskGids: An array of task gids to relate to the anchor task.
        - relation: Either 'predecessor' (relatedTaskGids must complete before taskGid) or
          'successor' (relatedTaskGids happen after taskGid).
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.taskGid)) {
            throw [System.ArgumentException]::new("Parameters must include a non-empty 'taskGid' value.", 'taskGid')
        }

        if ($null -eq $params.relatedTaskGids -or $params.relatedTaskGids -is [string] -or $params.relatedTaskGids -isnot [System.Collections.IEnumerable]) {
            throw [System.ArgumentException]::new("Parameters must include a 'relatedTaskGids' array.", 'relatedTaskGids')
        }

        $relatedTaskGids = @($params.relatedTaskGids)
        if ($relatedTaskGids.Count -eq 0 -or @($relatedTaskGids | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
            throw [System.ArgumentException]::new("Parameter 'relatedTaskGids' must contain non-empty task gids.", 'relatedTaskGids')
        }

        $validRelations = @('predecessor', 'successor')
        if ($validRelations -notcontains $params.relation) {
            throw [System.ArgumentException]::new("Parameter 'relation' must be one of: $($validRelations -join ', ')", 'relation')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Links the related tasks to the anchor task as predecessors or successors.

        .DESCRIPTION
        'predecessor' calls addDependencies with { dependencies: relatedTaskGids }; 'successor'
        calls addDependents with { dependents: relatedTaskGids }. Same shape, opposite endpoint.
        #>
        $taskGid = [string]$this.parameters.taskGid
        $relatedTaskGids = @($this.parameters.relatedTaskGids)

        if ($this.parameters.relation -eq 'predecessor') {
            return $this.InvokeAsanaApi('POST', "/tasks/$taskGid/addDependencies", @{ dependencies = $relatedTaskGids })
        }

        return $this.InvokeAsanaApi('POST', "/tasks/$taskGid/addDependents", @{ dependents = $relatedTaskGids })
    }
}

# Register the AsanaCreateTaskDependency plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateTaskDependency])
