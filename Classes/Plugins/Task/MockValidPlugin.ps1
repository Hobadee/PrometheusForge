class MockValidPlugin : TaskPluginInterface {
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
