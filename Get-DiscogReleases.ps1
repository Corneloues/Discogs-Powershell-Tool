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

# ============================================================================
# MAIN PROGRAM - Process Discogs Label Releases
# ============================================================================

# Step 1: Retrieve all releases from the specified label
$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

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

# Step 3: Process each master release to extract track information
# For each master: fetch all versions, then all tracks from each version
$rows = @()

foreach ($master in $numberedMasters) {
    # Extract issue number from title (e.g., "Now 50" → 50)
    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)

    # Step 3a: Get all versions (different pressings/formats) of this master
    $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
    $versions    = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get

    foreach ($v in $versions.versions) {
        # Step 3b: Get detailed release information including tracklist
        $releaseUrl  = "$BaseUrl/releases/$($v.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get

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

# Step 4: Export all collected track data to CSV file
# Sorted by: Issue → Format → Version → Disc → Track Number
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Retrieves all releases for a specified Discogs label with automatic pagination.

.DESCRIPTION
    Queries the Discogs API to fetch all releases associated with a given label ID.
    Automatically handles pagination to retrieve all results across multiple pages.
    Uses the $BaseUrl and $Headers script-level variables for API access.

.PARAMETER LabelId
    The Discogs label ID to query. This is a numeric identifier from Discogs.

.PARAMETER PerPage
    Number of results per page. Default is 100 (maximum allowed by Discogs API).

.OUTPUTS
    System.Array
    Returns an array of release objects containing metadata for each release.

.EXAMPLE
    $releases = Get-DiscogsLabelReleases -LabelId 563691
    Retrieves all releases from label ID 563691

.NOTES
    Requires $BaseUrl and $Headers variables to be set at script level.
    May take some time for labels with many releases due to API rate limiting.
#>
function Get-DiscogsLabelReleases {
    param(
        [int]$LabelId,
        [int]$PerPage = 100
    )
    $page = 1
    $results = @()

    do {
        $url = "$BaseUrl/labels/$LabelId/releases?per_page=$PerPage&page=$page"
        $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Get
        $results += $response.releases
        $page++
    } while ($response.pagination.page -lt $response.pagination.pages)

    return $results
}

<#
.SYNOPSIS
    Determines the version label for a release based on format and descriptions.

.DESCRIPTION
    Analyzes the format name and description tags from a Discogs release to
    categorize it as Original, Remaster, Reissue, Repress, Club Edition, or Promo.
    Uses a priority-based system where the first matching description wins.

.PARAMETER FormatName
    The name of the format (e.g., "CD", "Vinyl", "Cassette")

.PARAMETER Descriptions
    An array of description strings associated with the release format.
    Common values include "Remastered", "Reissue", "Repress", "Club Edition", "Promo"

.OUTPUTS
    System.String
    Returns a combined string in format "FormatName-VersionType"
    Example: "CD-Remaster", "Vinyl-Original"

.EXAMPLE
    $label = Get-VersionLabel -FormatName "CD" -Descriptions @("Remastered")
    Returns: "CD-Remaster"

.EXAMPLE
    $label = Get-VersionLabel -FormatName "Vinyl" -Descriptions @()
    Returns: "Vinyl-Original"

.NOTES
    Priority order: Remastered > Reissue > Repress > Club Edition > Promo > Original
#>
function Get-VersionLabel {
    param(
        [string]$FormatName,
        [string[]]$Descriptions
    )

    $suffix = "Original"

    if ($Descriptions -contains "Remastered") { $suffix = "Remaster" }
    elseif ($Descriptions -contains "Reissue") { $suffix = "Reissue" }
    elseif ($Descriptions -contains "Repress") { $suffix = "Repress" }
    elseif ($Descriptions -contains "Club Edition") { $suffix = "Club" }
    elseif ($Descriptions -contains "Promo") { $suffix = "Promo" }

    return "$FormatName-$suffix"
}

<#
.SYNOPSIS
    Parses track position strings into disc and track number components.

.DESCRIPTION
    Handles multiple track position formats from Discogs:
    - Vinyl format: A1, B2, C10 (letter = disc side, number = track)
    - CD format: 1-01, 2-07 (disc-track notation)
    - Fallback: Treats unrecognized formats as disc 1, track 0

.PARAMETER Position
    The position string from the Discogs tracklist (e.g., "A1", "1-05")

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns an object with two properties:
    - Disc: The disc identifier (letter for vinyl, number for CD)
    - TrackNumber: The track number (integer)

.EXAMPLE
    $parsed = Parse-DiscAndTrack -Position "A5"
    Returns: @{ Disc = "A"; TrackNumber = 5 }

.EXAMPLE
    $parsed = Parse-DiscAndTrack -Position "2-07"
    Returns: @{ Disc = "2"; TrackNumber = 7 }

.NOTES
    Leading zeros in CD track numbers are automatically removed.
    Invalid position formats default to disc "1", track 0.
#>
function Parse-DiscAndTrack {
    param(
        [string]$Position
    )

    # Vinyl: A1, B2, C10 etc.
    if ($Position -match '^[A-Z](\d+)$') {
        $disc  = $Position.Substring(0,1)
        $track = [int]$matches[1]
    }
    # CD: 1-01, 2-07, 3-12, etc.
    elseif ($Position -match '^(\d+)-0*(\d+)$') {
        $disc  = $matches[1]
        $track = [int]$matches[2]
    }
    else {
        # fallback – no clean position, treat as disc 1, and track = 0 or increment later
        $disc  = "1"
        $track = 0
    }

    [pscustomobject]@{
        Disc        = $disc
        TrackNumber = $track
    }
}
