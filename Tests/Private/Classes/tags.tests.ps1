Using Module "../../../build/PrometheusForge/PrometheusForge.psd1"

Describe 'tags' {
    BeforeEach {
        $script:tags = [tags]::new()
    }

    Context 'Construction' {
        It 'starts empty' {
            $script:tags.Count() | Should -Be 0
            @($script:tags.GetTags()).Count | Should -Be 0
        }
    }

    Context 'AddTag' {
        It 'adds a tag' {
            $script:tags.AddTag('alpha') | Out-Null

            $script:tags.HasTag('alpha') | Should -BeTrue
            $script:tags.Count() | Should -Be 1
        }

        It 'ignores duplicate tags' {
            $script:tags.AddTag('alpha') | Out-Null
            $script:tags.AddTag('alpha') | Out-Null

            $script:tags.Count() | Should -Be 1
        }

        It 'returns the same instance to allow chaining' {
            $result = $script:tags.AddTag('alpha')

            [object]::ReferenceEquals($result, $script:tags) | Should -BeTrue
            $script:tags.AddTag('a').AddTag('b').Count() | Should -Be 3
        }
    }

    Context 'AddTags' {
        It 'adds every tag in the list, skipping duplicates' {
            $script:tags.AddTag('alpha') | Out-Null

            $script:tags.AddTags(@('alpha', 'beta', 'gamma')) | Out-Null

            $script:tags.GetTags() | Should -Be @('alpha', 'beta', 'gamma')
        }

        It 'returns the same instance to allow chaining' {
            $result = $script:tags.AddTags(@('a', 'b'))

            [object]::ReferenceEquals($result, $script:tags) | Should -BeTrue
        }
    }

    Context 'RemoveTag' {
        It 'removes an existing tag' {
            $script:tags.AddTags(@('alpha', 'beta')) | Out-Null

            $script:tags.RemoveTag('alpha') | Out-Null

            $script:tags.HasTag('alpha') | Should -BeFalse
            $script:tags.HasTag('beta') | Should -BeTrue
        }

        It 'completes silently when the tag does not exist' {
            { $script:tags.RemoveTag('missing') } | Should -Not -Throw
        }

        It 'returns the same instance to allow chaining' {
            $result = $script:tags.RemoveTag('missing')

            [object]::ReferenceEquals($result, $script:tags) | Should -BeTrue
        }
    }

    Context 'HasTag / HasTags' {
        BeforeEach {
            $script:tags.AddTags(@('alpha', 'beta')) | Out-Null
        }

        It 'reports whether a single tag exists' {
            $script:tags.HasTag('alpha') | Should -BeTrue
            $script:tags.HasTag('gamma') | Should -BeFalse
        }

        It 'reports true when any of the given tags exist' {
            $script:tags.HasTags(@('gamma', 'beta')) | Should -BeTrue
        }

        It 'reports false when none of the given tags exist' {
            $script:tags.HasTags(@('gamma', 'delta')) | Should -BeFalse
        }

        It 'reports false for an empty list of tags' {
            $script:tags.HasTags(@()) | Should -BeFalse
        }
    }

    Context 'GetTags' {
        It 'returns a copy that does not affect the collection' {
            $script:tags.AddTag('alpha') | Out-Null

            $copy = $script:tags.GetTags()
            $copy[0] = 'changed'

            $script:tags.HasTag('alpha') | Should -BeTrue
            $script:tags.HasTag('changed') | Should -BeFalse
        }
    }

    Context 'Clear' {
        It 'removes every tag' {
            $script:tags.AddTags(@('alpha', 'beta')) | Out-Null

            $script:tags.Clear() | Out-Null

            $script:tags.Count() | Should -Be 0
            $script:tags.HasTag('alpha') | Should -BeFalse
        }

        It 'returns the same instance to allow chaining' {
            $result = $script:tags.Clear()

            [object]::ReferenceEquals($result, $script:tags) | Should -BeTrue
        }
    }
}
