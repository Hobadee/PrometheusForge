class AsanaTaskPluginBase : TaskPluginInterface {
    <#
    .SYNOPSIS
    Shared boilerplate for Asana task plugins.

    .DESCRIPTION
    Base class for all Asana-related task plugins. Scope is intentionally limited to
    *creating* Asana objects (projects, sections, tasks, task dependencies) - no reads,
    updates, or deletes of any other Asana data.

    Centralizes pushing connection config into the [AsanaApiClient] singleton, which owns
    authentication (read from [Variables], never from step/plugin parameters) and HTTP calls.
    Gid parameters (e.g. projectGid, taskGid) are always plain templated strings - plugins
    read them directly from $this.parameters, no resolution helper needed.

    .NOTES
    This class is NOT registered with [taskPluginRegistry] - only concrete derived plugins
    (AsanaCreateProject, AsanaCreateSection, AsanaCreateTask, AsanaCreateTaskDependency)
    are registered.

    Derived Execute() methods other than AsanaCreateProject and AsanaCreateSection are still
    boilerplate only.
    #>

    static [string[]] $UniversalRichTextTags = @('body', 'strong', 'em', 'u', 's', 'code', 'ol', 'ul', 'li', 'a', 'blockquote', 'pre')

    AsanaTaskPluginBase() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaTaskPluginBase class.
        #>
    }

    [void] ValidateRichText([string]$fieldName, [string]$html, [string[]]$additionalAllowedTags) {
        <#
        .SYNOPSIS
        Validates a rich text field against Asana's supported HTML subset.

        .DESCRIPTION
        Per https://developers.asana.com/docs/rich-text, rich text fields must be wrapped in
        <body> tags and may only contain the universal tag set plus any field-specific tags
        (e.g. tasks additionally allow h1/h2/hr/img).

        .PARAMETER fieldName
        Name of the field being validated, used in error messages.

        .PARAMETER html
        The rich text HTML content to validate.

        .PARAMETER additionalAllowedTags
        Extra tag names (lowercase, no brackets/slashes) allowed beyond the universal set.
        #>
        if ($null -eq $html) {
            return
        }

        if ($html -notmatch '^\s*<body>[\s\S]*</body>\s*$') {
            throw [System.ArgumentException]::new("Parameter '$fieldName' must be wrapped in <body> tags.", $fieldName)
        }

        $allowedTags = @([AsanaTaskPluginBase]::UniversalRichTextTags) + @($additionalAllowedTags)
        $tagMatches = [regex]::Matches($html, '<\/?([a-zA-Z0-9]+)\b[^>]*>')
        foreach ($match in $tagMatches) {
            $tagName = $match.Groups[1].Value.ToLowerInvariant()
            if ($allowedTags -notcontains $tagName) {
                throw [System.ArgumentException]::new("Parameter '$fieldName' contains unsupported tag '<$tagName>'.", $fieldName)
            }
        }
    }

    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates parameters common to all Asana task plugins, then delegates to the
        derived plugin for resource-specific validation.

        .DESCRIPTION
        Credentials are never step/plugin parameters - see [AsanaApiClient] for the Variables
        keys used to authenticate.
        Optionally:
        - baseUri: Override for the Asana API base URI (useful for testing).

        .PARAMETER params
        The parameters object to validate.

        .NOTES
        Derived plugins must implement ValidateAsanaParameters() for their own required
        fields; do not override ValidateParameters() directly in derived classes.
        #>
        if ($null -eq $params) {
            throw [System.ArgumentException]::new("Parameters cannot be null")
        }

        $this.ValidateAsanaParameters($params)
    }

    [void] ValidateAsanaParameters([object]$params) {
        <#
        .SYNOPSIS
        Resource-specific parameter validation. Must be implemented by derived plugins.

        .PARAMETER params
        The parameters object to validate.
        #>
        throw [System.NotImplementedException]::new("ValidateAsanaParameters method must be implemented by derived Asana plugin")
    }

    [object] InvokeAsanaApi([string]$method, [string]$path, [object]$body) {
        <#
        .SYNOPSIS
        Makes an authenticated call against the Asana API.

        .DESCRIPTION
        Thin wrapper around [AsanaApiClient]::GetInstance().InvokeApi() - the client singleton
        owns authentication and the actual HTTP call. Concrete plugins call this to perform
        their create operation (e.g. POST /projects, POST /sections, POST /tasks,
        POST /tasks/{gid}/addDependencies).

        .PARAMETER method
        The HTTP method to use (e.g. "POST").

        .PARAMETER path
        The Asana API path, relative to the configured base URI (e.g. "/projects").

        .PARAMETER body
        The request body to send. Automatically wrapped in a top-level "data" property,
        per Asana API convention; pass $null for requests with no body.

        .OUTPUTS
        System.Object - the parsed JSON response (typically has a top-level "data" property).
        #>
        [Log]::Trace("AsanaTaskPluginBase::InvokeAsanaApi() - Invoking API with method $method, path $path, body: $($body | Out-String)")
        return [AsanaApiClient]::GetInstance().InvokeApi($method, $path, $body)
    }

}
