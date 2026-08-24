class processorInterface {
    <#
    .SYNOPSIS
    Defines the interface for a processor class

    .NOTES
    DRAFT - MAY NOT ACTUALLY USE
    Can we have both SourcePlugins and TaskPlugins implement this interface?
    This could make it easier for us to lazy-load external files
    #>

    Process(){
        throw [System.NotImplementedException]::new('Process must be implemented by concrete processor classes')
    }
}
