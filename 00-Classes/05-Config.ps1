<#
.SYNOPSIS
Config object created from YAML master file.
#>
class Config {
    [hashtable] $Defaults
    [hashtable] $Plugins
    [object[]] $Tasks

    Config([hashtable] $spec) {
        $this.Defaults = @{}
        $this.Plugins = @{}
        $this.Tasks = @()
        if ($null -ne $spec) {
            if ($spec.ContainsKey('defaults')) { $this.Defaults = $spec['defaults'] }
            if ($spec.ContainsKey('plugins')) { $this.Plugins = $spec['plugins'] }
            if ($spec.ContainsKey('tasks')) { $this.Tasks = $spec['tasks'] }
        }
    }

    [Config] ApplyOverrides([object[]] $overrides) {
        # Return a new Config with overrides applied (simple merge stub)
        $new = [Config]::new(@{})
        $new.Defaults = $this.Defaults.Clone()
        $new.Plugins = $this.Plugins.Clone()
        $new.Tasks = $this.Tasks
        return $new
    }
}
