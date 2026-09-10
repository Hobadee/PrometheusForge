Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"


Describe 'Variables Singleton Pattern' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
    }

    Context 'GetInstance' {
        It 'Should create a new instance on first call' {
            $instance1 = [Variables]::GetInstance()
            $instance1 | Should -Not -BeNullOrEmpty
        }

        It 'Should return the same instance on subsequent calls' {
            $instance1 = [Variables]::GetInstance()
            $instance2 = [Variables]::GetInstance()
            $instance1 | Should -Be $instance2
        }

        It 'Should initialize KeyValueStore as empty dictionary' {
            [Variables]::GetInstance()
            $expectedType = [System.Collections.Generic.Dictionary[string, object]]
            [Variables]::KeyValueStore | Should -BeOfType $expectedType
            [Variables]::KeyValueStore.Count | Should -Be 0
        }

        It 'Should initialize IncludeTags as tags object' {
            [Variables]::GetInstance()
            $expectedType = [tags]
            [Variables]::IncludeTags | Should -BeOfType $expectedType
        }

        It 'Should initialize ExcludeTags as tags object' {
            [Variables]::GetInstance()
            $expectedType = [tags]
            [Variables]::ExcludeTags | Should -BeOfType $expectedType
        }
    }
}

Describe 'Key/Value Store Operations' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        $config = [Variables]::GetInstance()
    }

    Context 'Set and Get' {
        It 'Should set and retrieve a string value' {
            $config.Set('testKey', 'testValue')
            $config.Get('testKey') | Should -Be 'testValue'
        }

        It 'Should set and retrieve an integer value' {
            $config.Set('intKey', 42)
            $config.Get('intKey') | Should -Be 42
        }

        It 'Should set and retrieve an object value' {
            $obj = @{ name = 'test'; value = 123 }
            $config.Set('objKey', $obj)
            $config.Get('objKey') | Should -Be $obj
        }

        It 'Should set and retrieve an array value' {
            $arr = @('a', 'b', 'c')
            $config.Set('arrayKey', $arr)
            $config.Get('arrayKey') | Should -Be $arr
        }

        It 'Should set and retrieve $null value' {
            $config.Set('nullKey', $null)
            $config.Get('nullKey') | Should -BeNullOrEmpty
        }

        It 'Should overwrite existing value' {
            $config.Set('key', 'value1')
            $config.Set('key', 'value2')
            $config.Get('key') | Should -Be 'value2'
        }

        It 'Should return $null for non-existent key' {
            $config.Get('nonExistentKey') | Should -BeNullOrEmpty
        }
        
        It 'Should be idempotent' {
            $config.Set('idempotentKey', 'value')
            $config.Set('idempotentKey', 'value')
            $config.Get('idempotentKey') | Should -Be 'value'
        }

        It 'Should set multiple values from a dictionary' {
            $config.SetMany(@{
                keyA = 'valueA'
                keyB = 42
            })

            $config.Get('keyA') | Should -Be 'valueA'
            $config.Get('keyB') | Should -Be 42
        }

        It 'Should do nothing when SetMany receives null' {
            $config.SetMany($null)
            [Variables]::KeyValueStore.Count | Should -Be 0
        }

        It 'Should throw when SetMany receives a non-dictionary value' {
            $exceptionType = [System.ArgumentException]
            { $config.SetMany([pscustomobject]@{ key = 'value' }) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should populate IncludeTags from a tagsInclude entry' {
            $config.SetMany(@{ tagsInclude = @('tag1', 'tag2') })
            $config.GetIncludeTags() | Should -Contain 'tag1'
            $config.GetIncludeTags() | Should -Contain 'tag2'
        }

        It 'Should populate ExcludeTags from a tagsExclude entry' {
            $config.SetMany(@{ tagsExclude = @('tag1', 'tag2') })
            $config.GetExcludeTags() | Should -Contain 'tag1'
            $config.GetExcludeTags() | Should -Contain 'tag2'
        }

        It 'Should overwrite previously set IncludeTags on a later SetMany call' {
            $config.SetMany(@{ tagsInclude = @('tag1') })
            $config.SetMany(@{ tagsInclude = @('tag2') })
            $config.GetIncludeTags() | Should -Not -Contain 'tag1'
            $config.GetIncludeTags() | Should -Contain 'tag2'
        }
    }

    Context 'HasKey' {
        It 'Should return true for existing key' {
            $config.Set('existingKey', 'value')
            $config.HasKey('existingKey') | Should -BeTrue
        }

        It 'Should return false for non-existent key' {
            $config.HasKey('nonExistentKey') | Should -BeFalse
        }

        It 'Should return true even if value is $null' {
            $config.Set('nullKey', $null)
            $config.HasKey('nullKey') | Should -BeTrue
        }
    }

    Context 'Unset' {
        It 'Should remove an existing key' {
            $config.Set('key', 'value')
            $config.HasKey('key') | Should -BeTrue
            $config.Unset('key')
            $config.HasKey('key') | Should -BeFalse
        }

        It 'Should not error when unsetting non-existent key' {
            { $config.Unset('nonExistentKey') } | Should -Not -Throw
        }

        It 'Should be idempotent' {
            $config.Set('key', 'value')
            $config.Unset('key')
            { $config.Unset('key') } | Should -Not -Throw
        }
    }
}

