class AnotherMockPlugin : TaskPluginInterface {
    <#
    .SYNOPSIS
    Mock plugin used for registry and plugin discovery tests.

    .PARAMETER $null
    This mock plugin accepts no required parameters. It is intentionally minimal and only validates
    that the object exists so tests can exercise registry behavior without a real external dependency.
    #>
    AnotherMockPlugin() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = "AnotherMockPlugin"
            version = "1.0.0"
        }
    }
    
    [void] ValidateParameters([object]$params) {
        # Mock plugins do minimal validation
    }

    [object] Execute() {
        return @{ result = "executed" }
    }
}

# DO NOT LOAD!  Used for unit testing only!
