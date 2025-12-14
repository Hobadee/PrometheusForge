<#
.SYNOPSIS
DependencyResolver: normalize dependencies and topologically sort tasks. Detect cycles and throw informative error.
#>
function New-DependencyGraph {
    param([object[]] $Tasks)
    # Build adjacency list and in-degree counts
    $nodes = @{}
    foreach ($t in $Tasks) { $nodes[$t.Id] = @{ Task = $t; Out = New-Object System.Collections.Generic.List[string]; In = New-Object System.Collections.Generic.List[string] } }

    # Expand explicit dependencies declared on tasks (Dependency.Id) and tag-based
    foreach ($t in $Tasks) {
        if ($null -eq $t.Dependencies) { continue }
        foreach ($d in $t.Dependencies) {
            $candidates = $d.ResolveCandidates($Tasks)
            foreach ($c in $candidates) {
                # add edge c -> t (c must precede t)
                $nodes[$c.Id].Out.Add($t.Id) | Out-Null
                $nodes[$t.Id].In.Add($c.Id) | Out-Null
            }
        }
        # After ordering: tasks in After should be treated likewise
        if ($t.After) {
            foreach ($afterId in $t.After) {
                if ($nodes.ContainsKey($afterId)) {
                    $nodes[$afterId].Out.Add($t.Id) | Out-Null
                    $nodes[$t.Id].In.Add($afterId) | Out-Null
                }
            }
        }
    }
    return $nodes
}

function Resolve-DependencyOrder {
    param([object[]] $Tasks)
    $nodes = New-DependencyGraph -Tasks $Tasks

    # Kahn's algorithm
    $L = @()
    $S = New-Object System.Collections.Generic.List[string]

    foreach ($k in $nodes.Keys) { if (($nodes[$k].In).Count -eq 0) { $S.Add($k) } }

    while ($S.Count -gt 0) {
        # deterministic: sort S and pick first
        $S.Sort()
        $n = $S[0]
        $S.RemoveAt(0)
        $L += $nodes[$n].Task

        foreach ($m in $nodes[$n].Out) {
            $nodes[$m].In.Remove($n)
            if (($nodes[$m].In).Count -eq 0) { $S.Add($m) }
        }
    }

    # If graph has edges, there was a cycle
    $remaining = $nodes.Keys | Where-Object { ($nodes[$_].In).Count -gt 0 }
    if ($remaining.Count -gt 0) {
        $cycle = $remaining -join ', '
        throw "Dependency cycle detected involving tasks: $cycle"
    }

    return $L
}
