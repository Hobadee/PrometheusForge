class AsanaTaskPluginBase : TaskPluginInterface {
    <#
    .SYNOPSIS
    Shared boilerplate for Asana task plugins.

    .DESCRIPTION
    Base class for all Asana-related task plugins. Scope is intentionally limited to
    *creating* Asana objects (projects, sections, tasks, task dependencies) - no reads,
    updates, or deletes of any other Asana data.

    Centralizes:
    - Pushing connection config into the [AsanaApiClient] singleton, which owns authentication
      (read from [Variables], never from step/plugin parameters) and HTTP calls.
    - A helper for resolving a "gid" (Asana's resource id) either from a literal value in
      YAML or from a previously-registered Step result, so later steps can chain off of
      ids created by earlier steps (e.g. use a created project's gid as the parent for a
      section created in a later step).

    .NOTES
    This class is NOT registered with [taskPluginRegistry] - only concrete derived plugins
    (AsanaCreateProject, AsanaCreateSection, AsanaCreateTask, AsanaCreateTaskDependency)
    are registered.

    This is boilerplate only; ResolveGid() and derived Execute() methods are not implemented yet.
    #>

    AsanaTaskPluginBase() : base() {
        <#
        .SYNOPSIS
        Constructor for the AsanaTaskPluginBase class.
        #>
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
        return [AsanaApiClient]::GetInstance().InvokeApi($method, $path, $body)
    }

    [string] ResolveGid([object]$value) {
        <#
        .SYNOPSIS
        Resolves an Asana gid from either a literal string or a reference to a
        previously-registered Step result.

        .DESCRIPTION
        Supports two shapes for a "gid" parameter (e.g. parentProjectGid, taskGid):
        - A literal string gid, e.g. "1234567890".
        - A reference object pointing at a Step result registered via that step's
          'result:' config key, e.g.:
              { fromStep: "createdProject", path: "object.data.gid" }
          'fromStep' names the key the earlier step's full result hashtable was stored
          under via $this.Api.Variables (Step.Process() does this when config.result is set).
          'path' is a dot-notation path into that stored result used to locate the gid.

        .PARAMETER value
        The raw parameter value to resolve (string or reference object).

        .OUTPUTS
        System.String - the resolved gid.

        .NOTES
        Not implemented - boilerplate only.
        #>
        throw [System.NotImplementedException]::new("ResolveGid is not yet implemented")
    }

}
