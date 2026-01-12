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
    WHERE_MATCH   - Regex pattern to match release titles (required)
    FILE_NAME     - Output CSV filename without extension (required)
    ENABLE_DIAGNOSTICS - Enable diagnostic output (optional, defaults to false)
    
    NOTE: WHERE_TYPE and WHERE_ROLE are not used because the /labels/{id}/releases 
          endpoint does not return these fields. Filtering is done by title pattern only.

.NOTES
    This script is designed to run in GitHub Actions with secrets and variables.
#>

# Read configuration from environment variables (passed from GitHub Actions)
$DiscogsToken = $env:DISCOGS_TOKEN
$BaseUrl      = $env:BASE_URL
$UserAgent    = $env:USER_AGENT
$labelIdStr   = $env:LABEL_ID
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
Write-Host "Filter - Title Match Pattern: $whereMatch"
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
    
    # Show releases that match the title pattern
    Write-Host ""
    Write-Host "Releases matching title pattern '$whereMatch' (type/role filters not available in this API endpoint):"
#     $typeRoleMatches = $allReleases | Where-Object {
# #        $_.type -eq $whereType -and $_.role -eq $whereRole
#         $_.type -match $whereType -or $_.role -match $whereRole
#     }
    $typeRoleMatches = $allReleases
    
    Write-Host "  Found $($typeRoleMatches.Count) total releases"
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

# Step 2: Filter releases based on title pattern only and sort by number
# The /labels/{id}/releases endpoint does not return 'type' or 'role' fields,
# so we can only filter by title pattern
$filteredReleases = $allReleases |
    Where-Object {
        $_.title -match $whereMatch
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# Log results of Step 2
Write-Host "✓ Filtered to $($filteredReleases.Count) releases matching title pattern" -ForegroundColor Green
if ($filteredReleases.Count -eq 0) {
    Write-Host "WARNING: No releases matched the title pattern: $whereMatch" -ForegroundColor Yellow
} else {
    Write-Host "  Matched releases:" -ForegroundColor Cyan
    $filteredReleases | Select-Object -First 10 | ForEach-Object {
        Write-Host "    - $($_.title) (ID: $($_.id))" -ForegroundColor Cyan
    }
}
Write-Host ""

# Step 3: Process each release directly to extract track information
$rows = @()

foreach ($release in $filteredReleases) {
    # Extract issue number from title (e.g., "Now 50" → 50)
    $issueNumber = if ($release.title -match '\d+') { 
        [int]([regex]::Match($release.title, '\d+').Value) 
    } else { 
        0 
    }
    
    Write-Host "Processing: $($release.title) (Issue #$issueNumber, ID: $($release.id))..." -ForegroundColor Cyan
    
    try {
        # Fetch full release details to get tracklist
        $releaseUrl  = "$BaseUrl/releases/$($release.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get
        
        Write-Host "  Year: $($releaseData.year), Format: $($releaseData.formats[0].name)" -ForegroundColor Gray
        Write-Host "  Tracks: $($releaseData.tracklist.Count)" -ForegroundColor Gray
        
        $year = $releaseData.year
        
        # Extract format information
        $formatName = if ($releaseData.formats -and $releaseData.formats.Count -gt 0) {
            $releaseData.formats[0].name
        } else {
            "Unknown"
        }
        
        # Get version label (keep existing logic)
        $formatDescs = if ($releaseData.formats -and $releaseData.formats[0].descriptions) {
            $releaseData.formats[0].descriptions
        } else {
            @()
        }
        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $formatDescs
        
        # Process each track in the tracklist
        foreach ($track in $releaseData.tracklist) {
            if ($track.type_ -eq "track") {
                $parsed = Parse-DiscAndTrack -Position $track.position
                
                $trackArtist = if ($track.artists -and $track.artists.Count -gt 0) {
                    $track.artists[0].name
                } else {
                    "Various"
                }
                
                $rows += [PSCustomObject]@{
                    Issue            = $issueNumber
                    Year             = $year
                    Format           = $formatName
                    Version          = $versionLabel
                    Disc             = $parsed.Disc
                    TrackNumber      = $parsed.TrackNumber
                    Title            = $track.title
                    Artist           = $trackArtist
                    DiscogsReleaseID = $release.id
                }
            }
        }
        
        # Rate limiting
        Start-Sleep -Milliseconds 1000
        
    } catch {
        Write-Host "  ⚠ ERROR fetching release $($release.id): $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        }
        continue
    }
}

# Log results after processing all releases
Write-Host ""
Write-Host "✓ Collected $($rows.Count) total tracks from $($filteredReleases.Count) releases" -ForegroundColor Green

if ($rows.Count -eq 0) {
    Write-Host "WARNING: No tracks were collected! CSV will be empty." -ForegroundColor Yellow
    Write-Host "  - Releases fetched: $($allReleases.Count)" -ForegroundColor Yellow
    Write-Host "  - Releases matching filter: $($filteredReleases.Count)" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Export all collected track data to CSV file
# Sorted by: Issue → Format → Version → Disc → Track Number
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

# Log completion
Write-Host "✓ Successfully exported $($rows.Count) tracks to $fileName.csv" -ForegroundColor Green
Write-Host "=== Extraction Complete ===" -ForegroundColor Cyan

