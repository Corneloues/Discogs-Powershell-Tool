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

.NOTES
    This script is designed to run in GitHub Actions with secrets and variables.
#>

# Read configuration from environment variables (passed from GitHub Actions)
$DiscogsToken = $env:DISCOGS_TOKEN
$BaseUrl      = $env:BASE_URL
$UserAgent    = $env:USER_AGENT
$labelIdStr   = $env:LABEL_ID

# Validate required environment variables
if (-not $DiscogsToken) { throw "DISCOGS_TOKEN environment variable is required" }
if (-not $BaseUrl) { throw "BASE_URL environment variable is required" }
if (-not $UserAgent) { throw "USER_AGENT environment variable is required" }
if (-not $labelIdStr) { throw "LABEL_ID environment variable is required" }

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

$allReleases = Get-DiscogsLabelReleases -LabelId $labelId

$numberedMasters = $allReleases |
    Where-Object {
        $_.type -eq "master" -and
        $_.role -eq "Main" -and
        $_.title -match "Now That's What I Call Music\s*\d+"
    } |
    Sort-Object { [int]([regex]::Match($_.title, '\d+').Value) }

# Work through the releases returned by the API

$rows = @()

foreach ($master in $numberedMasters) {

    $issueNumber = [int]([regex]::Match($master.title, '\d+').Value)

    # Get versions for this master
    $versionsUrl = "$BaseUrl/masters/$($master.id)/versions?per_page=100"
    $versions    = Invoke-RestMethod -Uri $versionsUrl -Headers $Headers -Method Get

    foreach ($v in $versions.versions) {
        # Get the concrete release
        $releaseUrl  = "$BaseUrl/releases/$($v.id)"
        $releaseData = Invoke-RestMethod -Uri $releaseUrl -Headers $Headers -Method Get

        $year = $releaseData.year

        # Use first format entry
        $firstFormat = $releaseData.formats | Select-Object -First 1
        $formatName  = $firstFormat.name
        $descriptions = @()
        if ($firstFormat.descriptions) { $descriptions = $firstFormat.descriptions }

        $versionLabel = Get-VersionLabel -FormatName $formatName -Descriptions $descriptions

        foreach ($t in $releaseData.tracklist) {
            if (-not $t.title) { continue }

            $parsed = Parse-DiscAndTrack -Position $t.position

            $disc  = $parsed.Disc
            $track = $parsed.TrackNumber

            # track artist: sometimes null; sometimes in extraartists; often in 'artists' for VA
            $artistName = $null
            if ($t.artists -and $t.artists.Count -gt 0) {
                $artistName = ($t.artists | Select-Object -First 1).name
            }

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

# Export CSV File
$rows | Sort-Object Issue, Format, Version, Disc, TrackNumber |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path ".\Now_UK_1to122_AllVersions_Tracks.csv"

<#
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
