<#
.SYNOPSIS
    Helper functions for Discogs API interactions.

.DESCRIPTION
    This module contains helper functions used by Get-DiscogReleases.ps1
    for querying the Discogs API and processing release data.

.NOTES
    Requires $BaseUrl and $Headers variables to be set at script level.
#>

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
    
    Write-Host "  Fetching releases from label $LabelId (paginated)..."

    do {
        $url = "$BaseUrl/labels/$LabelId/releases?per_page=$PerPage&page=$page"
        
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Get
            
            # Validate response
            if (-not $response.releases) {
                Write-Host "  WARNING: No releases in response for page $page" -ForegroundColor Yellow
                break
            }
            
            if (-not $response.pagination) {
                Write-Host "  WARNING: No pagination info in response" -ForegroundColor Yellow
                $results += $response.releases
                break
            }
            
            Write-Host "    Page $page - Fetched $($response.releases.Count) releases"
            
            # Log total pages on first iteration
            if ($page -eq 1) {
                Write-Host "  Total pages to fetch: $($response.pagination.pages)"
            }
            
            $results += $response.releases
            $page++
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "  ERROR: API call failed - $url" -ForegroundColor Red
            Write-Host "  Status Code: $statusCode" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($statusCode -eq 401 -or $statusCode -eq 403) {
                Write-Host "  Authentication failed. Check your DISCOGS_TOKEN." -ForegroundColor Red
            } elseif ($statusCode -eq 429) {
                Write-Host "  Rate limit exceeded. Consider adding delays between requests." -ForegroundColor Red
            }
            
            throw
        }
    } while ($response.pagination.page -lt $response.pagination.pages)
    
    Write-Host "  Completed: Retrieved $($results.Count) total releases"

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
