class MockValidPlugin : TaskPluginInterface {
    MockValidPlugin() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = "MockValidPlugin"
            version = "1.0.0"
        }
    }
    
    [object] Execute([object]$parameters) {
        return @{ result = "executed" }
    }
}
