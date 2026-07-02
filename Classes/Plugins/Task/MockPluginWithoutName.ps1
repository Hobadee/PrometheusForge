class MockPluginWithoutName : TaskPluginInterface {
    MockPluginWithoutName() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = ""
            version = "1.0.0"
        }
    }
    
    [object] Execute([object]$parameters) {
        return @{ result = "executed" }
    }
}
