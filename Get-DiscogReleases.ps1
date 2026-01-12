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

# Validate required environment variables
if (-not $DiscogsToken) { throw "DISCOGS_TOKEN environment variable is required" }
if (-not $BaseUrl) { throw "BASE_URL environment variable is required" }
if (-not $UserAgent) { throw "USER_AGENT environment variable is required" }
if (-not $labelIdStr) { throw "LABEL_ID environment variable is required" }
if (-not $whereType) { throw "WHERE_TYPE environment variable is required" }
if (-not $whereRole) { throw "WHERE_ROLE environment variable is required" }
if (-not $whereMatch) { throw "WHERE_MATCH environment variable is required" }
if (-not $fileName) { throw "FILE_NAME environment variable is required" }

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

Write-Host "================================================"
Write-Host "Starting Discogs Release Extraction"
Write-Host "================================================"
Write-Host "Configuration:"
Write-Host "  Base URL: $BaseUrl"
Write-Host "  Label ID: $labelId"
Write-Host "  Filter - Type: $whereType, Role: $whereRole"
Write-Host "  Filter - Match Pattern: $whereMatch"
Write-Host "  Output File: $fileName.csv"
Write-Host ""

# Import helper functions
. "$PSScriptRoot/DiscogsHelpers.ps1"

# ============================================================================
# MAIN PROGRAM - Process Discogs Label Releases
# ============================================================================

# Step 1: Retrieve all releases from the specified label
$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

Write-Host "✓ Retrieved $($allReleases.Count) total releases from label"
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

Write-Host "✓ Filtered to $($numberedMasters.Count) releases matching criteria:"
foreach ($m in $numberedMasters) {
    Write-Host "  - $($m.title) (ID: $($m.id))"
}
Write-Host ""

if ($numberedMasters.Count -eq 0) {
    Write-Host "⚠ WARNING: No releases matched the filter criteria!" -ForegroundColor Yellow
    Write-Host "  Check that WHERE_TYPE, WHERE_ROLE, and WHERE_MATCH are correct." -ForegroundColor Yellow
    Write-Host "  Creating empty CSV file..." -ForegroundColor Yellow
}

# Step 3: Process each master release to extract track information
# For each master: fetch all versions, then all tracks from each version
$rows = @()

foreach ($master in $numberedMasters) {
    # Extract issue number from title (e.g., "Now 50" → 50)
    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)

    Write-Host "Processing: $($master.title) (Issue #$issueNumber)..."

    # Step 3a: Get all versions (different pressings/formats) of this master
    try {
        $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
        $versions    = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get
        Write-Host "  Found $($versions.versions.Count) versions"
    } catch {
        Write-Host "  ⚠ ERROR fetching versions: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        }
        continue
    }

    foreach ($v in $versions.versions) {
        # Step 3b: Get detailed release information including tracklist
        try {
            $releaseUrl  = "$BaseUrl/releases/$($v.id)"
            $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get
        } catch {
            Write-Host "    ⚠ ERROR fetching release $($v.id): $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.Response) {
                Write-Host "    HTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            }
            continue
        }

        $year = $releaseData.year

        # Step 3c: Determine format and version label (e.g., "CD-Remaster")
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName  = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }

        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions

        Write-Host "    Processing release ID $($v.id) - $($releaseData.year) - $formatName"
        Write-Host "      Tracks: $($releaseData.tracklist.Count)"

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

        # Respect API rate limits (1 request per second)
        Start-Sleep -Milliseconds 1000
    }
}

# Step 4: Export all collected track data to CSV file
# Sorted by: Issue → Format → Version → Disc → Track Number
if ($rows.Count -eq 0) {
    Write-Host "⚠ WARNING: No tracks were extracted. CSV will be empty." -ForegroundColor Yellow
}

$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

Write-Host ""
Write-Host "================================================"
Write-Host "Extraction Complete!"
Write-Host "================================================"
Write-Host "Summary:"
Write-Host "  Total releases fetched: $($allReleases.Count)"
Write-Host "  Releases matching filters: $($numberedMasters.Count)"
Write-Host "  Total tracks exported: $($rows.Count)"
Write-Host "  Output file: $fileName.csv"
Write-Host "================================================"