Describe 'Key Validation' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        $config = [Variables]::GetInstance()
    }

    Context 'ValidateKey' {
        It 'Should accept valid string keys' {
            { $config.ValidateKey('validKey') } | Should -Not -Throw
        }

        It 'Should throw on null key' {
            $exceptionType = [System.ArgumentNullException]
            { $config.ValidateKey($null) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw on integer key' {
            $exceptionType = [System.ArgumentException]
            { $config.ValidateKey(42) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw on array key' {
            $exceptionType = [System.ArgumentException]
            { $config.ValidateKey(@('a', 'b')) } | Should -Throw -ExceptionType $exceptionType
        }

        It 'Should throw on object key' {
            $exceptionType = [System.ArgumentException]
            { $config.ValidateKey([pscustomobject]@{ Name = 'value' }) } | Should -Throw -ExceptionType $exceptionType
        }
    }

    Context 'Set with Invalid Keys' {
        It 'Should throw when setting with null key' {
            { $config.Set($null, 'value') } | Should -Throw
        }

        It 'Should throw when setting with non-string key' {
            { $config.Set(123, 'value') } | Should -Throw
        }
    }

    Context 'Get with Invalid Keys' {
        It 'Should throw when getting with null key' {
            { $config.Get($null) } | Should -Throw
        }

        It 'Should throw when getting with non-string key' {
            { $config.Get(123) } | Should -Throw
        }
    }

    Context 'HasKey with Invalid Keys' {
        It 'Should throw when checking null key' {
            { $config.HasKey($null) } | Should -Throw
        }

        It 'Should throw when checking non-string key' {
            { $config.HasKey(123) } | Should -Throw
        }
    }

    Context 'Unset with Invalid Keys' {
        It 'Should throw when unsetting null key' {
            { $config.Unset($null) } | Should -Throw
        }

        It 'Should throw when unsetting non-string key' {
            { $config.Unset(123) } | Should -Throw
        }
    }
}

Describe 'Include Tag Operations' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        $config = [Variables]::GetInstance()
    }

    Context 'AddIncludeTag' {
        It 'Should add a tag to include tags' {
            $config.AddIncludeTag('tag1')
            $config.HasIncludeTag('tag1') | Should -BeTrue
        }

        It 'Should add multiple tags' {
            $config.AddIncludeTag('tag1')
            $config.AddIncludeTag('tag2')
            $config.AddIncludeTag('tag3')
            $config.GetIncludeTags() | Should -Contain 'tag1'
            $config.GetIncludeTags() | Should -Contain 'tag2'
            $config.GetIncludeTags() | Should -Contain 'tag3'
        }

        It 'Should not add duplicate tags' {
            $config.AddIncludeTag('tag1')
            $config.AddIncludeTag('tag1')
            @($config.GetIncludeTags()).Count | Should -Be 1
        }
    }

    Context 'RemoveIncludeTag' {
        It 'Should remove an existing include tag' {
            $config.AddIncludeTag('tag1')
            $config.RemoveIncludeTag('tag1')
            $config.HasIncludeTag('tag1') | Should -BeFalse
        }

        It 'Should not error when removing non-existent tag' {
            { $config.RemoveIncludeTag('nonExistentTag') } | Should -Not -Throw
        }
    }

    Context 'HasIncludeTag' {
        It 'Should return true for existing tag' {
            $config.AddIncludeTag('myTag')
            $config.HasIncludeTag('myTag') | Should -BeTrue
        }

        It 'Should return false for non-existent tag' {
            $config.HasIncludeTag('nonExistentTag') | Should -BeFalse
        }
    }

    Context 'GetIncludeTags' {
        It 'Should return empty array when no tags added' {
            $config.GetIncludeTags() | Should -HaveCount 0
        }

        It 'Should return all added tags' {
            $config.AddIncludeTag('tag1')
            $config.AddIncludeTag('tag2')
            $config.AddIncludeTag('tag3')
            $tags = $config.GetIncludeTags()
            $tags | Should -Contain 'tag1'
            $tags | Should -Contain 'tag2'
            $tags | Should -Contain 'tag3'
        }
    }
}

