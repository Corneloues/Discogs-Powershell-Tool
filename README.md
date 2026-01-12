# Discogs PowerShell Tool

## Overview
A PowerShell script that extracts release information from Discogs and exports it to CSV format, designed to run as a GitHub Action.

## Features
- Automatically fetches releases from a Discogs label
- Filters releases based on configurable criteria
- Extracts detailed track information
- Exports to CSV format
- Runs on schedule or on-demand via GitHub Actions
- Fully configurable via GitHub Secrets and Variables

## How It Works

The workflow:
1. Connects to the Discogs API using your token
2. Fetches all releases for a specified label ID
3. Filters releases by type, role, and title pattern
4. For each matching release, retrieves all versions
5. Extracts track-level details (disc, track number, title, artist)
6. Exports everything to a CSV file
7. Commits the CSV back to the repository
8. Uploads CSV as a downloadable artifact

---

## Setup Instructions

### Prerequisites
- A GitHub account
- A Discogs account and API token

### For Repository Owner

#### 1. Get Your Discogs API Token
1. Log in to <a href="https://www.discogs.com">Discogs.com</a>
2. Go to Settings → Developers
3. Click "Generate new token"
4. Copy the token (you'll need it in the next step)
5. **Important:** Never commit this token to your code!

#### 2. Configure GitHub Secret
1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `DISCOGS_TOKEN`
5. Value: Paste your Discogs API token
6. Click **Add secret**

#### 3. Configure GitHub Action Variables
In the same **Secrets and variables** → **Actions** section:
1. Click the **Variables** tab
2. Add each of these variables:

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `BASE_URL` | `https://api.discogs.com` | Discogs API base URL |
| `USER_AGENT` | `DiscogsExtractor/1.0` | User agent string for API requests |
| `NOW_UK_SERIES` | `563691` | Discogs label ID to query |
| `NOW_UK_WHERE_TYPE` | `master` | Filter by release type |
| `NOW_UK_WHERE_ROLE` | `Main` | Filter by role |
| `NOW_UK_WHERE_MATCH` | `Now That's What I Call Music\s*\d+` | Regex pattern to match titles |
| `NOW_UK_FILE_NAME` | `Now_UK_1to122_AllVersions_Tracks` | Output CSV filename (without .csv) |

---

## Running the Workflow

### Manual Execution
1. Go to the **Actions** tab in your repository
2. Select the "Extract Discogs Releases" workflow (or whatever the workflow is named)
3. Click **Run workflow** button
4. Select the branch (usually `main`)
5. Click **Run workflow** to start
6. Wait for completion (may take several minutes depending on data size)
7. Download the CSV from the workflow run artifacts, or find it committed to your repository

### Scheduled Execution

The workflow is configured to run automatically:
- **Schedule:** Every Sunday at midnight UTC (weekly)
- **Cron expression:** `0 0 * * 0`

#### To Disable the Schedule:
1. Edit `.github/workflows/discogs-extract.yml`
2. Comment out or remove the `schedule:` section:
```yaml
# schedule:
#   - cron: '0 0 * * 0'
```
3. Commit the change

#### To Change the Schedule:
1. Edit `.github/workflows/discogs-extract.yml`
2. Modify the cron expression in the `schedule:` section
3. Use <a href="https://crontab.guru">crontab.guru</a> to help generate cron expressions
4. Examples:
   - Daily at 2 AM UTC: `0 2 * * *`
   - Every Monday at 9 AM UTC: `0 9 * * 1`
   - First day of every month: `0 0 1 * *`

---

## For Others: Fork and Use This Tool

Want to use this tool for your own Discogs data extraction? Here's how:

### 1. Fork This Repository
1. Click the **Fork** button at the top right of this repository
2. This creates a copy in your own GitHub account

### 2. Get Your Own Discogs API Token
1. Create a Discogs account at <a href="https://www.discogs.com">Discogs.com</a> if you don't have one
2. Go to Settings → Developers
3. Generate a new token
4. Copy it for the next step

### 3. Set Up Your Secrets
In your forked repository:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Create a new secret:
   - Name: `DISCOGS_TOKEN`
   - Value: Your Discogs API token

### 4. Set Up Your Variables
In the **Variables** tab, create these 7 variables:

| Variable | What It Does | How to Find/Set It |
|----------|--------------|-------------------|
| `BASE_URL` | Discogs API endpoint | Use: `https://api.discogs.com` |
| `USER_AGENT` | User agent for API requests | Use: `DiscogsExtractor/1.0` or similar |
| `NOW_UK_SERIES` | Label ID to query | Find your label on Discogs, get ID from URL |
| `NOW_UK_WHERE_TYPE` | Release type filter | Common: `master`, `release` |
| `NOW_UK_WHERE_ROLE` | Role filter | Common: `Main` |
| `NOW_UK_WHERE_MATCH` | Title regex pattern | Customize for your label's naming pattern |
| `NOW_UK_FILE_NAME` | Output filename | Choose any name (no .csv extension) |

**Finding a Label ID:**
1. Go to Discogs.com and search for a label
2. Click on the label name
3. Look at the URL: `https://discogs.com/label/563691-Now-Thats-What-I-Call-Music`
4. The number after `/label/` is your label ID (563691 in this example)

### 5. Customize for Your Use Case

You can adapt this script for different music series or labels by changing the variables:

**Example: Different Label**
- Change `NOW_UK_SERIES` to a different label ID
- Update `NOW_UK_WHERE_MATCH` to match different title patterns
- Update `NOW_UK_FILE_NAME` to reflect the new series

**Example: Different Filters**
- Change `NOW_UK_WHERE_TYPE` to `release` instead of `master`
- Change `NOW_UK_WHERE_ROLE` to filter different roles
- Adjust the regex in `NOW_UK_WHERE_MATCH` for different naming conventions

### 6. Run Your Workflow
Follow the "Running the Workflow" instructions above to execute manually or on schedule!

---

## Output

The script generates a CSV file with the following columns:
- **Issue** - Issue/volume number
- **Year** - Release year
- **Format** - Release format (CD, Vinyl, etc.)
- **Version** - Version label
- **Disc** - Disc number
- **TrackNumber** - Track number on disc
- **Title** - Track title
- **Artist** - Track artist
- **DiscogsReleaseID** - Discogs release ID for reference

The CSV is automatically:
- Committed back to your repository (appears in the root directory)
- Uploaded as a workflow artifact (downloadable for 30 days)

---

## Troubleshooting

### Workflow Fails with "Environment variable required"
- Check that all secrets and variables are configured correctly
- Variable names are case-sensitive and must match exactly

### API Rate Limiting
- Discogs has rate limits (60 requests per minute for authenticated users)
- The script includes delays but may still hit limits for very large labels
- If this happens, the workflow will fail - just run it again later

### No CSV Output
- Check that your label ID is correct
- Check that your filter criteria match actual releases
- Review the workflow logs for errors

### Secrets Are Exposed in Logs
- GitHub automatically masks secrets in workflow logs
- If you see `***` in logs, that's normal - the secret is hidden
- Never use `Write-Output` or `echo` with secret values

---

## Security Notes

### Your Repository Security
- ✅ Secrets are encrypted and never exposed in logs
- ✅ Only you (and collaborators) can trigger workflows
- ✅ Forked repositories cannot access your secrets
- ✅ Safe to keep repository public

### Best Practices
- Never commit tokens or secrets to code
- Rotate your Discogs token periodically
- Review Action variable values (they're visible to repo viewers)
- If a token is exposed, revoke it immediately and generate a new one

---

## GitHub Actions Permissions

**Who can run workflows in a public repo?**
- ✅ Repository owner (you)
- ✅ Collaborators with write access
- ❌ Random public users (they can view but not execute)

To share this tool, others must fork it and set up their own secrets/variables.

---

## Contributing

Issues and pull requests are welcome! If you find a bug or have a feature suggestion, please open an issue.

---

## License

[Choose your license - MIT, Apache, etc., or state "No license specified"]

---

## Credits

Created for extracting "Now That's What I Call Music!" UK series data from Discogs, but adaptable for any label or compilation series.
