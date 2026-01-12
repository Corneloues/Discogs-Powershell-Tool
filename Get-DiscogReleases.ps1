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

#==============================================================================
# MAIN PROGRAM FLOW
#==============================================================================

# Step 1: Fetch all releases from the specified Discogs label
$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

# Step 2: Filter releases based on configured criteria
# - Filter by type (e.g., "master" releases)
# - Filter by role (e.g., "Main" releases)
# - Filter by title pattern (e.g., matching specific series names)
# - Sort by extracted number in title
$numberedMasters = $allReleases |
    Where-Object {
        $_.type -eq $whereType -and
        $_.role -eq $whereRole -and
        $_.title -match $whereMatch
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# Step 3: Process each master release to extract detailed track information
$rows = @()

foreach ($master in $numberedMasters) {
    # Extract issue number from title
    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)

    # Step 3a: Get all versions (pressings) of this master release
    $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
    $versions    = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get

    foreach ($v in $versions.versions) {
        # Step 3b: Get detailed information for each specific version
        $releaseUrl  = "$BaseUrl/releases/$($v.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get

        $year = $releaseData.year
        
        # Extract format information (e.g., CD, Vinyl, Cassette)
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName  = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }

        # Generate version label (e.g., "CD-Remaster", "Vinyl-Original")
        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions

        # Step 3c: Extract track details for this version
        foreach ($t in $releaseData.tracklist) {
            if (-not $t.title) { continue }  # Skip tracks without titles

            # Parse track position into disc and track number
            $parsed = Parse-DiscAndTrack -Position $t.position
            $disc  = $parsed.Disc
            $track = $parsed.TrackNumber

            # Extract artist name (varies by release type)
            $artistName = $null
            if ($t.artists -and $t.artists.Count -gt 0) {
                $artistName = ($t.artists | Select-Object -First 1).name
            }

            # Add track to results
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

# Step 4: Export all tracks to CSV file, sorted by issue, format, version, disc, and track
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

Write-Host "✅ Successfully exported $($rows.Count) tracks to $fileName.csv"

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

<#
.SYNOPSIS
    Retrieves all releases from a Discogs label with pagination support.

.DESCRIPTION
    Fetches all releases for a specified label ID from the Discogs API.
    Automatically handles pagination to retrieve all results across multiple pages.
    Uses the global $BaseUrl and $Headers variables for API requests.

.PARAMETER LabelId
    The Discogs label ID to query. This is a numeric identifier.

.PARAMETER PerPage
    Number of results to fetch per page. Default is 100 (maximum allowed by API).

.OUTPUTS
    Array of release objects containing information about each release from the label.

.EXAMPLE
    $releases = Get-DiscogsLabelReleases -LabelId 563691
    Retrieves all releases from label ID 563691.

.NOTES
    Requires $BaseUrl and $Headers to be set globally before calling this function.
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
    Determines a version label based on format and release descriptions.

.DESCRIPTION
    Creates a descriptive label for a release version by combining the format name
    with characteristics from the release descriptions (e.g., Remastered, Reissue).
    Used to distinguish between different versions of the same release.

.PARAMETER FormatName
    The format of the release (e.g., "CD", "Vinyl", "Cassette").

.PARAMETER Descriptions
    Array of description strings from the release metadata (e.g., "Remastered", "Reissue", "Club Edition").

.OUTPUTS
    String in format "{FormatName}-{Suffix}" (e.g., "CD-Remaster", "Vinyl-Original").

.EXAMPLE
    $label = Get-VersionLabel -FormatName "CD" -Descriptions @("Remastered", "Compilation")
    Returns "CD-Remaster"

.NOTES
    Priority order: Remastered > Reissue > Repress > Club Edition > Promo > Original (default).
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
    Parses track position strings into disc and track numbers.

.DESCRIPTION
    Converts various track position formats from Discogs (vinyl and CD formats)
    into standardized disc and track number values. Handles both letter-based
    vinyl positions (A1, B2) and numeric CD positions (1-01, 2-07).

.PARAMETER Position
    The position string from Discogs tracklist (e.g., "A1", "B12", "1-05", "2-10").

.OUTPUTS
    PSCustomObject with properties:
    - Disc: Disc identifier (letter for vinyl, number for CD)
    - TrackNumber: Track number as integer

.EXAMPLE
    $parsed = Parse-DiscAndTrack -Position "A5"
    Returns object with Disc="A", TrackNumber=5

.EXAMPLE
    $parsed = Parse-DiscAndTrack -Position "2-07"
    Returns object with Disc="2", TrackNumber=7

.NOTES
    Fallback for unrecognized formats: Disc=1, TrackNumber=0
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
