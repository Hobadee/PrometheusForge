class passwordGenerator : TaskPluginInterface {

    [int]$length = 16
    [bool]$includeLowercase = $true
    [bool]$includeUppercase = $true
    [bool]$includeNumbers = $true
    [bool]$includeSpecial = $false
    [string]$generatedPassword = ""

    passwordGenerator() : base(){
        <#
        .SYNOPSIS
        Constructor for the passwordGenerator plugin class

        .DESCRIPTION
        This constructor initializes the passwordGenerator plugin by calling the base class constructor.
        It sets up default values for password generation options.
        #>
    }

    static [hashtable] PluginInfo() {
        <#
        .SYNOPSIS
        Gets information about the plugin

        .DESCRIPTION
        This method returns a hashtable containing plugin metadata including
        the name and other extensible properties used by the task management system.
        #>
        return @{
            name = "passwordGenerator"
            version = "1.0.0"
        }
    }

    [string] GetCharacterSet() {
        <#
        .SYNOPSIS
        Builds the character set based on enabled options

        .DESCRIPTION
        Constructs a string containing all characters that can be used
        in password generation based on the includeLowercase, includeUppercase,
        includeNumbers, and includeSpecial flags.

        .OUTPUTS
        A string containing the combined character set for password generation
        #>
        $charSet = ""
        
        if ($this.includeLowercase) {
            $charSet += "abcdefghijklmnopqrstuvwxyz"
        }
        
        if ($this.includeUppercase) {
            $charSet += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        
        if ($this.includeNumbers) {
            $charSet += "0123456789"
        }
        
        if ($this.includeSpecial) {
            $charSet += "!@#$%^&*()_+-=[]{}|;:,.<>?"
        }
        
        return $charSet
    }

    [string] GenerateRandomPassword() {
        <#
        .SYNOPSIS
        Generates a random password

        .DESCRIPTION
        Creates a completely random password by selecting random characters
        from the character set determined by the configuration options.

        .OUTPUTS
        A string containing the generated password
        #>
        $charSet = $this.GetCharacterSet()
        
        if ([string]::IsNullOrEmpty($charSet)) {
            throw [System.ArgumentException]::new("At least one character class must be enabled (lowercase, uppercase, numbers, or special characters)")
        }
        
        if ($this.length -lt 1) {
            throw [System.ArgumentException]::new("Password length must be at least 1")
        }
        
        $random = [System.Random]::new()
        $password = ""
        
        for ($i = 0; $i -lt $this.length; $i++) {
            $randomIndex = $random.Next($charSet.Length)
            $password += $charSet[$randomIndex]
        }
        
        return $password
    }

    [passwordGenerator] Execute([object]$parameters) {
        <#
        .SYNOPSIS
        Executes the passwordGenerator plugin functionality.

        .DESCRIPTION
        This method generates a random password based on configuration options
        provided in the executionData. The generated password is stored in the
        generatedPassword property and the plugin object is returned.

        .PARAMETER executionData
        An object containing password generation options:
        - length: The desired password length (default: 16)
        - includeLowercase: Include a-z characters (default: true)
        - includeUppercase: Include A-Z characters (default: true)
        - includeNumbers: Include 0-9 characters (default: true)
        - includeSpecial: Include special characters (default: false)
        #>
        
        # Parse executionData and apply options
        if ($null -ne $parameters.length) {
            $this.length = [int]$parameters.length
        }
        
        if ($null -ne $parameters.includeLowercase) {
            $this.includeLowercase = [bool]$parameters.includeLowercase
        }
        
        if ($null -ne $parameters.includeUppercase) {
            $this.includeUppercase = [bool]$parameters.includeUppercase
        }
        
        if ($null -ne $parameters.includeNumbers) {
            $this.includeNumbers = [bool]$parameters.includeNumbers
        }
        
        if ($null -ne $parameters.includeSpecial) {
            $this.includeSpecial = [bool]$parameters.includeSpecial
        }
        
        # Generate the password
        $this.generatedPassword = $this.GenerateRandomPassword()
        
        return $this
    }
    
}

# Register the passwordGenerator plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([passwordGenerator])