Describe 'Exclude Tag Operations' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        $config = [Variables]::GetInstance()
    }

    Context 'AddExcludeTag' {
        It 'Should add a tag to exclude tags' {
            $config.AddExcludeTag('tag1')
            $config.HasExcludeTag('tag1') | Should -BeTrue
        }

        It 'Should add multiple tags' {
            $config.AddExcludeTag('tag1')
            $config.AddExcludeTag('tag2')
            $config.AddExcludeTag('tag3')
            $config.GetExcludeTags() | Should -Contain 'tag1'
            $config.GetExcludeTags() | Should -Contain 'tag2'
            $config.GetExcludeTags() | Should -Contain 'tag3'
        }

        It 'Should not add duplicate tags' {
            $config.AddExcludeTag('tag1')
            $config.AddExcludeTag('tag1')
            @($config.GetExcludeTags()).Count | Should -Be 1
        }
    }

    Context 'RemoveExcludeTag' {
        It 'Should remove an existing exclude tag' {
            $config.AddExcludeTag('tag1')
            $config.RemoveExcludeTag('tag1')
            $config.HasExcludeTag('tag1') | Should -BeFalse
        }

        It 'Should not error when removing non-existent tag' {
            { $config.RemoveExcludeTag('nonExistentTag') } | Should -Not -Throw
        }
    }

    Context 'HasExcludeTag' {
        It 'Should return true for existing tag' {
            $config.AddExcludeTag('myTag')
            $config.HasExcludeTag('myTag') | Should -BeTrue
        }

        It 'Should return false for non-existent tag' {
            $config.HasExcludeTag('nonExistentTag') | Should -BeFalse
        }
    }

    Context 'GetExcludeTags' {
        It 'Should return empty array when no tags added' {
            $config.GetExcludeTags() | Should -HaveCount 0
        }

        It 'Should return all added tags' {
            $config.AddExcludeTag('tag1')
            $config.AddExcludeTag('tag2')
            $config.AddExcludeTag('tag3')
            $tags = $config.GetExcludeTags()
            $tags | Should -Contain 'tag1'
            $tags | Should -Contain 'tag2'
            $tags | Should -Contain 'tag3'
        }
    }
}

Describe 'Tag Isolation' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
        $config = [Variables]::GetInstance()
    }

    Context 'Include and Exclude Tags Independence' {
        It 'Should keep include and exclude tags separate' {
            $config.AddIncludeTag('tag1')
            $config.AddExcludeTag('tag2')
            $config.HasIncludeTag('tag1') | Should -BeTrue
            $config.HasIncludeTag('tag2') | Should -BeFalse
            $config.HasExcludeTag('tag1') | Should -BeFalse
            $config.HasExcludeTag('tag2') | Should -BeTrue
        }

        It 'Should allow same tag in both include and exclude' {
            $config.AddIncludeTag('sharedTag')
            $config.AddExcludeTag('sharedTag')
            $config.HasIncludeTag('sharedTag') | Should -BeTrue
            $config.HasExcludeTag('sharedTag') | Should -BeTrue
        }

        It 'Should not affect exclude tags when modifying include tags' {
            $config.AddExcludeTag('sharedTag')
            $config.AddIncludeTag('sharedTag')
            $config.RemoveIncludeTag('sharedTag')
            $config.HasExcludeTag('sharedTag') | Should -BeTrue
        }
    }
}

Describe 'Variables State Persistence' {
    BeforeEach {
        # Reset the singleton instance before each test
        [Variables]::Instance = $null
        [Variables]::KeyValueStore = $null
        [Variables]::IncludeTags = $null
        [Variables]::ExcludeTags = $null
    }

    Context 'State Across Multiple Operations' {
        It 'Should maintain state across multiple Set/Get operations' {
            $config = [Variables]::GetInstance()
            $config.Set('key1', 'value1')
            $config.Set('key2', 42)
            $config.AddIncludeTag('tag1')
            
            $config.Get('key1') | Should -Be 'value1'
            $config.Get('key2') | Should -Be 42
            $config.HasIncludeTag('tag1') | Should -BeTrue
        }

        It 'Should persist state across GetInstance calls' {
            $config1 = [Variables]::GetInstance()
            $config1.Set('persistKey', 'persistValue')
            $config1.AddIncludeTag('persistTag')
            
            $config2 = [Variables]::GetInstance()
            $config2.Get('persistKey') | Should -Be 'persistValue'
            $config2.HasIncludeTag('persistTag') | Should -BeTrue
        }
    }
}

