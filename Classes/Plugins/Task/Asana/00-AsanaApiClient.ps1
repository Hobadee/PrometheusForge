class AsanaApiClient {
    <#
    .SYNOPSIS
    Singleton responsible for Asana authentication and making Asana API calls.

    .DESCRIPTION
    Centralizes everything Asana-connection-related so [AsanaTaskPluginBase] (and, through
    it, every concrete Asana plugin) shares one place that knows how to authenticate and
    make requests. Currently supports Personal Access Token auth. Asana also supports OAuth2
    for some scopes/apps; this class is the intended home for that once it's needed - callers
    only ever go through Configure()/InvokeApi(), so adding OAuth later shouldn't require
    changes in the plugins themselves.

    Credentials are never accepted as plugin/step parameters. They are read directly from the
    [Variables] singleton, which is populated from CLI arguments or overlay YAML - never from
    workflow config files themselves:
    - Plugin.Asana.PAT      Personal Access Token (current, only implemented auth mode)
    - Plugin.Asana.Username OAuth username (reserved; not implemented, takes precedence once it is)

    .NOTES
    Run-scoped singleton: holds credentials for the current Invoke-Forge run, so it is reset
    via Reset-ForgeState.ps1 between runs (see [AsanaApiClient]::Reset()).
    #>

    static [AsanaApiClient] $Instance = $null  # Singleton object; Explicitly initialize to $null

    static [string] $VarKey_PAT = 'Plugin.Asana.PAT'
    static [string] $VarKey_OAuthUsername = 'Plugin.Asana.Username'
    static [string] $VarKey_BaseUri = 'Plugin.Asana.BaseUri'

    [string] $baseUri = "https://app.asana.com/api/1.0"

    [string] $bearerToken = $null


    AsanaApiClient() {
        <#
        .SYNOPSIS
        Constructor for the AsanaApiClient class.

        .NOTES
        No way of enforcing `private` constructor in PowerShell, but this is intended to be
        used only via GetInstance().
        #>
    }


    static [AsanaApiClient] GetInstance() {
        <#
        .SYNOPSIS
        Gets the singleton instance of the AsanaApiClient class.
        #>
        if ($null -eq [AsanaApiClient]::Instance) {
            [AsanaApiClient]::Instance = [AsanaApiClient]::new()
        }
        return [AsanaApiClient]::Instance
    }


    static [void] Reset() {
        <#
        .SYNOPSIS
        Resets the singleton instance.

        .DESCRIPTION
        Clears the singleton instance, forcing GetInstance() to create a new one on the next
        call. Wired into Reset-ForgeState.ps1 so credentials don't leak between Invoke-Forge
        calls in the same session.
        #>

        # If OAuth is in use, we should attempt to invalidate the bearer token
        # Implement later

        [AsanaApiClient]::Instance = $null
    }


    [void] Configure() {
        <#
        .SYNOPSIS
        Resolves Asana auth from [Variables] and applies any connection overrides.

        .PARAMETER baseUri
        The Asana API base URI to use. Pass $null/empty to keep the current value.

        .DESCRIPTION
        Credentials are intentionally NOT accepted as arguments - they are looked up from the
        [Variables] singleton (Plugin.Asana.Username takes precedence for OAuth once it's
        implemented; otherwise Plugin.Asana.PAT is required).

        .NOTES
        Called by [AsanaTaskPluginBase]::ValidateParameters() for each plugin instance, so this
        may be called multiple times per run. Last call wins; all Asana plugins in a given run
        are expected to authenticate the same way.
        #>
        $variables = [Variables]::GetInstance()

        # Retrieve the base URI from the variables, falling back to the current value if not set.
        $this.baseUri = $variables.GetOrDefault([AsanaApiClient]::VarKey_BaseUri, $this.baseUri)

        # Check for existence of PAT and OAuth credentials in the variables.
        $oauth = $variables.HasKey([AsanaApiClient]::VarKey_OAuthUsername)
        $pat = $variables.HasKey([AsanaApiClient]::VarKey_PAT)

        # If neither PAT nor OAuth is configured, we can't actually do anything; throw an exception.
        if (-not $pat -and -not $oauth) {
            throw [System.InvalidOperationException]::new("Asana authentication is not configured. Set either the '$([AsanaApiClient]::VarKey_PAT)' or '$([AsanaApiClient]::VarKey_OAuthUsername)' variable via CLI or overlay YAML.")
        }

        # If OAuth is configured, we would normally set up the OAuth token here. Since it's not implemented, we just throw an exception below.
        if ($oauth) {
            throw [System.NotImplementedException]::new("Asana OAuth authentication ('$([AsanaApiClient]::VarKey_OAuthUsername)') is not yet implemented")
        }
        # Fall back to PAT authentication if OAuth is not configured.
        else {
            $this.bearerToken = [string]$variables.Get([AsanaApiClient]::VarKey_PAT)
        }
    }

    
    [object] InvokeApi([string]$method, [string]$path, [object]$body) {
        <#
        .SYNOPSIS
        Makes an authenticated call against the Asana API.

        .PARAMETER method
        The HTTP method to use (e.g. "POST").

        .PARAMETER path
        The Asana API path, relative to $this.baseUri (e.g. "/projects").

        .PARAMETER body
        The request body to send. Automatically wrapped in a top-level "data" property,
        per Asana API convention; pass $null for requests with no body.

        .OUTPUTS
        System.Object - the parsed JSON response (typically has a top-level "data" property).
        #>

        # Ensure we have a valid bearer token before making the API request.
        if ([string]::IsNullOrWhiteSpace($this.bearerToken)) {
            $this.Configure()
        }

        $uri = "$($this.baseUri.TrimEnd('/'))/$($path.TrimStart('/'))"

        $requestParams = @{
            Method      = $method
            Uri         = $uri
            Headers     = @{ Authorization = "Bearer $($this.bearerToken)" }
            ContentType = "application/json"
        }

        if ($null -ne $body) {
            $requestParams.Body = (@{ data = $body } | ConvertTo-Json -Depth 20)
        }

        try {
            return Invoke-RestMethod @requestParams
        }
        catch {
            # Asana returns error details as JSON (e.g. { errors: [ { message: ... } ] });
            # surface that instead of the generic HTTP exception message when available.
            $asanaMessage = $null
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                try {
                    $asanaMessage = ($_.ErrorDetails.Message | ConvertFrom-Json).errors.message -join '; '
                }
                catch {
                    $asanaMessage = $_.ErrorDetails.Message
                }
            }

            $reason = if ([string]::IsNullOrWhiteSpace($asanaMessage)) { $_.Exception.Message } else { $asanaMessage }
            throw [System.Exception]::new("Asana API request failed: $method $path - $reason", $_.Exception)
        }
    }
}
