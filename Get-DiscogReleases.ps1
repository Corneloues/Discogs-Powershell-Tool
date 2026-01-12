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

<#
==============================================================================
SCRIPT OVERVIEW
==============================================================================
This script extracts Discogs label releases to CSV format with detailed
track information. It is designed to run as a GitHub Action with configuration
via environment variables (GitHub Secrets and Variables).

MAIN WORKFLOW:
1. Fetch all releases for a specified Discogs label ID (with pagination)
2. Filter releases by type, role, and title pattern (e.g., numbered compilations)
3. For each matching master release, retrieve all available versions
4. Extract detailed track information (disc, track number, title, artist)
5. Export all data to a CSV file
6. CSV is committed back to the repository and uploaded as an artifact

REQUIRED ENVIRONMENT VARIABLES:
- DISCOGS_TOKEN: API authentication token (from GitHub Secrets)
- BASE_URL: Discogs API endpoint
- LABEL_ID: Discogs label ID to query
- WHERE_TYPE, WHERE_ROLE, WHERE_MATCH: Filtering criteria
- FILE_NAME: Output CSV filename (without .csv extension)
==============================================================================
#>

# ============================================================================
# STEP 1: Fetch all releases for the label
# ============================================================================
$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

# ============================================================================
# STEP 2: Filter and sort releases
# ============================================================================
# Filter releases based on configured criteria:
# - Type (e.g., "master" for master releases)
# - Role (e.g., "Main" for main releases)
# - Title pattern (regex match, e.g., "Now That's What I Call Music\s*\d+")
# Then sort by the numeric value extracted from the title (e.g., issue number)
$numberedMasters = $allReleases |
    Where-Object {
        $_.type -eq $whereType -and
        $_.role -eq $whereRole -and
        $_.title -match $whereMatch
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# ============================================================================
# STEP 3: Process each master release and extract track information
# ============================================================================
# For each filtered release, we will:
# - Extract the issue number from the title
# - Fetch all versions (different formats/pressings) of the master release
# - For each version, get detailed release data including tracklist
# - Parse track position (disc and track number)
# - Build a row for each track with all metadata

$rows = @()

foreach ($master in $numberedMasters) {

    # Extract issue number from title (e.g., "Now 55" -> 55)
    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)

    # Get all versions (formats/pressings) for this master release
    $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
    $versions    = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get

    foreach ($v in $versions.versions) {
        # Get detailed data for this specific release version
        $releaseUrl  = "$BaseUrl/releases/$($v.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get

        $year = $releaseData.year

        # Extract format information (CD, Vinyl, etc.) and descriptions (Remaster, Reissue, etc.)
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName  = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }

        # Generate a version label (e.g., "CD-Remaster", "Vinyl-Original")
        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions

        # Process each track in the tracklist
        foreach ($t in $releaseData.tracklist) {
            # Skip tracks without titles (e.g., headings or blank entries)
            if (-not $t.title) { continue }

            # Parse disc and track number from position string (e.g., "1-05" or "A1")
            $parsed = Parse-DiscAndTrack -Position $t.position

            $disc  = $parsed.Disc
            $track = $parsed.TrackNumber

            # Extract track artist name
            # Artist info is sometimes in the 'artists' array (common for compilations)
            $artistName = $null
            if ($t.artists -and $t.artists.Count -gt 0) {
                $artistName = ($t.artists | Select-Object -First 1).name
            }

            # Add a row with all track information
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

# ============================================================================
# STEP 4: Export results to CSV
# ============================================================================
# Sort by issue, format, version, disc, and track number for a clean output
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\$fileName.csv"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Fetches all releases for a given Discogs label ID with pagination.

.DESCRIPTION
    Retrieves the complete list of releases associated with a label from the
    Discogs API. Automatically handles pagination to fetch all results across
    multiple pages.

.PARAMETER LabelId
    The Discogs label ID to query. This is the numeric identifier found in
    the label's URL on Discogs.com (e.g., 563691 for "Now That's What I Call Music").

.PARAMETER PerPage
    Number of results to fetch per page. Default is 100 (maximum allowed by API).
    Higher values reduce the number of API calls needed.

.OUTPUTS
    System.Array
    Returns an array of release objects containing basic release information
    (id, title, type, role, etc.) for all releases associated with the label.

.EXAMPLE
    $releases = Get-DiscogsLabelReleases -LabelId 563691
    Fetches all releases for label ID 563691 with default pagination (100 per page).

.EXAMPLE
    $releases = Get-DiscogsLabelReleases -LabelId 563691 -PerPage 50
    Fetches all releases for label ID 563691 with 50 results per page.

.NOTES
    This function uses the $BaseUrl and $Headers variables from the parent scope.
    It will continue fetching pages until all available releases are retrieved.
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
    Generates a version label from format name and descriptions.

.DESCRIPTION
    Creates a human-readable version label by combining the format name (e.g., CD,
    Vinyl) with a suffix indicating the release type (Original, Remaster, Reissue,
    etc.). The suffix is determined by checking for specific keywords in the
    descriptions array.

.PARAMETER FormatName
    The name of the format (e.g., "CD", "Vinyl", "Cassette"). This will be the
    first part of the generated label.

.PARAMETER Descriptions
    An array of description strings associated with the format (e.g., "Remastered",
    "Reissue", "Club Edition"). The function checks these descriptions in priority
    order to determine the appropriate suffix.

.OUTPUTS
    System.String
    Returns a formatted label string in the format "FormatName-Suffix"
    (e.g., "CD-Remaster", "Vinyl-Original", "CD-Reissue").

.EXAMPLE
    Get-VersionLabel -FormatName "CD" -Descriptions @("Remastered")
    Returns "CD-Remaster"

.EXAMPLE
    Get-VersionLabel -FormatName "Vinyl" -Descriptions @("Reissue", "180g")
    Returns "Vinyl-Reissue"

.EXAMPLE
    Get-VersionLabel -FormatName "CD" -Descriptions @()
    Returns "CD-Original" (default when no special descriptions match)

.NOTES
    Priority order for suffixes:
    1. Remaster (if "Remastered" found)
    2. Reissue (if "Reissue" found)
    3. Repress (if "Repress" found)
    4. Club (if "Club Edition" found)
    5. Promo (if "Promo" found)
    6. Original (default fallback)
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
    Parses disc and track number from a position string.

.DESCRIPTION
    Extracts disc and track number information from Discogs position strings,
    which can have different formats depending on the media type:
    - Vinyl format: "A1", "B2", "C10" (letter = disc, number = track)
    - CD format: "1-01", "2-07", "3-12" (first number = disc, second = track)
    - Fallback: If format is unrecognized, defaults to disc 1, track 0

.PARAMETER Position
    The position string from Discogs tracklist data. Common formats include:
    - "A1", "B5" for vinyl (side A/B/C/D, then track number)
    - "1-01", "2-12" for CDs (disc number, then track number)
    - Other formats may not parse cleanly and will use fallback values

.OUTPUTS
    PSCustomObject
    Returns an object with two properties:
    - Disc: String or integer representing the disc identifier (e.g., "A", "1")
    - TrackNumber: Integer representing the track number on that disc

.EXAMPLE
    Parse-DiscAndTrack -Position "A1"
    Returns object with Disc = "A", TrackNumber = 1 (vinyl format)

.EXAMPLE
    Parse-DiscAndTrack -Position "2-07"
    Returns object with Disc = "2", TrackNumber = 7 (CD format)

.EXAMPLE
    Parse-DiscAndTrack -Position "Video"
    Returns object with Disc = "1", TrackNumber = 0 (fallback for unrecognized format)

.NOTES
    Leading zeros in track numbers are automatically removed (e.g., "01" becomes 1).
    The fallback behavior ensures the script can handle unexpected position formats
    without failing.
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
