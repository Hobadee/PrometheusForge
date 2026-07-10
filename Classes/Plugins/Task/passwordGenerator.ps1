class PasswordGenerator : TaskPluginInterface {

    [int]$length = 16
    [bool]$includeLowercase = $true
    [bool]$includeUppercase = $true
    [bool]$includeNumbers = $true
    [bool]$includeSpecial = $false
    [string]$generatedPassword = ""

    PasswordGenerator() : base(){
        <#
        .SYNOPSIS
        Constructor for the PasswordGenerator plugin class

        .DESCRIPTION
        This constructor initializes the PasswordGenerator plugin by calling the base class constructor.
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
            name = "PasswordGenerator"
            version = "1.0.0"
        }
    }

    [void] ValidateParameters([object]$params) {
        <#
        .SYNOPSIS
        Validates and extracts password generation parameters.

        .DESCRIPTION
        Validates that parameters are valid and extracts password generation options.
        Applies validated options to instance variables (early validation model).

        .PARAMETER params
        An object containing optional password generation options:
        - length: The desired password length (must be >= 1)
        - includeLowercase: Include a-z characters
        - includeUppercase: Include A-Z characters
        - includeNumbers: Include 0-9 characters
        - includeSpecial: Include special characters

        .NOTES
        I'm not a huge fan of double-storing parameters - I would rather directly reference the $this.parameters object for accessing parameter values
        however this is what AI generated and I am leaving it as-is for now, even though it duplicates parameter storage.
        #>
        
        if ($null -ne $params.length) {
            try {
                $this.length = [int]$params.length
                if ($this.length -lt 1) {
                    throw [System.ArgumentException]::new("Password length must be at least 1")
                }
            }
            catch [System.InvalidCastException] {
                throw [System.ArgumentException]::new("Parameter 'length' must be a valid integer")
            }
        }
        
        if ($null -ne $params.includeLowercase) {
            $this.includeLowercase = [bool]$params.includeLowercase
        }
        
        if ($null -ne $params.includeUppercase) {
            $this.includeUppercase = [bool]$params.includeUppercase
        }
        
        if ($null -ne $params.includeNumbers) {
            $this.includeNumbers = [bool]$params.includeNumbers
        }
        
        if ($null -ne $params.includeSpecial) {
            $this.includeSpecial = [bool]$params.includeSpecial
        }
        
        # Validate that at least one character class is enabled
        if (-not ($this.includeLowercase -or $this.includeUppercase -or $this.includeNumbers -or $this.includeSpecial)) {
            throw [System.ArgumentException]::new("At least one character class must be enabled (lowercase, uppercase, numbers, or special)")
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
            throw [System.ArgumentException]::new("At least one character class must be enabled")
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

    [PasswordGenerator] Execute() {
        <#
        .SYNOPSIS
        Executes the PasswordGenerator plugin functionality.

        .DESCRIPTION
        Generates a random password based on configuration options that were
        previously validated and stored via SetParameters() / ValidateParameters().
        The generated password is stored in the generatedPassword property.
        #>
        
        # Generate the password using pre-validated and stored options
        $this.generatedPassword = $this.GenerateRandomPassword()
        
        return $this
    }
    
}

# Register the PasswordGenerator plugin with the task plugin system
[taskPluginRegistry]::GetInstance().RegisterPlugin([PasswordGenerator])
