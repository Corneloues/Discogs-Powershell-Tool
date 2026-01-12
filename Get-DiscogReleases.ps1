<#
.SYNOPSIS
    Extract release information from Discogs API to CSV file.

.DESCRIPTION
    This script retrieves release data from the Discogs API for a specific label.
    It requires environment variables to be set for authentication and configuration.

.ENVIRONMENT VARIABLES
    DISCOGS_TOKEN - Discogs API authentication token (required)
    BASE_URL      - Discogs API base URL (required)
    USER_AGENT    - User agent string for API requests (required)
    LABEL_ID      - Discogs label ID to query (required)
    WHERE_MATCH   - Regex pattern to match titles (required)
    FILE_NAME     - Output CSV filename without extension (required)
    WHERE_TYPE    - Not used (kept for backward compatibility)
    WHERE_ROLE    - Not used (kept for backward compatibility)
    ENABLE_DIAGNOSTICS - Enable diagnostic output (optional, defaults to false)

.NOTES
    This script is designed to run in GitHub Actions with secrets and variables.
    Note: The /labels/{id}/releases endpoint returns individual releases, not masters.
    The 'type' and 'role' fields don't exist in this API response.
#>

# Read configuration from environment variables (passed from GitHub Actions)
$DiscogsToken = $env:DISCOGS_TOKEN
$BaseUrl      = $env:BASE_URL
$UserAgent    = $env:USER_AGENT
$labelIdStr   = $env:LABEL_ID
# Note: WHERE_TYPE and WHERE_ROLE are not used because the /labels/{id}/releases 
# endpoint doesn't return these fields. Filtering is done by title pattern only.
$whereType    = $env:WHERE_TYPE    # Not used - kept for backward compatibility
$whereRole    = $env:WHERE_ROLE    # Not used - kept for backward compatibility
$whereMatch   = $env:WHERE_MATCH
$fileName     = $env:FILE_NAME
$script:enableDiagnostics = $env:ENABLE_DIAGNOSTICS -eq 'true'

# Validate required environment variables
if (-not $DiscogsToken) { throw "DISCOGS_TOKEN environment variable is required" }
if (-not $BaseUrl) { throw "BASE_URL environment variable is required" }
if (-not $UserAgent) { throw "USER_AGENT environment variable is required" }
if (-not $labelIdStr) { throw "LABEL_ID environment variable is required" }
if (-not $whereMatch) { throw "WHERE_MATCH environment variable is required" }
if (-not $fileName) { throw "FILE_NAME environment variable is required" }

# Set error action preference to stop on errors
$ErrorActionPreference = "Stop"

# Parse and validate label ID
try {
    $labelId = [int]$labelIdStr
} catch {
    throw "LABEL_ID must be a valid integer"
}

# Configure headers for Discogs API requests
$Headers = @{
    "User-Agent"    = $UserAgent
    "Authorization" = "Discogs token=$DiscogsToken"
}

# ============================================================================
# STARTUP LOGGING
# ============================================================================
Write-Host "=== Discogs Release Extraction Started ===" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl"
Write-Host "Label ID: $labelId"
Write-Host "Filter - Match: $whereMatch"
Write-Host "Output File: $fileName.csv"

# Sanitize token for logging (only show first/last 4 chars)
$tokenDisplay = if ($DiscogsToken.Length -gt 8) {
    "$($DiscogsToken.Substring(0,4))...$($DiscogsToken.Substring($DiscogsToken.Length-4))"
} else {
    "****"
}
Write-Host "Token: $tokenDisplay"
Write-Host "Diagnostics: $script:enableDiagnostics"
Write-Host ""

# Import helper functions
. "$PSScriptRoot/DiscogsHelpers.ps1"

# ============================================================================
# MAIN PROGRAM - Process Discogs Label Releases
# ============================================================================

# Step 1: Retrieve all releases from the specified label
$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

# Diagnostic output (if enabled)
if ($script:enableDiagnostics) {
    Write-Host ""
    Write-Host "================================================"
    Write-Host "DIAGNOSTIC MODE ENABLED"
    Write-Host "================================================"
    
    # Show unique Type values
    Write-Host ""
    Write-Host "Unique 'type' values found in releases:"
    $allReleases | Group-Object -Property type | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Count) releases"
    }
    
    # Show unique Role values
    Write-Host ""
    Write-Host "Unique 'role' values found in releases:"
    $allReleases | Group-Object -Property role | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Count) releases"
    }
    
    # Show sample titles (first 20)
    Write-Host ""
    Write-Host "Sample of release titles (first 20):"
    $allReleases | Select-Object -First 20 | ForEach-Object {
        Write-Host "  - ""$($_.title)"" (Type: $($_.type), Role: $($_.role))"
    }
    
    # Show releases that match Type and Role but not the title pattern
    Write-Host ""
    Write-Host "Releases matching Type=$whereType and Role=$whereRole (but may not match title pattern):"
