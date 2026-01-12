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
    WHERE_TYPE    - Filter type for releases (e.g., "master") (required)
    WHERE_ROLE    - Filter role for releases (e.g., "Main") (required)
    WHERE_MATCH   - Regex pattern to match titles (required)
    FILE_NAME     - Output CSV filename without extension (required)
    ENABLE_DIAGNOSTICS - Enable diagnostic output (optional, defaults to false)

.NOTES
    This script is designed to run in GitHub Actions with secrets and variables.
#>

# Read configuration from environment variables (passed from GitHub Actions)
$DiscogsToken = $env:DISCOGS_TOKEN
$BaseUrl      = $env:BASE_URL
$UserAgent    = $env:USER_AGENT
$labelIdStr   = $env:LABEL_ID
$whereType    = $env:WHERE_TYPE
$whereRole    = $env:WHERE_ROLE
$whereMatch   = $env:WHERE_MATCH
$fileName     = $env:FILE_NAME
$script:enableDiagnostics = $env:ENABLE_DIAGNOSTICS -eq 'true'

# Validate required environment variables
if (-not $DiscogsToken) { throw "DISCOGS_TOKEN environment variable is required" }
if (-not $BaseUrl) { throw "BASE_URL environment variable is required" }
if (-not $UserAgent) { throw "USER_AGENT environment variable is required" }
if (-not $labelIdStr) { throw "LABEL_ID environment variable is required" }
if (-not $whereType) { throw "WHERE_TYPE environment variable is required" }
if (-not $whereRole) { throw "WHERE_ROLE environment variable is required" }
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
Write-Host "Filter - Type: $whereType, Role: $whereRole, Match: $whereMatch"
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
    $typeRoleMatches = $allReleases | Where-Object {
#        $_.type -eq $whereType -and $_.role -eq $whereRole
        $_.type -match $whereType -and $_.role -match $whereRole
    }
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

# Step 2: Filter releases based on configured criteria and sort by number
# Only processes releases that match:
# - Type (e.g., "master" releases)
# - Role (e.g., "Main" releases)  
# - Title pattern (e.g., "Now That's What I Call Music\s*\d+")
$numberedMasters = $allReleases |
    Where-Object {
        $_.type -eq $whereType -and
        $_.role -eq $whereRole -and
        $_.title -match $whereMatch
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# Log results of Step 2
Write-Host "✓ Filtered to $($numberedMasters.Count) releases matching criteria" -ForegroundColor Green
if ($numberedMasters.Count -eq 0) {
    Write-Host "WARNING: No releases matched the filter criteria (Type=$whereType, Role=$whereRole, Match=$whereMatch)" -ForegroundColor Yellow
} else {
    Write-Host "First few titles matched:"
    $numberedMasters | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.title)" -ForegroundColor Gray
    }
}
Write-Host ""

# Step 3: Process each master release to extract track information
# For each master: fetch all versions, then all tracks from each version
$rows = @()

foreach ($master in $numberedMasters) {
    # Extract issue number from title (e.g., "Now 50" → 50)
    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)
    
    # Log progress
    Write-Host "Processing: $($master.title) (Issue $issueNumber)..." -ForegroundColor Cyan

    # Step 3a: Get all versions (different pressings/formats) of this master
    $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
    try {
        $versions = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get
        
        # Validate response
        if (-not $versions.versions) {
            Write-Host "  WARNING: No versions found for master $($master.id)" -ForegroundColor Yellow
            continue
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "  ERROR: API call failed - $versionsUrl" -ForegroundColor Red
        Write-Host "  Status Code: $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Host "  Authentication failed. Check your DISCOGS_TOKEN." -ForegroundColor Red
        } elseif ($statusCode -eq 429) {
            Write-Host "  Rate limit exceeded. Consider adding delays between requests." -ForegroundColor Red
        }
        
        throw
    }

    foreach ($v in $versions.versions) {
        # Step 3b: Get detailed release information including tracklist
        $releaseUrl = "$BaseUrl/releases/$($v.id)"
        try {
            $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get
            
            # Validate response has tracklist
            if (-not $releaseData.tracklist) {
                Write-Host "  WARNING: No tracklist found for release $($v.id)" -ForegroundColor Yellow
                continue
            }
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "  ERROR: API call failed - $releaseUrl" -ForegroundColor Red
            Write-Host "  Status Code: $statusCode" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($statusCode -eq 401 -or $statusCode -eq 403) {
                Write-Host "  Authentication failed. Check your DISCOGS_TOKEN." -ForegroundColor Red
            } elseif ($statusCode -eq 429) {
                Write-Host "  Rate limit exceeded. Consider adding delays between requests." -ForegroundColor Red
            }
            
            throw
        }
        
        # Add rate limiting protection
        Start-Sleep -Milliseconds 100

        $year = $releaseData.year

        # Step 3c: Determine format and version label (e.g., "CD-Remaster")
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName  = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }

        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions

        # Step 3d: Process each track in the release
        foreach ($t in $releaseData.tracklist) {
            if (-not $t.title) { continue }  # Skip tracks without titles

            # Parse track position (e.g., "A1" or "1-05") into disc and track number
            $parsed = Parse-DiscAndTrack -Position $t.position
            $disc  = $parsed.Disc
            $track = $parsed.TrackNumber

            # Extract artist name (may be in 'artists' array for VA compilations)
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

