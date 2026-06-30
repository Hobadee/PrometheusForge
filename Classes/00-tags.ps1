class tags {
    <#
    .SYNOPSIS
    Manages a collection of string tags

    .DESCRIPTION
    This class provides a reusable mechanism for managing a collection of string tags.
    It supports adding, removing, and querying tags in a type-safe manner.

    .NOTES
    This class is designed to be reusable across the application for any tag collection management needs.
    #>

    [System.Collections.Generic.List[string]] $TagList = [System.Collections.Generic.List[string]]::new()

    # Constructor
    tags() {
        # Initialize with empty tag list
    }

    # TODO: Consider adding case-sensitivity options
    # TODO: Consider adding tag validation/normalization
    # TODO: Consider adding batch operations (AddTags, RemoveTags with multiple values)


    [tags] AddTag([string] $tag) {
        <#
        .SYNOPSIS
        Adds a tag to the collection if it doesn't already exist

        .PARAMETER tag
        The tag string to add

        .OUTPUTS
        [tags] The current instance of the tags class, allowing for method chaining

        .NOTES
        Duplicate tags are not added; only unique tags are stored.
        #>
        if (-not $this.HasTag($tag)) {
            $this.TagList.Add($tag)
        }
        return $this
    }


    [tags] RemoveTag([string] $tag) {
        <#
        .SYNOPSIS
        Removes a tag from the collection

        .PARAMETER tag
        The tag string to remove

        .OUTPUTS
        [tags] The current instance of the tags class, allowing for method chaining

        .NOTES
        If the tag doesn't exist, this method completes silently without error.
        #>
        $this.TagList.Remove($tag)
        return $this
    }


    [bool] HasTag([string] $tag) {
        <#
        .SYNOPSIS
        Checks if a tag exists in the collection

        .PARAMETER tag
        The tag string to check for

        .OUTPUTS
        [bool] True if the tag exists, false otherwise
        #>
        return $this.TagList.Contains($tag)
    }


    [string[]] GetTags() {
        <#
        .SYNOPSIS
        Returns all tags in the collection

        .OUTPUTS
        [string[]] Array of all tags in the collection
        #>
        return $this.TagList.ToArray()
    }


    [tags] Clear() {
        <#
        .SYNOPSIS
        Removes all tags from the collection

        .OUTPUTS
        [tags] The current instance of the tags class, allowing for method chaining

        .NOTES
        After this call, the tag collection will be empty.
        #>
        $this.TagList.Clear()
        return $this
    }


    [int] Count() {
        <#
        .SYNOPSIS
        Returns the number of tags in the collection

        .OUTPUTS
        [int] The count of tags
        #>
        return $this.TagList.Count
    }

}
