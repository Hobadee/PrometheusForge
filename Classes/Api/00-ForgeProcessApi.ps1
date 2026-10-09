class ForgeProcessApi {
    <#
    .SYNOPSIS
    API to affect processing of the workflow

    .DESCRIPTION
    API to allow control of processing (e.g., starting, stopping, or modifying the workflow execution).
    #>

    hidden static [string] $StartAtSlugKey = 'ForgeAPI_StartAtSlug'

    hidden [Variables] $variables

    ForgeProcessApi() {
        <#
        .SYNOPSIS
        Constructor for the ForgeProcessApi class.

        .DESCRIPTION
        Pulls the Variables singleton internally, matching how other classes in this
        codebase (Variables, Steps, taskPluginRegistry) access their own singletons.
        #>
        $this.variables = [Variables]::GetInstance()
    }


    [void] SetStartAtSlug([string] $slug) {
        <#
        .SYNOPSIS
        Sets the starting point of processing to the specified slug.

        .DESCRIPTION
        This method sets the starting point for processing to the specified slug.
        If this is set, NO PROCESSING will occur until the workflow reaches the specified slug.
        #>

        if ([string]::IsNullOrWhiteSpace($slug)) {
            # Throw an error if the slug is null or empty
            throw [System.ArgumentException]::new("Slug cannot be null or empty.", "slug")
        }

        if (-not [Steps]::GetInstance().Exists($slug)){
            # Throw an error if the step does not exist
            throw [System.InvalidOperationException]::new("The step with the specified slug does not exist.")
        }

        if ([Steps]::GetInstance().IsProcessed($slug)) {
            # Log a warning if the step has already been processed
            # This is unusual, but it might happen if the workflow is being restarted or modified.
            [Log]::Warning("The step with the specified slug has already been processed.")
        }

        $this.variables.Set([ForgeProcessApi]::StartAtSlugKey, $slug)
    }


    [bool] HasStartAtSlug() {
        <#
        .SYNOPSIS
        Returns true while a StartAtSlug is pending (processing has not yet reached it).
        #>
        return $this.variables.HasKey([ForgeProcessApi]::StartAtSlugKey)
    }


    [string] GetStartAtSlug() {
        <#
        .SYNOPSIS
        Returns the pending StartAtSlug, or $null if none is set.
        #>
        return $this.variables.Get([ForgeProcessApi]::StartAtSlugKey)
    }


    [void] ClearStartAtSlug() {
        <#
        .SYNOPSIS
        Clears the starting point of processing.

        .DESCRIPTION
        This method removes any previously set starting point for processing.  This has the
        side effect of resuming processing if it was paused.

        .NOTES
        If processing is currently paused/skipped, (due to running up to a StartAtSlug) you
        can't actually call this from a step!
        #>
        $this.variables.Unset([ForgeProcessApi]::StartAtSlugKey)
    }
}
