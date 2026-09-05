class ItemSection : ItemInterface, System.Collections.IEnumerable {
    <#
    .SYNOPSIS
    Represents a composite checklist node that contains and executes child items.

    .DESCRIPTION
    ItemSection is the container implementation of ItemInterface.
    It holds an ordered collection of child ItemInterface instances (steps or nested sections),
    provides index-based navigation for the current child, supports enumeration, and can execute
    either the current item or all child items.

    During construction, ItemSection can materialize child nodes from configuration by delegating
    to ItemFactory. This enables recursive checklist hierarchies composed of sections and steps.

    .INPUTS
    A configuration object (typically from YAML) with:
    - name  : string
    - type  : "section"
    - items : optional enumerable of child item configuration nodes

    .OUTPUTS
    System.Boolean from Process, ProcessCurrentItem, and ProcessAllItems.
    System.Int32 from Count.
    ItemInterface from GetCurrentItem.
    System.Collections.IEnumerator from GetEnumerator.

    .NOTES
    Child ordering is preserved as items are added.
    currentIndex defaults to 0 and is validated by SetCurrentIndex.

    .EXAMPLE
    YAML section mapped to ItemSection:
    name: Provisioning
    type: section
    items:
        - name: Generate Password
            type: step
            plugin: PasswordGenerator
            parameters:
                length: 20
        - name: Enrollment
            type: section
            items:
                - name: Run MDM Enrollment
                    type: step
                    plugin: TextOutput
                    parameters:
                        message: "Enroll device"
    #>


    # TODO: All documentation generated with AI - verify accuracy and completeness before use.


    <#
    .SYNOPSIS
    Stores child checklist items for this section.

    .DESCRIPTION
    Ordered list containing ItemInterface-derived objects managed by this section.
    Use Add() to append validated child items.
    #>
    [System.Collections.Generic.List[ItemInterface]] $items = [System.Collections.Generic.List[ItemInterface]]::new()

    <#
    .SYNOPSIS
    Tracks which child item is considered current.

    .DESCRIPTION
    Zero-based index used by GetCurrentItem().
    Update using SetCurrentIndex() to enforce bounds validation.
    #>
    [int] $currentIndex = 0


    ItemSection([object]$config) : base($config) {
        <#
        .SYNOPSIS
        Initializes a new ItemSection and loads child items from configuration.

        .DESCRIPTION
        Calls the ItemInterface base constructor to validate shared item metadata.
        If config.items is provided and enumerable, each child configuration object is converted
        to an ItemInterface implementation via ItemFactory and appended using Add().

        This constructor enables recursive section trees where nested sections and steps are
        built from the same configuration shape.

        .PARAMETER config
        Section configuration object.
        - Required: name
        - Optional: items (enumerable child configurations)

        .NOTES
        Child objects are created in source order.
        ItemFactory throws for unknown child item types.
        #>
        if ($null -ne $config.items -and $config.items -is [System.Collections.IEnumerable]) {
            foreach ($itemConfig in $config.items) {
                $this.Add([ItemFactory]::Create($itemConfig))
            }
        }
    }


    [void] Add([ItemInterface] $item) {
        <#
        .SYNOPSIS
        Adds a child item to the section.

        .DESCRIPTION
        Appends an ItemInterface-derived object to the internal items collection.
        Null values are rejected to maintain collection integrity.

        .PARAMETER item
        Child item to add. Must not be null.

        .NOTES
        Insertion order determines execution and enumeration order.
        #>
        if ($null -eq $item) {
            throw [System.ArgumentNullException]::new("item", "Item cannot be null")
        }

        $this.items.Add($item)
        Write-Debug "Added item '$($item.name)' to section '$($this.name)'. Total items: $($this.items.Count)"
    }


    [int] Count() {
        <#
        .SYNOPSIS
        Returns the number of child items in the section.

        .OUTPUTS
        System.Int32 child count.
        #>
        return $this.items.Count
    }


    [void] SetCurrentIndex([int] $index) {
        <#
        .SYNOPSIS
        Sets the current child index used for targeted execution.

        .DESCRIPTION
        Validates that index is within the bounds of the current items collection,
        then updates currentIndex.

        .PARAMETER index
        Zero-based child index.

        .NOTES
        Throws ArgumentOutOfRangeException when index is less than 0 or greater than
        the last valid child index.
        #>
        if ($index -lt 0 -or $index -ge $this.items.Count) {
            throw [System.ArgumentOutOfRangeException]::new(
                "index",
                "Index must be between 0 and $($this.items.Count - 1)"
            )
        }

        $this.currentIndex = $index
    }


    [ItemInterface] GetCurrentItem() {
        <#
        .SYNOPSIS
        Gets the currently selected child item.

        .DESCRIPTION
        Returns the item at currentIndex.
        Throws if the section contains no items.

        .OUTPUTS
        ItemInterface currently selected child.

        .NOTES
        Use SetCurrentIndex() to switch the selected item safely.
        #>
        if ($this.items.Count -eq 0) {
            throw [System.InvalidOperationException]::new("No items are available")
        }

        return $this.items[$this.currentIndex]
    }


    [System.Collections.IEnumerator] GetEnumerator() {
        <#
        .SYNOPSIS
        Returns an enumerator over child items.

        .DESCRIPTION
        Enables foreach iteration for ItemSection by exposing the internal list enumerator.

        .OUTPUTS
        System.Collections.IEnumerator over ItemInterface children.
        #>
        return $this.items.GetEnumerator()
    }


    [object] ProcessCurrentItem() {
        <#
        .SYNOPSIS
        Executes the currently selected child item.

        .DESCRIPTION
        Resolves the child at currentIndex via GetCurrentItem() and invokes its Process() method.

        .OUTPUTS
        System.Object. Returns the selected child's Process() result.

        .NOTES
        Throws InvalidOperationException when the section contains no child items.
        #>
        $currentItem = [object]$this.GetCurrentItem()
        return $currentItem.Process()
    }


    [object] ProcessAllItems() {
        <#
        .SYNOPSIS
        Executes all child items in order.

        .DESCRIPTION
        Iterates through the internal child list and calls Process() on each child.
        Child return values are not aggregated; this method returns $true after iteration.

        .OUTPUTS
        System.Object. Returns $true after processing the collection.

        .NOTES
        Child-level exception handling is delegated to child implementations.
        If a child throws, execution of this method stops and the exception bubbles up.

        .EXAMPLE
        Invoke all child items for a section:
        $section = [ItemSection]::new($config)
        $ok = $section.ProcessAllItems()
        # $ok is $true when all child calls complete without terminating errors.
        #>
        foreach ($item in $this.items) {
            ([object]$item).Process()
        }
        return $true
    }


    [object] Process() {
        <#
        .SYNOPSIS
        Executes the currently selected child item.

        .DESCRIPTION
        ItemSection's default Process() behavior is current-item execution based on currentIndex.
        Use ProcessAllItems() when the entire section should be processed in sequence.

        .OUTPUTS
        System.Boolean. Returns the selected child's Process() result.
        #>
        return $this.ProcessAllItems()
    }
}
