# Copy this file to Config.ps1 and add your Discogs API token
$DiscogsToken = "<YOUR_TOKEN_HERE>"
$BaseUrl      = "https://api.discogs.com"
$Headers      = @{
    "User-Agent" = "RoyNowDiscogsScript/1.0"
    "Authorization" = "Discogs token=$DiscogsToken"
}