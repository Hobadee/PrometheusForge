class AnotherMockPlugin : TaskPluginInterface {
    AnotherMockPlugin() : base() {}
    
    static [hashtable] PluginInfo() {
        return @{
            name = "AnotherMockPlugin"
            version = "1.0.0"
        }
    }
    
    [object] Execute([object]$parameters) {
        return @{ result = "executed" }
    }
}
