Using Module "../../../../../build/Lifecycle/Lifecycle.psd1"

Describe 'passwordGenerator Plugin - Basic Functionality' {
    Context 'Constructor and Initialization' {
        It 'Should create a passwordGenerator instance' {
            $plugin = [passwordGenerator]::new()
            $plugin | Should -Not -BeNullOrEmpty
        }

        It 'Should have default values set correctly' {
            $plugin = [passwordGenerator]::new()
            $plugin.length | Should -Be 16
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeUppercase | Should -Be $true
            $plugin.includeNumbers | Should -Be $true
            $plugin.includeSpecial | Should -Be $false
            $plugin.generatedPassword | Should -Be ""
        }

        It 'Should inherit from TaskPluginInterface' {
            $plugin = [passwordGenerator]::new()
            $expectedType = [TaskPluginInterface]
            $plugin | Should -BeOfType $expectedType
        }
    }

    Context 'PluginInfo Static Method' {
        It 'Should return plugin information as hashtable' {
            $info = [passwordGenerator]::PluginInfo()
            $info | Should -Not -BeNullOrEmpty
            $info.GetType().Name | Should -Be "Hashtable"
        }

        It 'Should have correct plugin name' {
            $info = [passwordGenerator]::PluginInfo()
            $info['name'] | Should -Be "passwordGenerator"
        }

        It 'Should have version information' {
            $info = [passwordGenerator]::PluginInfo()
            $info['version'] | Should -Not -BeNullOrEmpty
            $info['version'] | Should -Be "1.0.0"
        }
    }
}

Describe 'passwordGenerator Plugin - Character Set Generation' {
    Context 'GetCharacterSet Method' {
        It 'Should include lowercase letters when includeLowercase is true' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Match "a"
            $charSet | Should -Match "z"
            $charSet | Should -Match "^[a-z]+$"
        }

        It 'Should include uppercase letters when includeUppercase is true' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $true
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Match "A"
            $charSet | Should -Match "Z"
            $charSet | Should -Match "^[A-Z]+$"
        }

        It 'Should include numbers when includeNumbers is true' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $true
            $plugin.includeSpecial = $false
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Match "[0-9]"
        }

        It 'Should include special characters when includeSpecial is true' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $true
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Match "!"
            $charSet | Should -Match "@"
            $charSet | Should -Match "#"
        }

        It 'Should combine multiple character sets correctly' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $true
            $plugin.includeNumbers = $true
            $plugin.includeSpecial = $false
            
            $charSet = $plugin.GetCharacterSet()
            $charSet.Length | Should -BeGreaterThan 50
            $charSet | Should -Match "[a-z]"
            $charSet | Should -Match "[A-Z]"
            $charSet | Should -Match "[0-9]"
        }

        It 'Should include all character sets when all are enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $true
            $plugin.includeNumbers = $true
            $plugin.includeSpecial = $true
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Match "[a-z]"
            $charSet | Should -Match "[A-Z]"
            $charSet | Should -Match "[0-9]"
            $charSet | Should -Match "!"
        }

        It 'Should return empty string when all character sets are disabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $charSet = $plugin.GetCharacterSet()
            $charSet | Should -Be ""
        }
    }
}

