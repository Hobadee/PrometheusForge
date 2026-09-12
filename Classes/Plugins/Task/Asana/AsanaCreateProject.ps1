class AsanaCreateProject : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana project.

    .DESCRIPTION
    Creates a project in Asana via the POST /projects API endpoint.
    Supports workspace, name, notes, html_notes, privacy_setting,
    default_access_level, color, icon, and default_view fields.
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
            name    = "AsanaCreateProject"
            version = "1.0.0"
        }
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters required to create an Asana project.

        .DESCRIPTION
        Expected parameters:
        - name: The name of the project to create (required).
        - workspace: The gid of the workspace to create the project in (required). Also accepts workspaceGid.
        - notes (optional): Free-form notes/description for the project.
        - html_notes (optional): HTML formatted notes/description for the project.
        - privacy_setting (optional): The privacy setting of the project (e.g. 'public_to_workspace', 'private_to_team', 'private').
        - default_access_level (optional): The default access level of the project (e.g. 'admin', 'editor', 'commenter', 'viewer').
        - color (optional): Color of the project.
        - icon (optional): Icon for the project.
        - default_view (optional): Default view of the project (e.g. 'list', 'board', 'calendar', 'timeline').
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ([string]::IsNullOrWhiteSpace([string]$params.workspaceGid)) {
            throw [System.ArgumentException]::new("Parameters must include a 'workspaceGid' value.", 'workspaceGid')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Creates a new Asana project.

        .DESCRIPTION
        Builds the project payload and makes a POST request to the Asana /projects endpoint.

        .OUTPUTS
        System.Object - the parsed JSON response from the Asana API (typically containing data with project details).
        #>
        $workspace = if ($null -ne $this.parameters.workspace) { $this.parameters.workspace } else { $this.parameters.workspaceGid }

        $body = @{
            name      = [string]$this.parameters.name
            workspace = [string]$workspace
        }

        if ($null -ne $this.parameters.notes) {
            $body['notes'] = [string]$this.parameters.notes
        }

        if ($null -ne $this.parameters.html_notes) {
            $body['html_notes'] = [string]$this.parameters.html_notes
        }

        if ($null -ne $this.parameters.privacy_setting) {
            $body['privacy_setting'] = [string]$this.parameters.privacy_setting
        }

        if ($null -ne $this.parameters.default_access_level) {
            $body['default_access_level'] = [string]$this.parameters.default_access_level
        }

        if ($null -ne $this.parameters.color) {
            $body['color'] = [string]$this.parameters.color
        }

        if ($null -ne $this.parameters.icon) {
            $body['icon'] = [string]$this.parameters.icon
        }

        if ($null -ne $this.parameters.default_view) {
            $body['default_view'] = [string]$this.parameters.default_view
        }

        return $this.InvokeAsanaApi('POST', '/projects', $body)
    }
}

# Register the AsanaCreateProject plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateProject])
