class yamlSource : sourcePluginInterface {
    <#
    .SYNOPSIS
    Source plugin that loads configuration data from a YAML file or file URI.

    .DESCRIPTION
    yamlSource validates that the target URI is readable, parses the YAML content, and returns the
    resulting configuration object via the base Load() workflow.
    #>


    yamlSource([string] $URI) : base($URI) {
        <#
        .SYNOPSIS
        Initializes a yamlSource plugin with its target URI.

        .PARAMETER URI
        The URI or path to the YAML configuration file.
        #>
    }


    static [hashtable] PluginInfo() {
        return @{
            Name = 'yamlSource'
            Version = '1.0.0'
            Description = 'Loads configuration data from YAML files'
            Author = 'Eric Kincl'
        }
    }


    [bool] ValidateURI() {
        # If caller passed a relative path, make it absolute using current working directory.
        if (-not $this.URI.IsAbsoluteUri) {
            $fullPath = [System.IO.Path]::GetFullPath($this.URI.OriginalString)
            $this.URI = [System.Uri]::new($fullPath)   # becomes file:///...
        }

        if (-not $this.URI.IsFile) {
            throw [System.ArgumentException]::new(
                "URI scheme '$($this.URI.Scheme)' is not supported. Only file paths/URIs are allowed.",
                'URI'
            )
        }

        if (-not (Test-Path -LiteralPath $this.URI.LocalPath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]::new(
                "YAML source '$($this.URI)' was not found.",
                $this.URI.LocalPath
            )
        }

        return $true
    }


    [void] doLoad() {

        try {
            $yaml = Get-Content -LiteralPath $this.URI.LocalPath -Raw
        }
        catch {
            throw [System.UnauthorizedAccessException]::new("YAML source '$($this.URI)' is not readable.", $_.Exception)
        }

        $config = ConvertFrom-Yaml $yaml

        if ($null -eq $config) {
            throw [System.InvalidOperationException]::new("The YAML source '$($this.URI)' did not produce a configuration object.")
        }

        $this.LoadedConfig = $config
    }
}

[sourcePluginRegistry]::GetInstance().RegisterPlugin([yamlSource])