Describe 'passwordGenerator Plugin - Password Generation' {
    Context 'GenerateRandomPassword Method' {
        It 'Should generate a password with the specified length' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 16
            
            $password = $plugin.GenerateRandomPassword()
            $password.Length | Should -Be 16
        }

        It 'Should generate different passwords on successive calls' {
            $plugin = [passwordGenerator]::new()
            
            $password1 = $plugin.GenerateRandomPassword()
            $password2 = $plugin.GenerateRandomPassword()
            
            $password1 | Should -Not -Be $password2
        }

        It 'Should respect custom length values' {
            @(1, 5, 10, 20, 50, 100) | ForEach-Object {
                $plugin = [passwordGenerator]::new()
                $plugin.length = $_
                
                $password = $plugin.GenerateRandomPassword()
                $password.Length | Should -Be $_
            }
        }

        It 'Should only contain lowercase letters when only lowercase is enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 100
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $password = $plugin.GenerateRandomPassword()
            $password | Should -Match "^[a-z]+$"
        }

        It 'Should only contain uppercase letters when only uppercase is enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 100
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $true
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $password = $plugin.GenerateRandomPassword()
            $password | Should -Match "^[A-Z]+$"
        }

        It 'Should only contain digits when only numbers are enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 100
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $true
            $plugin.includeSpecial = $false
            
            $password = $plugin.GenerateRandomPassword()
            $password | Should -Match "^[0-9]+$"
        }

        It 'Should only contain special characters when only special is enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 100
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $true
            
            $password = $plugin.GenerateRandomPassword()
            # Verify password contains only special chars from the charset
            $specialChars = "!@#\$%^&*()_+-=[]{}|;:,.<>?"
            
            # Check that all characters are in the special charset
            foreach ($char in $password.ToCharArray()) {
                $char | Should -Match "[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]"
            }
        }

        It 'Should throw when no character sets are enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $false
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $exceptionType = [System.ArgumentException]
            { $plugin.GenerateRandomPassword() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw when length is less than 1' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 0
            
            $exceptionType = [System.ArgumentException]
            { $plugin.GenerateRandomPassword() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw when length is negative' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = -5
            
            $exceptionType = [System.ArgumentException]
            { $plugin.GenerateRandomPassword() } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should generate a valid password of length 1' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 1
            
            $password = $plugin.GenerateRandomPassword()
            $password.Length | Should -Be 1
        }

        It 'Should generate a valid password with all character sets enabled' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 50
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $true
            $plugin.includeNumbers = $true
            $plugin.includeSpecial = $true
            
            $password = $plugin.GenerateRandomPassword()
            $password.Length | Should -Be 50
            # At least some characters from the expanded charset
            $password | Should -Not -BeNullOrEmpty
        }

        It 'Should generate random passwords that are statistically different' {
            $plugin = [passwordGenerator]::new()
            $passwords = @()
            
            # Generate 10 passwords and collect them
            for ($i = 0; $i -lt 10; $i++) {
                $passwords += $plugin.GenerateRandomPassword()
            }
            
            # This is a pretty crappy test - I blame AI.  :'-D
            # TODO: Make this test ACTUALLY check for statistical difference
            # Check that at least 8 are unique (allowing for slight collision possibility)
            $uniquePasswords = $passwords | Select-Object -Unique
            $uniquePasswords.Count | Should -BeGreaterThan 7
        }
    }
}

Describe 'passwordGenerator Plugin - Execute Method' {
    Context 'Execute with Default Configuration' {
        It 'Should execute and return the plugin instance' {
            $plugin = [passwordGenerator]::new()
            $result = $plugin.Execute([pscustomobject]@{ length = 16 })
            
            $result | Should -Be $plugin
        }

        It 'Should generate a password using default settings' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute([pscustomobject]@{ length = 16 })
            
            $plugin.generatedPassword | Should -Not -BeNullOrEmpty
            $plugin.generatedPassword.Length | Should -Be 16
        }

        It 'Should store password in generatedPassword property' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute([pscustomobject]@{ length = 16 })
            
            $plugin.generatedPassword | Should -Not -Be ""
            $plugin.generatedPassword | Should -BeOfType [string]
        }
    }

    Context 'Execute with Custom Length' {
        It 'Should apply custom length from executionData' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ length = 32 })
            
            $plugin.generatedPassword.Length | Should -Be 32
            $plugin.length | Should -Be 32
        }

        It 'Should handle various length values' {
            @(8, 16, 24, 50, 100) | ForEach-Object {
                $plugin = [passwordGenerator]::new()
                $plugin.Execute(@{ length = $_ })
                
                $plugin.generatedPassword.Length | Should -Be $_
                $plugin.length | Should -Be $_
            }
        }
    }

    Context 'Execute with Character Set Options' {
        It 'Should apply includeLowercase option' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $true
                includeUppercase = $false
                includeNumbers = $false
                includeSpecial = $false
                length = 100
            })
            
            $plugin.includeLowercase | Should -Be $true
            $plugin.generatedPassword | Should -Match "^[a-z]+$"
        }

        It 'Should apply includeUppercase option' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $false
                includeUppercase = $true
                includeNumbers = $false
                includeSpecial = $false
                length = 100
            })
            
            $plugin.includeUppercase | Should -Be $true
            $plugin.generatedPassword | Should -Match "^[A-Z]+$"
        }

        It 'Should apply includeNumbers option' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $false
                includeUppercase = $false
                includeNumbers = $true
                includeSpecial = $false
                length = 100
            })
            
            $plugin.includeNumbers | Should -Be $true
            $plugin.generatedPassword | Should -Match "^[0-9]+$"
        }

        It 'Should apply includeSpecial option' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $false
                includeUppercase = $false
                includeNumbers = $false
                includeSpecial = $true
                length = 100
            })
            
            $plugin.includeSpecial | Should -Be $true
            # Verify special characters are present
            $plugin.generatedPassword | Should -Match "[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]"
        }

        It 'Should apply all character set options together' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $true
                includeUppercase = $true
                includeNumbers = $true
                includeSpecial = $true
                length = 50
            })
            
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeUppercase | Should -Be $true
            $plugin.includeNumbers | Should -Be $true
            $plugin.includeSpecial | Should -Be $true
            $plugin.generatedPassword.Length | Should -Be 50
        }
    }

    Context 'Execute with Null or Partial executionData' {
        It 'Should preserve default values when unspecified' {
            $plugin = [passwordGenerator]::new()
            
            $plugin.length | Should -Be 16
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeUppercase | Should -Be $true
            $plugin.includeNumbers | Should -Be $true
            $plugin.includeSpecial | Should -Be $false
        }

        It 'Should preserve unspecified values when executionData is partial' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute([pscustomobject]@{ length = 24 })
            
            $plugin.length | Should -Be 24
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeUppercase | Should -Be $true
            $plugin.includeNumbers | Should -Be $true
            $plugin.includeSpecial | Should -Be $false
        }

        It 'Should only modify specified properties' {
            $plugin = [passwordGenerator]::new()
            $initialLength = $plugin.length
            $data = [pscustomobject]@{ includeSpecial = $true; length = 20 }
            $plugin.Execute($data)
            
            $plugin.length | Should -Be 20
            $plugin.includeSpecial | Should -Be $true
            $plugin.includeLowercase | Should -Be $true  # Should remain default
        }
    }

    Context 'Execute Randomness and Idempotence' {
        It 'Should generate different passwords on successive executions' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{})
            $password1 = $plugin.generatedPassword
            
            $plugin.Execute(@{})
            $password2 = $plugin.generatedPassword
            
            $password1 | Should -Not -Be $password2
        }

        It 'Should generate different passwords with same configuration' {
            $plugin1 = [passwordGenerator]::new()
            $plugin1.Execute(@{ length = 32 })
            $password1 = $plugin1.generatedPassword
            
            $plugin2 = [passwordGenerator]::new()
            $plugin2.Execute(@{ length = 32 })
            $password2 = $plugin2.generatedPassword
            
            $password1 | Should -Not -Be $password2
        }

        It 'Should update generatedPassword on each Execute call' {
            $plugin = [passwordGenerator]::new()
            
            $plugin.Execute(@{ length = 10 })
            $password1 = $plugin.generatedPassword
            
            $plugin.Execute(@{ length = 10 })
            $password2 = $plugin.generatedPassword
            
            $plugin.generatedPassword | Should -Be $password2
            $plugin.generatedPassword | Should -Not -Be $password1
        }
    }
}

