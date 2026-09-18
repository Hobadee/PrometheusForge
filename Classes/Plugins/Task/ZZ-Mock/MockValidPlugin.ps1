class MockValidPlugin : TaskPluginInterface {
    <#
    .SYNOPSIS
    Valid mock plugin used to verify plugin registration and execution flows.

    .PARAMETER $null
    This mock plugin accepts no required parameters. It is used as a baseline plugin for tests that verify a successful plugin registration and execution cycle.
    #>
    MockValidPlugin() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = "MockValidPlugin"
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
