class AsanaCreateSection : AsanaTaskPluginBase {
    <#
    .SYNOPSIS
    Task plugin that creates a new Asana section within a project.

    .DESCRIPTION
    Creates a section in a project via the POST /projects/{project_gid}/sections API endpoint.
    Supports name, insert_before, and insert_after fields.
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
        - name: The name of the section to create (required). Cannot be an empty string.
        - projectGid: The gid of the project to create the section in (required), as a string.
          Typically templated from the result of an earlier AsanaCreateProject step.
        - insert_before (optional): An existing section gid before which the new section should be
          inserted. Cannot be provided together with insert_after.
        - insert_after (optional): An existing section gid after which the new section should be
          inserted. Cannot be provided together with insert_before.
        #>
        if ([string]::IsNullOrWhiteSpace([string]$params.name)) {
            throw [System.ArgumentException]::new("Parameters must include a 'name' value.", 'name')
        }

        if ($null -eq $params.projectGid) {
            throw [System.ArgumentException]::new("Parameters must include a 'projectGid' value.", 'projectGid')
        }

        if ($null -ne $params.insert_before -and $null -ne $params.insert_after) {
            throw [System.ArgumentException]::new("Parameters cannot include both 'insert_before' and 'insert_after'.", 'insert_before')
        }
    }

    [object] Execute() {
        <#
        .SYNOPSIS
        Creates a new Asana section within a project.

        .DESCRIPTION
        Resolves the target project's gid and makes a POST request to the Asana
        /projects/{project_gid}/sections endpoint.

        .OUTPUTS
        System.Object - the parsed JSON response from the Asana API (typically containing data with section details).
        #>
        $projectGid = [string]$this.parameters.projectGid

        $body = @{
            name = [string]$this.parameters.name
        }

        if ($null -ne $this.parameters.insert_before) {
            $body['insert_before'] = [string]$this.parameters.insert_before
        }

        if ($null -ne $this.parameters.insert_after) {
            $body['insert_after'] = [string]$this.parameters.insert_after
        }

        return $this.InvokeAsanaApi('POST', "/projects/$projectGid/sections", $body)
    }
}

# Register the AsanaCreateSection plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([AsanaCreateSection])

