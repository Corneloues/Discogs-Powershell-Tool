# Discogs PowerShell Tool

Extract comprehensive release information from Discogs labels to CSV format using automated GitHub Actions.

## 📖 Overview

This tool queries the [Discogs API](https://www.discogs.com/developers) to retrieve detailed track information from music label releases. It's designed to run automatically via GitHub Actions, with all configuration managed through GitHub Secrets and Variables for maximum security and flexibility.

**Key Features:**
- 🔒 Secure API token storage (GitHub Secrets)
- ⚙️ Fully configurable via GitHub Variables (no code changes needed)
- 🤖 Automated execution (manual trigger or scheduled)
- 📊 Exports detailed track data to CSV
- 🔄 Handles pagination and multiple release versions
- 💿 Supports vinyl and CD track formats

## 🔒 Security Note for Public Repositories

**Your secrets are safe!** This repository can remain public while keeping your Discogs API token secure:

- ✅ **GitHub Secrets** are encrypted and never exposed in logs or to the public
- ✅ Only repository owners/collaborators can manually trigger workflows
- ✅ Only repository owners/collaborators can access or modify secrets
- ✅ Pull requests from forks cannot access your secrets
- ✅ Action Variables are visible but contain no sensitive data

**Others who want to use this code must:**
1. Fork/clone the repository to their own GitHub account
2. Obtain their own Discogs API token
3. Configure their own secrets and variables
4. Run workflows in their own repository

[Learn more about GitHub Actions security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

## 🚀 For Repository Owners: Running the Workflow

### Manual Execution

1. Go to the **Actions** tab in your repository
2. Click on the **"Extract Discogs Releases"** workflow in the left sidebar
3. Click the **"Run workflow"** button (top right)
4. (Optional) Override default values:
   - **label_id**: Enter a different Discogs label ID to query
   - **file_name**: Enter a custom filename (without .csv extension)
5. Click the green **"Run workflow"** button
6. Wait for the workflow to complete (you'll see a green checkmark)
7. The generated CSV file will be committed to your repository automatically
8. You can also download the CSV from the **Artifacts** section at the bottom of the workflow run page

### Schedule Management

The workflow is configured to run automatically every **Sunday at midnight UTC**.

**To modify the schedule:**

1. Edit `.github/workflows/discogs-extract.yml`
2. Find the `schedule` section:
   ```yaml
   schedule:
     - cron: '0 0 * * 0'  # Every Sunday at 00:00 UTC
   ```
3. Change the cron expression:
   - Daily at 2am: `'0 2 * * *'`
   - Every Monday at 9am: `'0 9 * * 1'`
   - First day of month: `'0 0 1 * *'`
   
   [Cron syntax reference](https://crontab.guru/)

4. Commit the change to activate the new schedule

**To disable the schedule:**

1. Edit `.github/workflows/discogs-extract.yml`
2. Comment out or delete the `schedule` section:
   ```yaml
   # schedule:
   #   - cron: '0 0 * * 0'
   ```
3. Commit the change (workflow will only run manually)

### Your Configured Secrets & Variables

**Secret (Settings → Secrets and variables → Actions → Secrets):**
- `DISCOGS_TOKEN` - Your Discogs API authentication token

**Variables (Settings → Secrets and variables → Actions → Variables):**
- `BASE_URL` - Discogs API base URL: `https://api.discogs.com`
- `USER_AGENT` - Your API user agent: `SoundchaserUKDiscogsScript/1.0`
- `NOW_UK_SERIES` - Discogs label ID: `563691`
- `NOW_UK_WHERE_MATCH` - Title regex pattern: `Now That's What I Call Music\s*\d+`
- `NOW_UK_FILE_NAME` - Output filename: `Now_UK_1to122_AllVersions_Tracks`

**Note:** The `NOW_UK_WHERE_TYPE` and `NOW_UK_WHERE_ROLE` variables are no longer used because the `/labels/{id}/releases` API endpoint does not return `type` or `role` fields. Filtering is now done by title pattern only.

---

## 🔧 For New Users: Setup Instructions

Want to use this tool for your own Discogs label tracking? Follow these steps:

### Step 1: Fork or Clone This Repository

1. Click the **"Fork"** button at the top right of this page, OR
2. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/Corneloues/Discogs-Powershell-Tool.git
   ```

### Step 2: Get a Discogs API Token

1. Create a free account at [Discogs.com](https://www.discogs.com/)
2. Go to [Settings → Developers](https://www.discogs.com/settings/developers)
3. Click **"Generate new token"**
4. Copy your token (you'll need it in the next step)
5. **Keep this token secret!** Never commit it to your repository

### Step 3: Configure GitHub Secret

1. In your forked repository, go to **Settings** tab
2. Navigate to **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Name: `DISCOGS_TOKEN`
5. Value: Paste your Discogs API token from Step 2
6. Click **"Add secret"**

### Step 4: Configure GitHub Variables

In the same section (**Settings** → **Secrets and variables** → **Actions**), click the **"Variables"** tab:

Click **"New repository variable"** for each of the following:

| Variable Name | Example Value | Description |
|--------------|---------------|-------------|
| `BASE_URL` | `https://api.discogs.com` | Discogs API base URL (usually doesn't change) |
| `USER_AGENT` | `YourUsername/YourScript/1.0` | Must include your Discogs username per API guidelines |
| `NOW_UK_SERIES` | `563691` | Discogs label ID (see below for how to find this) |
| `NOW_UK_WHERE_MATCH` | `Now That's What I Call Music\s*\d+` | Regex pattern to match titles |
| `NOW_UK_FILE_NAME` | `Now_UK_Tracks` | Output CSV filename (without .csv extension) |

**Note:** The variables `NOW_UK_WHERE_TYPE` and `NOW_UK_WHERE_ROLE` are no longer used because the `/labels/{id}/releases` API endpoint does not return `type` or `role` fields. Filtering is now done by title pattern only.

**Finding a Discogs Label ID:**
1. Go to [Discogs.com](https://www.discogs.com/)
2. Search for the label you want to track
3. Click on the label name
4. The label ID is in the URL: `https://www.discogs.com/label/563691-Now-Thats-What-I-Call-Music`
   - Label ID = `563691`

### Step 5: Run Your First Workflow

1. Go to the **Actions** tab in your repository
2. You may need to enable GitHub Actions for your fork (click the green button)
3. Click **"Extract Discogs Releases"** workflow
4. Click **"Run workflow"** → **"Run workflow"**
5. Wait for completion and check your repository for the CSV file!

---

## 📊 Output Format

The generated CSV file contains the following columns:

| Column | Description |
|--------|-------------|
| `Issue` | The issue/volume number extracted from the title |
| `Year` | Release year |
| `Format` | Physical format (CD, Vinyl, Cassette, etc.) |
| `Version` | Version type (Original, Remaster, Reissue, etc.) |
| `Disc` | Disc identifier (letter for vinyl sides, number for CD) |
| `TrackNumber` | Track number on the disc |
| `Title` | Song title |
| `Artist` | Artist name (if available) |
| `DiscogsReleaseID` | Unique Discogs release ID for reference |

**Example rows:**
```csv
Issue,Year,Format,Version,Disc,TrackNumber,Title,Artist,DiscogsReleaseID
50,2001,CD,Original,1,1,Lady (Hear Me Tonight),Modjo,123456
50,2001,CD,Original,1,2,Groovejet (If This Ain't Love),Spiller,123456
50,2001,Vinyl,Original,A,1,Lady (Hear Me Tonight),Modjo,123457
```

---

## 🎯 Customization Examples

### Track a Different Label

1. Find the Discogs label ID (see instructions above)
2. Update the `NOW_UK_SERIES` variable with the new label ID
3. Update `NOW_UK_WHERE_MATCH` to match the title pattern for that label
4. Update `NOW_UK_FILE_NAME` to something descriptive
5. Run the workflow!

### Filter by Release Type

**Note:** The `NOW_UK_WHERE_TYPE` and `NOW_UK_WHERE_ROLE` variables are no longer used because the `/labels/{id}/releases` API endpoint does not return these fields. The script now fetches releases directly without the master/versions layer. Filtering is done by title pattern only using the `NOW_UK_WHERE_MATCH` variable.

### Customize Title Matching

The `NOW_UK_WHERE_MATCH` variable uses regex:
- `Now That's What I Call Music\s*\d+` - Matches "Now That's What I Call Music 50", etc.
- `Volume\s*\d+` - Matches "Volume 1", "Volume 2", etc.
- `.*` - Matches everything (no filtering)

[Learn more about regex](https://regexr.com/)

### Track Multiple Labels

Create multiple copies of the workflow file with different configurations:
1. Duplicate `.github/workflows/discogs-extract.yml`
2. Rename it (e.g., `discogs-jazz-series.yml`)
3. Create new variables: `JAZZ_SERIES`, `JAZZ_WHERE_MATCH`, `JAZZ_FILE_NAME`
4. Update the workflow to use the new variables

---

## 🛠️ Troubleshooting

### Error: "DISCOGS_TOKEN environment variable is required"

**Cause:** The `DISCOGS_TOKEN` secret is not configured.

**Solution:**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Verify `DISCOGS_TOKEN` exists in the **Secrets** tab
3. If missing, create it with your Discogs API token

### Error: "401 Unauthorized"

**Cause:** Invalid or expired Discogs API token.

**Solution:**
1. Generate a new token at [Discogs Developer Settings](https://www.discogs.com/settings/developers)
2. Update the `DISCOGS_TOKEN` secret in your repository

### Error: "You must provide a unique User-Agent"

**Cause:** The `USER_AGENT` variable doesn't meet Discogs requirements.

**Solution:**
1. Update the `USER_AGENT` variable to include your Discogs username
2. Format: `YourDiscogsUsername/ScriptName/1.0`
3. Example: `JohnDoe/MyDiscogsScript/1.0`

### Workflow Doesn't Run on Schedule

**Possible causes:**
- Repository has no recent activity (GitHub may disable scheduled workflows)
- Cron syntax error

**Solution:**
1. Make a commit to re-activate scheduled workflows
2. Verify cron syntax at [crontab.guru](https://crontab.guru/)

### Empty or Incomplete CSV

**Cause:** Filter criteria too restrictive or label has no matching releases.

**Solution:**
1. Check the workflow logs to see how many releases were found
2. Adjust filter variables (`NOW_UK_WHERE_TYPE`, `NOW_UK_WHERE_ROLE`, `NOW_UK_WHERE_MATCH`)
3. Try setting `NOW_UK_WHERE_MATCH` to `.*` to match all titles

---

## 📚 Resources

- [Discogs API Documentation](https://www.discogs.com/developers)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Secrets Guide](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Cron Expression Reference](https://crontab.guru/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Regular Expressions Tutorial](https://regexr.com/)

---

## 📝 License

This project is open source and available for anyone to use and modify.

## 🤝 Contributing

Found a bug or have a feature request? Feel free to open an issue or submit a pull request!

---

**Happy cataloging! 🎵**