Describe 'passwordGenerator Plugin - Integration and Edge Cases' {
    Context 'Property Modification and Regeneration' {
        It 'Should regenerate password after property changes' {
            $plugin = [passwordGenerator]::new()
            $plugin.length = 16
            $password1 = $plugin.GenerateRandomPassword()
            
            $plugin.length = 32
            $password2 = $plugin.GenerateRandomPassword()
            
            $password2.Length | Should -Be 32
            $password2.Length | Should -Not -Be $password1.Length
        }

        It 'Should generate valid password after disabling character sets' {
            $plugin = [passwordGenerator]::new()
            $plugin.includeLowercase = $true
            $plugin.includeUppercase = $false
            $plugin.includeNumbers = $false
            $plugin.includeSpecial = $false
            
            $plugin.Execute(@{})
            $plugin.generatedPassword | Should -Match "^[a-z]+$"
        }
    }

    Context 'Data Type Conversion' {
        It 'Should convert string length to integer' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ length = "24" })
            
            $plugin.length | Should -Be 24
            $plugin.length | Should -BeOfType [int]
        }

        It 'Should convert numeric values to booleans (non-zero is true)' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = 1
                includeSpecial = 0
            })
            
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeSpecial | Should -Be $false
        }

        It 'Should convert boolean values directly' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ 
                includeLowercase = $true
                includeSpecial = $false
            })
            
            $plugin.includeLowercase | Should -Be $true
            $plugin.includeSpecial | Should -Be $false
        }
    }

    Context 'Large Password Lengths' {
        It 'Should generate a password of length 1000' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ length = 1000 })
            
            $plugin.generatedPassword.Length | Should -Be 1000
        }

        It 'Should generate a password of length 10000' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute(@{ length = 10000 })
            
            $plugin.generatedPassword.Length | Should -Be 10000
        }
    }

    Context 'Character Distribution' {
        It 'Should have reasonable character distribution in large password' {
            $plugin = [passwordGenerator]::new()
            $plugin.Execute([pscustomobject]@{ 
                length = 1000
                includeLowercase = $true
                includeUppercase = $false
                includeNumbers = $false
                includeSpecial = $false
            })
            $password = $plugin.generatedPassword
            
            # Count unique characters
            $uniqueChars = ($password.ToCharArray() | Select-Object -Unique).Count
            
            # With lowercase alphabet (26 chars) and 1000 character password,
            # we should see a decent variety
            $uniqueChars | Should -BeGreaterThan 5
        }
    }
}
