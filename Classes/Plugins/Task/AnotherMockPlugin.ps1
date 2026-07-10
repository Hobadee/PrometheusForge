class AnotherMockPlugin : TaskPluginInterface {
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
