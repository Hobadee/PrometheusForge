function Get-ForgeStepResults {
    <#
    .SYNOPSIS
    Gets the full result of a step from the most recent Invoke-Forge run.

    .DESCRIPTION
    Returns the entire result object recorded for the step with the given slug, exactly as the task plugin
    returned it (success flag, execution time, error, and any plugin-specific data).

    An error is raised if no step with that slug exists.  If the step exists but has not run, nothing is
    returned.

    The results are kept until the next Invoke-Forge run starts, which discards them.

    .PARAMETER Slug
    The slug of the step to get the result for.

    .OUTPUTS
    System.Object
    The step's complete result.  Nothing is returned if the step has not run.

    .EXAMPLE
    $result = Get-ForgeStepResults -Slug 'create-user'
    $result.success

    Captures the full result of the step with the slug 'create-user'.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Slug
    )

    process {
        $steps = [Steps]::GetInstance()

        if (-not $steps.Exists($Slug)) {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.ArgumentException]::new("No step with the slug '$Slug' exists."),
                    'StepNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Slug
                )
            )
        }

        # Wrap in a local so a hashtable result is emitted as one object, not unrolled.
        $result = $steps.GetResult($Slug)
        if ($null -ne $result) {
            , $result
        }
    }
}
