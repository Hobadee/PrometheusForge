class Configuration {
    <#
    .SYNOPSIS
    Singleton class to store global Configuration information for the lifecycle run

    .DESCRIPTION
    This class provides a singleton instance that maintains Configuration state across the application.
    It includes a key/value store for arbitrary Configuration data and manages include/exclude tag collections.

    .NOTES
    This class is intended to be used as a singleton. Access via [Configuration]::GetInstance().
    All Configuration is global for the duration of the run.
    #>

    static [Configuration] $Instance = $null  # Singleton object; Explicitly initialize to $null

    static [System.Collections.Generic.Dictionary[string, object]] $KeyValueStore = $null  # Key/value store; Explicitly initialize to $null
    static [tags] $IncludeTags = $null  # Tags to include; Explicitly initialize to $null
    static [tags] $ExcludeTags = $null  # Tags to exclude; Explicitly initialize to $null


    # TODO: Consider adding methods for exporting/importing Configuration state
    # TODO: Consider adding methods for validation hooks
    # TODO: Consider adding change notifications/callbacks
    # TODO: Consider adding Configuration file loading/saving


    # Singleton handler
    static [Configuration] GetInstance() {
        if ($null -eq [Configuration]::Instance) {
            [Configuration]::Instance = [Configuration]::new()
        }
        return [Configuration]::Instance
    }


    # Constructor
    Configuration() {
        [Configuration]::KeyValueStore = [System.Collections.Generic.Dictionary[string, object]]::new()
        [Configuration]::IncludeTags = [tags]::new()
        [Configuration]::ExcludeTags = [tags]::new()
    }


    #########################
    # Configuration Handler #
    #########################


    # Validation methods
    [void] ValidateKey([object] $key) {
        <#
        .SYNOPSIS
        Validates that a key is a valid string

        .PARAMETER key
        The key to validate. Must be a non-null, non-empty string.

        .NOTES
        This method can be extended in the future with additional validation rules.
        Since this is potentially the end-location for user input via YAML, we need to accept [object] instead of
        [string], since [string] will cast the type and ruin validation.  This would be bad if the user threw an array
        in the YAML where a variable name was supposed to go.
        #>
        if ([string]::IsNullOrEmpty($key)) {
            throw [System.ArgumentNullException]::new("key", "Key cannot be null or empty")
        }
        if ($key -isnot [string]) {
            throw [System.ArgumentException]::new("Key must be a string", "key")
        }
    }


    # Key/Value Store Methods
    [void] Set([object] $key, [object] $value) {
        <#
        .SYNOPSIS
        Sets a Configuration key/value pair

        .PARAMETER key
        The Configuration key (must be a string)

        .PARAMETER value
        The Configuration value (can be any object type)

        .NOTES
        If the key already exists, its value will be overwritten.
        #>
        $this.ValidateKey($key)
        [Configuration]::KeyValueStore[$key] = $value
    }


    [object] Get([object] $key) {
        <#
        .SYNOPSIS
        Gets a Configuration value by key

        .PARAMETER key
        The Configuration key to retrieve

        .OUTPUTS
        [object] The value associated with the key, or $null if the key doesn't exist

        .NOTES
        Returns $null if the key doesn't exist. Use HasKey() to check for existence first.
        #>
        $this.ValidateKey($key)
        return [Configuration]::KeyValueStore[$key]
    }


    [bool] HasKey([object] $key) {
        <#
        .SYNOPSIS
        Checks if a Configuration key exists

        .PARAMETER key
        The Configuration key to check

        .OUTPUTS
        [bool] True if the key exists, false otherwise
        #>
        $this.ValidateKey($key)
        return [Configuration]::KeyValueStore.ContainsKey($key)
    }


    [void] Unset([object] $key) {
        <#
        .SYNOPSIS
        Removes a Configuration key/value pair

        .PARAMETER key
        The Configuration key to remove

        .NOTES
        If the key doesn't exist, this method completes silently without error.
        #>
        $this.ValidateKey($key)
        [Configuration]::KeyValueStore.Remove($key)
    }


    #############################
    # End Configuration Handler #
    #############################


    # Include Tag Management Methods
    [void] AddIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the include tags collection

        .PARAMETER tag
        The tag to add
        #>
        [Configuration]::IncludeTags.AddTag($tag)
    }


    [void] RemoveIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the include tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [Configuration]::IncludeTags.RemoveTag($tag)
    }


    [bool] HasIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Checks if a tag exists in the include tags collection

        .PARAMETER tag
        The tag to check for

        .OUTPUTS
        [bool] True if the tag exists in include tags
        #>
        return [Configuration]::IncludeTags.HasTag($tag)
    }


    [string[]] GetIncludeTags() {
        <#
        .SYNOPSIS
        Returns all include tags

        .OUTPUTS
        [string[]] Array of all include tags
        #>
        return [Configuration]::IncludeTags.GetTags()
    }


    # Exclude Tag Management Methods
    [void] AddExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the exclude tags collection

        .PARAMETER tag
        The tag to add
        #>
        [Configuration]::ExcludeTags.AddTag($tag)
    }


    [void] RemoveExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the exclude tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [Configuration]::ExcludeTags.RemoveTag($tag)
    }


    [bool] HasExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Checks if a tag exists in the exclude tags collection

        .PARAMETER tag
        The tag to check for

        .OUTPUTS
        [bool] True if the tag exists in exclude tags
        #>
        return [Configuration]::ExcludeTags.HasTag($tag)
    }


    [string[]] GetExcludeTags() {
        <#
        .SYNOPSIS
        Returns all exclude tags

        .OUTPUTS
        [string[]] Array of all exclude tags
        #>
        return [Configuration]::ExcludeTags.GetTags()
    }
    
}
