class MockPluginWithNullName : TaskPluginInterface {
    <#
    .SYNOPSIS
    Invalid mock plugin used to verify null plugin names are rejected.

    .PARAMETER $null
    This mock plugin accepts no required parameters; the invalid condition is the null name returned by PluginInfo().
    #>
    MockPluginWithNullName() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = $null
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
