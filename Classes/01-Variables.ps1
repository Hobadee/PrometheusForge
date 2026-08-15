class Variables {
    <#
    .SYNOPSIS
    Singleton class to store global Variables information for the lifecycle run

    .DESCRIPTION
    This class provides a singleton instance that maintains Variables state across the application.
    It includes a key/value store for arbitrary Variables data and manages include/exclude tag collections.

    .NOTES
    This class is intended to be used as a singleton. Access via [Variables]::GetInstance().
    All Variables is global for the duration of the run.
    #>

    static [Variables] $Instance = $null  # Singleton object; Explicitly initialize to $null

    static [System.Collections.Generic.Dictionary[string, object]] $KeyValueStore = $null  # Key/value store; Explicitly initialize to $null
    static [tags] $IncludeTags = $null  # Tags to include; Explicitly initialize to $null
    static [tags] $ExcludeTags = $null  # Tags to exclude; Explicitly initialize to $null


    # TODO: Consider adding methods for exporting/importing Variables state
    # TODO: Consider adding methods for validation hooks
    # TODO: Consider adding change notifications/callbacks
    # TODO: Consider adding Variables file loading/saving


    # Singleton handler
    static [Variables] GetInstance() {
        if ($null -eq [Variables]::Instance) {
            [Variables]::Instance = [Variables]::new()
        }
        return [Variables]::Instance
    }


    # Constructor
    Variables() {
        [Variables]::KeyValueStore = [System.Collections.Generic.Dictionary[string, object]]::new()
        [Variables]::IncludeTags = [tags]::new()
        [Variables]::ExcludeTags = [tags]::new()
    }


    #########################
    # Variables Handler #
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
        Sets a Variables key/value pair

        .PARAMETER key
        The Variables key (must be a string)

        .PARAMETER value
        The Variables value (can be any object type)

        .NOTES
        If the key already exists, its value will be overwritten.
        #>
        $this.ValidateKey($key)
        [Variables]::KeyValueStore[$key] = $value
    }


    [void] SetMany([object] $entries) {
        <#
        .SYNOPSIS
        Sets multiple Variables key/value pairs in one operation.

        .PARAMETER entries
        A dictionary/map of keys and values to apply to Variables.

        .NOTES
        If entries is $null, this method is a no-op.
        Keys are validated through Set(). Existing keys are overwritten.
        #>
        if ($null -eq $entries) {
            return
        }

        if ($entries -isnot [System.Collections.IDictionary]) {
            throw [System.ArgumentException]::new("Variables.SetMany expects a dictionary/map.", "entries")
        }

        foreach ($key in $entries.Keys) {
            $this.Set($key, $entries[$key])
        }
    }


    [object] Get([object] $key) {
        <#
        .SYNOPSIS
        Gets a Variables value by key

        .PARAMETER key
        The Variables key to retrieve

        .OUTPUTS
        [object] The value associated with the key, or $null if the key doesn't exist

        .NOTES
        Returns $null if the key doesn't exist. Use HasKey() to check for existence first.
        #>
        $this.ValidateKey($key)
        return [Variables]::KeyValueStore[$key]
    }


    [bool] HasKey([object] $key) {
        <#
        .SYNOPSIS
        Checks if a Variables key exists

        .PARAMETER key
        The Variables key to check

        .OUTPUTS
        [bool] True if the key exists, false otherwise
        #>
        $this.ValidateKey($key)
        return [Variables]::KeyValueStore.ContainsKey($key)
    }


    [void] Unset([object] $key) {
        <#
        .SYNOPSIS
        Removes a Variables key/value pair

        .PARAMETER key
        The Variables key to remove

        .NOTES
        If the key doesn't exist, this method completes silently without error.
        #>
        $this.ValidateKey($key)
        [Variables]::KeyValueStore.Remove($key)
    }


    #############################
    # End Variables Handler #
    #############################


    # Include Tag Management Methods
    [void] AddIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the include tags collection

        .PARAMETER tag
        The tag to add
        #>
        [Variables]::IncludeTags.AddTag($tag)
    }


    [void] RemoveIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the include tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [Variables]::IncludeTags.RemoveTag($tag)
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
        return [Variables]::IncludeTags.HasTag($tag)
    }


    [string[]] GetIncludeTags() {
        <#
        .SYNOPSIS
        Returns all include tags

        .OUTPUTS
        [string[]] Array of all include tags
        #>
        return [Variables]::IncludeTags.GetTags()
    }


    # Exclude Tag Management Methods
    [void] AddExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the exclude tags collection

        .PARAMETER tag
        The tag to add
        #>
        [Variables]::ExcludeTags.AddTag($tag)
    }


    [void] RemoveExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the exclude tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [Variables]::ExcludeTags.RemoveTag($tag)
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
        return [Variables]::ExcludeTags.HasTag($tag)
    }


    [string[]] GetExcludeTags() {
        <#
        .SYNOPSIS
        Returns all exclude tags

        .OUTPUTS
        [string[]] Array of all exclude tags
        #>
        return [Variables]::ExcludeTags.GetTags()
    }
    
}