#     $typeRoleMatches = $allReleases | Where-Object {
# #        $_.type -eq $whereType -and $_.role -eq $whereRole
#         $_.type -match $whereType -or $_.role -match $whereRole
#     }
    $typeRoleMatches = $allReleases
    
    Write-Host "  Found $($typeRoleMatches.Count) releases matching Type and Role"
    if ($typeRoleMatches.Count -gt 0) {
        Write-Host "  Sample titles:"
        $typeRoleMatches | Select-Object -First 10 | ForEach-Object {
            Write-Host "    - ""$($_.title)"""
        }
    }
    
    # Test the regex pattern against sample titles
    Write-Host ""
    Write-Host "Testing regex pattern: '$whereMatch'"
    Write-Host "Sample matches:"
    $regexMatches = $allReleases | Where-Object { $_.title -match $whereMatch } | Select-Object -First 10
    if ($regexMatches.Count -gt 0) {
        $regexMatches | ForEach-Object {
            Write-Host "  ✓ ""$($_.title)"" (Type: $($_.type), Role: $($_.role))"
        }
    } else {
        Write-Host "  ⚠ No titles match the regex pattern"
    }
    
    # Show raw API response structure
    Write-Host ""
    Write-Host "================================================"
    Write-Host "RAW API RESPONSE INSPECTION"
    Write-Host "================================================"
    Write-Host ""
    
    # Show the first release object as JSON
    if ($allReleases.Count -gt 0) {
        Write-Host "First release object (raw JSON):"
        $firstRelease = $allReleases | Select-Object -First 1
        Write-Host ($firstRelease | ConvertTo-Json -Depth 3)
        Write-Host ""
        
        # Show all available property names
        Write-Host "Available properties on release objects:"
        $firstRelease.PSObject.Properties | ForEach-Object {
            Write-Host "  - $($_.Name) (Type: $($_.TypeNameOfValue)) = $($_.Value)"
        }
        Write-Host ""
        
        # Show a few more sample releases with all properties
        Write-Host "Sample of first 3 releases with all properties:"
        $allReleases | Select-Object -First 3 | ForEach-Object {
            Write-Host "  Release:"
            $_.PSObject.Properties | ForEach-Object {
                Write-Host "    $($_.Name): $($_.Value)"
            }
            Write-Host ""
        }
    } else {
        Write-Host "  No releases available to inspect!"
    }
    
    Write-Host "================================================"
    Write-Host ""
}

# Log results of Step 1
Write-Host "✓ Fetched $($allReleases.Count) total releases from label $labelId" -ForegroundColor Green
if ($allReleases.Count -eq 0) {
    Write-Host "WARNING: No releases returned from API!" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Filter releases based on title pattern and sort by issue number
# Note: The /labels/{id}/releases endpoint returns individual releases, not masters.
# The 'type' and 'role' fields don't exist in this API response, so we filter by title only.
$numberedReleases = $allReleases |
    Where-Object {
        $_.title -match $whereMatch
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# Log results of Step 2
Write-Host "✓ Filtered to $($numberedReleases.Count) releases matching criteria" -ForegroundColor Green
if ($numberedReleases.Count -eq 0) {
    Write-Host "WARNING: No releases matched the filter criteria (Match=$whereMatch)" -ForegroundColor Yellow
} else {
    Write-Host "First few titles matched:"
    $numberedReleases | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.title)" -ForegroundColor Gray
    }
}
Write-Host ""

# Step 3: Process each release to extract track information
# Each release is fetched directly from /releases/{id} - no masters/versions needed.
$rows = @()

foreach ($release in $numberedReleases) {
    # Extract issue number from title (e.g., "Now That's What I Call Music 50" → 50)
    $issueNumber = [int]([regex]::Match($release.title, '\d+').Value)
    
    Write-Host "Processing: $($release.title) (Issue #$issueNumber)..." -ForegroundColor Cyan

    try {
        # Fetch the release directly (no masters/versions needed)
        $releaseUrl = "$BaseUrl/releases/$($release.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get
        
        $year = $releaseData.year
        
        # Extract format information
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }
        
        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions
        
        Write-Host "  Format: $formatName-$versionLabel, Year: $year, Tracks: $($releaseData.tracklist.Count)" -ForegroundColor Gray
        
        # Process each track in the release
        foreach ($t in $releaseData.tracklist) {
            if (-not $t.title) { continue }  # Skip tracks without titles
            
            # Parse track position (e.g., "A1" or "1-05")
            $parsed = Parse-DiscAndTrack -Position $t.position
            $disc = $parsed.Disc
            $track = $parsed.TrackNumber
            
            # Extract artist name
            $artistName = $null
            if ($t.artists -and $t.artists.Count -gt 0) {
                $artistName = ($t.artists | Select-Object -First 1).name
            }
            
            # Add track data to output collection
            $rows += [pscustomobject]@{
                Issue            = $issueNumber
                Year             = $year
                Format           = $formatName
                Version          = $versionLabel
                Disc             = $disc
                TrackNumber      = $track
                Title            = $t.title
                Artist           = $artistName
                DiscogsReleaseID = $releaseData.id
            }
        }
        
        # Add rate limiting delay
        Start-Sleep -Milliseconds 1000
        
    } catch {
        Write-Host "  ⚠ ERROR fetching release $($release.id): $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "  HTTP Status: $statusCode" -ForegroundColor Red
            
            if ($statusCode -eq 429) {
                Write-Host "  Rate limit hit - waiting 60s..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
            }
        }
        continue
    }
}

# Log results after processing all releases
Write-Host ""
Write-Host "✓ Collected $($rows.Count) total tracks from all releases" -ForegroundColor Green
if ($rows.Count -eq 0) {
    Write-Host "WARNING: No tracks were collected! CSV will be empty." -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Export all collected track data to CSV file
# Sorted by: Issue → Format → Version → Disc → Track Number
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

# Log completion
Write-Host "✓ Successfully exported $($rows.Count) tracks to $fileName.csv" -ForegroundColor Green
Write-Host "=== Extraction Complete ===" -ForegroundColor Cyan

