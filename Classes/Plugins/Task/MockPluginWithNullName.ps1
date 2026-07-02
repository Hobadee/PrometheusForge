class MockPluginWithNullName : TaskPluginInterface {
    MockPluginWithNullName() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = $null
            version = "1.0.0"
        }
    }
    
    [object] Execute([object]$parameters) {
        return @{ result = "executed" }
    }
}
