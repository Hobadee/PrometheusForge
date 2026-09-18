class AsanaCreateProject : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana project.

    .DESCRIPTION
    Creates a project in Asana via the POST /projects API endpoint.
    Supports workspace, name, notes, html_notes, privacy_setting,
    default_access_level, color, icon, and default_view fields.

    .PARAMETER name
    Required project title to create in Asana.

    .PARAMETER workspace
    The Asana workspace GID to create the project in. This is accepted as a synonym for workspaceGid.

    .PARAMETER workspaceGid
    The Asana workspace GID to create the project in. This is accepted as a synonym for workspace.

    .PARAMETER notes
    Optional plain-text description for the project.

    .PARAMETER html_notes
    Optional rich-text HTML description for the project.

    .PARAMETER privacy_setting
    Optional Asana privacy mode for the project.

    .PARAMETER default_access_level
    Optional team access level for new members.

    .PARAMETER color
    Optional project color key.

    .PARAMETER icon
    Optional project icon key.

    .PARAMETER default_view
    Optional view mode for the project.
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
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ([string]::IsNullOrWhiteSpace([string]$params.workspaceGid)) {
            throw [System.ArgumentException]::new("Parameters must include a 'workspaceGid' value.", 'workspaceGid')
        }

        if ($null -ne $params.color) {
            $validColors = @(
                "dark-pink", "dark-green", "dark-blue", "dark-red", "dark-teal", "dark-brown", "dark-orange", "dark-purple", "dark-warm-gray",
                "light-pink", "light-green", "light-blue", "light-red", "light-teal", "light-brown", "light-orange", "light-purple", "light-warm-gray",
                "none", "null"
            )
            if ($validColors -notcontains $params.color) {
                throw [System.ArgumentException]::new("Invalid color value. Must be one of: $($validColors -join ', ')", 'color')
            }
        }

        if ($null -ne $params.icon) {
            $validIcons = @(
                "list", "board", "timeline", "calendar", "rocket", "people", "graph", "star", "bug", "light_bulb", "globe", "gear", "notebook",
                "computer", "check", "target", "html", "megaphone", "chat_bubbles", "briefcase", "page_layout", "mountain_flag", "puzzle",
                "presentation", "line_and_symbols", "speed_dial", "ribbon", "shoe", "shopping_basket", "map", "ticket", "coins"
            )
            if ($validIcons -notcontains $params.icon) {
                throw [System.ArgumentException]::new("Invalid icon value. Must be one of: $($validIcons -join ', ')", 'icon')
            }
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
