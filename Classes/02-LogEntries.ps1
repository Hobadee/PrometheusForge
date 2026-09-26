class LogEntries : System.Collections.IEnumerable {
    <#
    .SYNOPSIS
    Represents an ordered set of log entries that can be searched and filtered.

    .DESCRIPTION
    LogEntries stores and enumerates [LogEntry] objects.  Every filter or search method returns a
    new LogEntries containing only the matching entries, so calls can be chained:

        [Log]::GetEntries().WhereLevelAtLeast([LogLevel]::Warning).Search('timeout')

    .NOTES
    This class has no singleton behavior and does no output.  The shared, run-scoped set lives in [Log].
    Filtered sets are snapshots; entries added to the original afterwards do not appear in them.
    The [LogEntry] objects themselves are shared between a set and the sets derived from it.
    #>

    hidden [System.Collections.Generic.List[LogEntry]] $Entries = [System.Collections.Generic.List[LogEntry]]::new()

    hidden [int] $currentIndex = 0


    LogEntries() {
    }


    LogEntries([System.Collections.Generic.IEnumerable[LogEntry]] $entries) {
        if ($null -ne $entries) {
            $this.Entries.AddRange($entries)
        }
    }

    
    [void] Add([LogEntry] $entry) {
        if ($null -eq $entry) {
            throw [System.ArgumentNullException]::new('entry', 'Entry cannot be null')
        }

        $this.Entries.Add($entry)
    }


    [LogEntries] Snapshot() {
        <#
        .SYNOPSIS
        Creates a snapshot of the current set of log entries.

        .DESCRIPTION
        The Snapshot method returns a new LogEntries object containing the same entries as the current set.
        Changes to the original set after calling Snapshot do not affect the snapshot.
        #>
        return [LogEntries]::new($this.Entries)
    }


    <#############################
    # IEnumerable implementation #
    #############################>

    [System.Collections.IEnumerator] GetEnumerator() {
        return $this.Entries.GetEnumerator()
    }


    [void] SetCurrentIndex([int] $index) {
        if ($index -lt 0 -or $index -ge $this.Entries.Count) {
            throw [System.ArgumentOutOfRangeException]::new("index", "Index must be between 0 and $($this.Entries.Count - 1)")
        }
        $this.currentIndex = $index
    }

    
    [LogEntry] GetCurrentItem() {
        if ($this.Entries.Count -eq 0) {
            throw [System.InvalidOperationException]::new("No items are available")
        }

        return $this.Entries[$this.currentIndex]
    }


    [int] Count() {
        return $this.Entries.Count
    }

    <##########################
    # Filtering and Searching #
    ###########################>
    # Each method returns a new LogEntries; the set it is called on is never modified.

    # Entries at exactly the given level.
    [LogEntries] WhereLevel([LogLevel] $level) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetLevel() -eq $level) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries at the given level or more severe (lower numeric value, e.g. Warning includes Error).
    [LogEntries] WhereLevelAtLeast([LogLevel] $level) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ([int] $entry.GetLevel() -le [int] $level) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries whose source equals the given source, ignoring case.
    [LogEntries] WhereSource([string] $source) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ([string]::Equals($entry.GetSource(), $source, [System.StringComparison]::OrdinalIgnoreCase)) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries logged at or after the given time.
    [LogEntries] Since([datetime] $timestamp) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetTimestamp() -ge $timestamp) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries logged at or before the given time.
    [LogEntries] Until([datetime] $timestamp) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetTimestamp() -le $timestamp) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # The entry with exactly the given sequence number (a set holds at most one unless it mixes runs).
    [LogEntries] WhereSequence([long] $sequence) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetSequence() -eq $sequence) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries whose sequence number is at or after the given one.
    [LogEntries] SinceSequence([long] $sequence) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetSequence() -ge $sequence) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries whose sequence number is at or before the given one.
    [LogEntries] UntilSequence([long] $sequence) {
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry.GetSequence() -le $sequence) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries whose message matches the given regular expression, ignoring case
    # (use an inline (?-i) option in the pattern for a case-sensitive match).
    # An invalid pattern throws an ArgumentException.
    [LogEntries] Search([string] $text) {
        if ([string]::IsNullOrEmpty($text)) {
            throw [System.ArgumentNullException]::new('text', 'Search pattern cannot be null or empty')
        }

        $regex = [regex]::new($text, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($regex.IsMatch($entry.GetMessage())) {
                $found.Add($entry)
            }
        }
        return $found
    }


    # Entries for which the predicate returns true.  The entry is available as $_.
    [LogEntries] Filter([scriptblock] $predicate) {
        <#
        .SYNOPSIS
        Filters the log entries based on a predicate script block.
        
        .PARAMETER predicate
        The script block that determines whether a log entry should be included.
        The log entry is available as $_.

        .EXAMPLE
        $filtered = $logEntries.Filter({ $_.GetLevel() -eq 'Error' })
        This example filters the log entries to include only those with the level 'Error'.

        .EXAMPLE
        $filtered = $logEntries.Filter({ $_.GetMessage().Length -gt 20 })
        This example filters the log entries to include only those with a message length greater than 20.
        #>
        if ($null -eq $predicate) {
            throw [System.ArgumentNullException]::new('predicate', 'Predicate cannot be null')
        }

        $found = [LogEntries]::new()
        foreach ($entry in $this.Entries) {
            if ($entry | Where-Object -FilterScript $predicate) {
                $found.Add($entry)
            }
        }

        return $found
    }


}
