class AsanaAddTasksToSection : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that adds multiple Asana tasks to a section.

    .DESCRIPTION
    Adds each task to a section via the POST /sections/{section_gid}/addTask API endpoint.
    Asana accepts one task per request, so this plugin sends one request for each task gid.
    #>

    AsanaAddTasksToSection() : base() {
    }

    static [hashtable] PluginInfo() {
        return @{
            name    = 'AsanaAddTasksToSection'
            version = '1.0.0'
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        if ([string]::IsNullOrWhiteSpace([string]$params.sectionGid)) {
            throw [System.ArgumentException]::new("Parameters must include a non-empty 'sectionGid' value.", 'sectionGid')
        }

        if ($null -eq $params.taskGids -or $params.taskGids -is [string] -or $params.taskGids -isnot [System.Collections.IEnumerable]) {
            throw [System.ArgumentException]::new("Parameters must include a 'taskGids' array.", 'taskGids')
        }

        $taskGids = @($params.taskGids)
        if ($taskGids.Count -eq 0 -or @($taskGids | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
            throw [System.ArgumentException]::new("Parameter 'taskGids' must contain non-empty task gids.", 'taskGids')
        }
    }

    [object] Execute() {
        $sectionGid = [string]$this.parameters.sectionGid
        $responses = [System.Collections.Generic.List[object]]::new()

        # Asana adds newest tasks to the top of the section, so reverse the order to maintain the original order
        $taskGids = @($this.parameters.taskGids)
        [array]::Reverse($taskGids)

        foreach ($taskGid in $taskGids) {
            $responses.Add($this.InvokeAsanaApi('POST', "/sections/$sectionGid/addTask", @{ task = [string]$taskGid }))
        }

        return $responses.ToArray()
    }
}

# Register the AsanaAddTasksToSection plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaAddTasksToSection])
