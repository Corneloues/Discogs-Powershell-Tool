# Discogs-Powershell-Tool
Extract release information from Discogs to CSV

## Overview
This tool uses the Discogs API to extract release information from labels and exports the data to CSV format.

## Manual Usage
1. Copy `Config.example.ps1` to `Config.ps1`
2. Add your Discogs API token to `Config.ps1`
3. Run `Get-DiscogReleases.ps1` using PowerShell

## Automated GitHub Actions Workflow

### Setup
The repository includes a GitHub Actions workflow (`.github/workflows/discogs-extract.yml`) that automatically extracts Discogs data on a schedule or on-demand.

**Required Setup:**
1. Add your Discogs API token as a GitHub Secret:
   - Go to your repository Settings → Secrets and variables → Actions
   - Create a new secret named `DISCOGS_TOKEN`
   - Paste your Discogs API token as the value

### Running the Workflow

#### Manual Trigger
1. Go to the "Actions" tab in your GitHub repository
2. Select "Extract Discogs Release Information" workflow
3. Click "Run workflow"
4. (Optional) Customize inputs:
   - **Label ID**: Discogs label ID to extract (default: 563691)
   - **Per Page**: Number of results per page (default: 100)
   - **Commit Message**: Custom message for the commit (optional)

#### Scheduled Run
- The workflow automatically runs every Sunday at midnight UTC
- Generated CSV files are committed back to the repository

### Workflow Features
- ✅ Extracts Discogs release data using PowerShell Core
- ✅ Commits CSV output back to the repository with timestamps
- ✅ Uploads CSV files as artifacts (30-day retention)
- ✅ Handles cases where data hasn't changed (no empty commits)
- ✅ Provides detailed workflow summary with file sizes

### Artifacts
After each workflow run, CSV files are available:
1. **In the repository**: Committed automatically after generation
2. **As artifacts**: Available for download from the Actions tab for 30 days
