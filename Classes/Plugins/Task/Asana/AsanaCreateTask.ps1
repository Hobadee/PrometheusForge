class AsanaCreateTask : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana task.

    .DESCRIPTION
    Creates a task via the POST /tasks API endpoint.
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
        A task must provide a non-empty name and a workspace, project, or parent task.
        Dates use ISO 8601 UTC timestamps or YYYY-MM-DD calendar dates, as required by Asana.
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ($null -eq $params.workspace -and $null -eq $params.projects -and $null -eq $params.parent) {
            throw [System.ArgumentException]::new("Parameters must include 'workspace', 'projects', or 'parent'.", 'workspace')
        }

        foreach ($field in @('assignee', 'parent', 'workspace')) {
            if ($null -ne $params.$field -and [string]::IsNullOrWhiteSpace([string]$params.$field)) {
                throw [System.ArgumentException]::new("Parameter '$field' cannot be empty.", $field)
            }
        }

        foreach ($field in @('html_notes', 'notes')) {
            if ($null -ne $params.$field -and $params.$field -isnot [string]) {
                throw [System.ArgumentException]::new("Parameter '$field' must be a string.", $field)
            }
        }

        if ($null -ne $params.resource_subtype) {
            $validResourceSubtypes = @('default_task', 'milestone', 'approval', 'custom')
            if ($validResourceSubtypes -notcontains $params.resource_subtype) {
                throw [System.ArgumentException]::new("Invalid resource_subtype. Must be one of: $($validResourceSubtypes -join ', ')", 'resource_subtype')
            }
        }

        if ($null -ne $params.approval_status) {
            $validApprovalStatuses = @('pending', 'approved', 'rejected', 'changes_requested')
            if ($validApprovalStatuses -notcontains $params.approval_status) {
                throw [System.ArgumentException]::new("Invalid approval_status. Must be one of: $($validApprovalStatuses -join ', ')", 'approval_status')
            }
        }

        if ($null -ne $params.completed -and $params.completed -isnot [bool]) {
            throw [System.ArgumentException]::new("Parameter 'completed' must be a Boolean.", 'completed')
        }

        if ($null -ne $params.approval_status -and $null -ne $params.completed) {
            $approvalIsComplete = $params.approval_status -ne 'pending'
            if ($params.completed -ne $approvalIsComplete) {
                throw [System.ArgumentException]::new("Parameter 'completed' must match 'approval_status'.", 'completed')
            }
        }

        foreach ($field in @('due_at', 'start_at')) {
            if ($null -ne $params.$field -and (([string]$params.$field) -notmatch '^\d{4}-\d{2}-\d{2}T.*Z$' -or -not [datetime]::TryParse([string]$params.$field, [ref]([datetime]::MinValue)))) {
                throw [System.ArgumentException]::new("Parameter '$field' must be an ISO 8601 UTC timestamp.", $field)
            }
        }

        foreach ($field in @('due_on', 'start_on')) {
            if ($null -ne $params.$field -and (([string]$params.$field) -notmatch '^\d{4}-\d{2}-\d{2}$' -or -not [datetime]::TryParseExact([string]$params.$field, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]([datetime]::MinValue)))) {
                throw [System.ArgumentException]::new("Parameter '$field' must use YYYY-MM-DD format.", $field)
            }
        }

        if ($null -ne $params.due_at -and $null -ne $params.due_on) {
            throw [System.ArgumentException]::new("Parameters cannot include both 'due_at' and 'due_on'.", 'due_at')
        }

        if ($null -ne $params.start_at -and $null -ne $params.start_on) {
            throw [System.ArgumentException]::new("Parameters cannot include both 'start_at' and 'start_on'.", 'start_at')
        }

        if ($null -ne $params.start_at -and $null -eq $params.due_at) {
            throw [System.ArgumentException]::new("Parameter 'due_at' is required when 'start_at' is provided.", 'due_at')
        }

        if ($null -ne $params.start_on -and $null -eq $params.due_at -and $null -eq $params.due_on) {
            throw [System.ArgumentException]::new("Parameter 'due_at' or 'due_on' is required when 'start_on' is provided.", 'start_on')
        }

        if ($params.resource_subtype -eq 'milestone' -and ($null -ne $params.start_at -or $null -ne $params.start_on)) {
            throw [System.ArgumentException]::new("Milestone tasks cannot include 'start_at' or 'start_on'.", 'resource_subtype')
        }

        if ($null -ne $params.projects) {
            if ($params.projects -is [string] -or $params.projects -isnot [System.Collections.IEnumerable]) {
                throw [System.ArgumentException]::new("Parameter 'projects' must be an array of project gids.", 'projects')
            }

            $projects = @($params.projects)
            if ($projects.Count -eq 0 -or @($projects | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
                throw [System.ArgumentException]::new("Parameter 'projects' must contain non-empty project gids.", 'projects')
            }
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Creates a new Asana task.

        .DESCRIPTION
        Builds the task payload and makes a POST request to the Asana /tasks endpoint.
        #>
        $body = @{
            name = [string]$this.parameters.name
        }

        foreach ($field in @('resource_subtype', 'approval_status', 'completed', 'due_at', 'due_on', 'html_notes', 'notes', 'start_at', 'start_on', 'assignee', 'parent', 'projects', 'workspace')) {
            if ($null -ne $this.parameters.$field) {
                $body[$field] = $this.parameters.$field
            }
        }

        return $this.InvokeAsanaApi('POST', '/tasks', $body)
    }
}

# Register the AsanaCreateTask plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateTask])
