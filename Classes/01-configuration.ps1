class configuration {
    <#
    .SYNOPSIS
    Singleton class to store global configuration information for the lifecycle run

    .DESCRIPTION
    This class provides a singleton instance that maintains configuration state across the application.
    It includes a key/value store for arbitrary configuration data and manages include/exclude tag collections.

    .NOTES
    This class is intended to be used as a singleton. Access via [configuration]::GetInstance().
    All configuration is global for the duration of the run.
    #>

    static [configuration] $Instance = $null  # Singleton object; Explicitly initialize to $null

    static [System.Collections.Generic.Dictionary[string, object]] $KeyValueStore = $null  # Key/value store; Explicitly initialize to $null
    static [tags] $IncludeTags = $null  # Tags to include; Explicitly initialize to $null
    static [tags] $ExcludeTags = $null  # Tags to exclude; Explicitly initialize to $null


    # TODO: Consider adding methods for exporting/importing configuration state
    # TODO: Consider adding methods for validation hooks
    # TODO: Consider adding change notifications/callbacks
    # TODO: Consider adding configuration file loading/saving


    # Singleton handler
    static [configuration] GetInstance() {
        if ($null -eq [configuration]::Instance) {
            [configuration]::Instance = [configuration]::new()
        }
        return [configuration]::Instance
    }


    # Constructor
    configuration() {
        [configuration]::KeyValueStore = [System.Collections.Generic.Dictionary[string, object]]::new()
        [configuration]::IncludeTags = [tags]::new()
        [configuration]::ExcludeTags = [tags]::new()
    }


    #########################
    # Configuration Handler #
    #########################


    # Validation methods
    [void] ValidateKey([string] $key) {
        <#
        .SYNOPSIS
        Validates that a key is a valid string

        .PARAMETER key
        The key to validate

        .NOTES
        This method can be extended in the future with additional validation rules.
        #>
        if ($null -eq $key) {
            throw [System.ArgumentNullException]::new("key", "Key cannot be null")
        }
        if ($key -isnot [string]) {
            throw [System.ArgumentException]::new("Key must be a string", "key")
        }
    }


    # Key/Value Store Methods
    [void] Set([string] $key, [object] $value) {
        <#
        .SYNOPSIS
        Sets a configuration key/value pair

        .PARAMETER key
        The configuration key (must be a string)

        .PARAMETER value
        The configuration value (can be any object type)

        .NOTES
        If the key already exists, its value will be overwritten.
        #>
        $this.ValidateKey($key)
        [configuration]::KeyValueStore[$key] = $value
    }


    [object] Get([string] $key) {
        <#
        .SYNOPSIS
        Gets a configuration value by key

        .PARAMETER key
        The configuration key to retrieve

        .OUTPUTS
        [object] The value associated with the key, or $null if the key doesn't exist

        .NOTES
        Returns $null if the key doesn't exist. Use HasKey() to check for existence first.
        #>
        $this.ValidateKey($key)
        return [configuration]::KeyValueStore[$key]
    }


    [bool] HasKey([string] $key) {
        <#
        .SYNOPSIS
        Checks if a configuration key exists

        .PARAMETER key
        The configuration key to check

        .OUTPUTS
        [bool] True if the key exists, false otherwise
        #>
        $this.ValidateKey($key)
        return [configuration]::KeyValueStore.ContainsKey($key)
    }


    [void] Unset([string] $key) {
        <#
        .SYNOPSIS
        Removes a configuration key/value pair

        .PARAMETER key
        The configuration key to remove

        .NOTES
        If the key doesn't exist, this method completes silently without error.
        #>
        $this.ValidateKey($key)
        [configuration]::KeyValueStore.Remove($key)
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
        [configuration]::IncludeTags.AddTag($tag)
    }


    [void] RemoveIncludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the include tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [configuration]::IncludeTags.RemoveTag($tag)
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
        return [configuration]::IncludeTags.HasTag($tag)
    }


    [string[]] GetIncludeTags() {
        <#
        .SYNOPSIS
        Returns all include tags

        .OUTPUTS
        [string[]] Array of all include tags
        #>
        return [configuration]::IncludeTags.GetTags()
    }


    # Exclude Tag Management Methods
    [void] AddExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the exclude tags collection

        .PARAMETER tag
        The tag to add
        #>
        [configuration]::ExcludeTags.AddTag($tag)
    }


    [void] RemoveExcludeTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the exclude tags collection

        .PARAMETER tag
        The tag to remove
        #>
        [configuration]::ExcludeTags.RemoveTag($tag)
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
        return [configuration]::ExcludeTags.HasTag($tag)
    }


    [string[]] GetExcludeTags() {
        <#
        .SYNOPSIS
        Returns all exclude tags

        .OUTPUTS
        [string[]] Array of all exclude tags
        #>
        return [configuration]::ExcludeTags.GetTags()
    }
    
}
