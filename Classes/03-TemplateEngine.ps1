class TemplateEngine {
    <#
    .SYNOPSIS
    Expands lightweight template tokens from Variables values.

    .DESCRIPTION
    TemplateEngine provides static helpers for MVP variable templating in workflow step parameters.
    Supported token syntax is `{{ variableName }}` and nested paths like `{{ a.b.c }}`.

    Resolution behavior:
    - Root values are retrieved from the Variables singleton key/value store.
    - Nested segments are resolved across hashtables/dictionaries and object properties.
    - Unresolved or null values resolve to an empty string when rendering templates.

    MVP scope intentionally keeps expansion constrained:
    - Expand top-level string fields only when processing parameter objects.
    - Do not recursively expand nested objects/arrays.

    .NOTES
    This class is intentionally static-only and has no instance state.
    #>

    static [string] ExpandString([string]$template, [Variables]$configuration) {
        <#
        .SYNOPSIS
        Expands template tokens within a single string.

        .DESCRIPTION
        Replaces all template tokens matching `{{ token }}` in the provided string.
        Tokens support alphanumeric/underscore root names and optional dot-path traversal.
        Unresolved tokens produce empty-string replacements.

        .PARAMETER template
        The input string that may contain zero or more template tokens.

        .PARAMETER configuration
        The Variables instance used as the variable source.

        .OUTPUTS
        [string] The rendered string after token substitution.

        .EXAMPLE
        $config.Set('userName', 'Ada')
        [TemplateEngine]::ExpandString('Hello {{ userName }}', $config)
        # Returns: 'Hello Ada'
        #>
        if ([string]::IsNullOrEmpty($template)) {
            return ""
        }

        $pattern = '\{\{\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*\}\}'

        return [regex]::Replace(
            $template,
            $pattern,
            {
                param($match)

                $resolvedValue = [TemplateEngine]::ResolvePath($match.Groups[1].Value, $configuration)
                if ($null -eq $resolvedValue) {
                    return ""
                }

                return [string]$resolvedValue
            }
        )
    }

    static [object] ExpandTopLevelValues([object]$inputObject, [Variables]$configuration) {
        <#
        .SYNOPSIS
        Expands templated top-level string values in an object.

        .DESCRIPTION
        Applies ExpandString to top-level string members only.
        Supported input shapes:
        - IDictionary/hashtable: each top-level value
            - IList/arrays: each top-level element, with contained maps/objects expanded in place
        - PSCustomObject: each top-level property value
        - string: treated as a direct ExpandString call

        Non-string values are preserved without modification.
        Nested objects/arrays are intentionally not traversed in this MVP.

        .PARAMETER inputObject
        The object whose top-level values may contain template tokens.

        .PARAMETER configuration
        The Variables instance used as the variable source.

        .OUTPUTS
        [object] The same logical input shape with top-level string values expanded.

        .EXAMPLE
        $params = @{ message = 'User={{userName}}'; retries = 3 }
        [TemplateEngine]::ExpandTopLevelValues($params, $config)
        # Expands message but leaves retries unchanged.
        #>
        if ($null -eq $inputObject) {
            return $null
        }

        if ($inputObject -is [System.Collections.IDictionary]) {
            foreach ($key in @($inputObject.Keys)) {
                if ($inputObject[$key] -is [string]) {
                    $inputObject[$key] = [TemplateEngine]::ExpandString($inputObject[$key], $configuration)
                }
            }

            return $inputObject
        }

        if ($inputObject -is [System.Collections.IList]) {
            for ($index = 0; $index -lt $inputObject.Count; $index++) {
                $inputObject[$index] = [TemplateEngine]::ExpandTopLevelValues($inputObject[$index], $configuration)
            }

            return $inputObject
        }

        if ($inputObject -is [pscustomobject]) {
            foreach ($property in $inputObject.PSObject.Properties) {
                if ($property.Value -is [string]) {
                    $property.Value = [TemplateEngine]::ExpandString($property.Value, $configuration)
                }
            }

            return $inputObject
        }

        if ($inputObject -is [string]) {
            return [TemplateEngine]::ExpandString($inputObject, $configuration)
        }

        return $inputObject
    }

    static [object] ResolvePath([string]$path, [Variables]$configuration) {
        <#
        .SYNOPSIS
        Resolves a template variable path to a value.

        .DESCRIPTION
        Resolves a dot-delimited variable path such as `pin.object.generatedPassword`.
        The first segment is looked up in Variables, and remaining segments are
        traversed through dictionaries/hashtables or object properties.

        Returns $null when any segment is unresolved or when inputs are invalid.

        .PARAMETER path
        The variable path to resolve.

        .PARAMETER configuration
        The Variables instance used as the root lookup source.

        .OUTPUTS
        [object] The resolved value, or $null when not found.

        .EXAMPLE
        [TemplateEngine]::ResolvePath('pin.object.generatedPassword', $config)
        # Returns nested value when present; otherwise $null.
        #>
        if ([string]::IsNullOrEmpty($path)) {
            return $null
        }

        if ($null -eq $configuration) {
            return $null
        }

        $pathSegments = $path -split '\.'
        if ($pathSegments.Count -eq 0) {
            return $null
        }

        $rootKey = $pathSegments[0]
        if (-not $configuration.HasKey($rootKey)) {
            return $null
        }

        $currentValue = $configuration.Get($rootKey)

        if ($pathSegments.Count -eq 1) {
            return $currentValue
        }

        foreach ($segment in $pathSegments[1..($pathSegments.Count - 1)]) {
            if ($null -eq $currentValue) {
                return $null
            }

            if ($currentValue -is [System.Collections.IDictionary]) {
                if (-not $currentValue.Contains($segment)) {
                    return $null
                }

                $currentValue = $currentValue[$segment]
                continue
            }

            $property = $currentValue.PSObject.Properties[$segment]
            if ($null -eq $property) {
                return $null
            }

            $currentValue = $property.Value
        }

        return $currentValue
    }
}

