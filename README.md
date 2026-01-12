# Discogs PowerShell Tool

Extract detailed release and track information from Discogs labels and export to CSV format. This tool uses the Discogs API to retrieve data about music releases, including all versions (pressings), formats, and complete tracklists.

## 🎯 What This Tool Does

- Queries the Discogs API for all releases from a specified label
- Filters releases based on configurable criteria (type, role, title pattern)
- Retrieves all versions (pressings) of each release
- Extracts complete track information including disc numbers, track positions, titles, and artists
- Exports data to CSV format for analysis in Excel, databases, or other tools
- Runs automatically via GitHub Actions (scheduled or manual)

## 🔒 Security & Privacy

**Your API token is safe!** This repository uses GitHub Secrets and Variables:
- ✅ API token stored in GitHub Secrets (encrypted, never exposed)
- ✅ Workflow can only be triggered by repository owner/collaborators
- ✅ Secrets are automatically masked in all logs
- ✅ Repository can remain public - others cannot access your credentials

## 📋 For Repository Owner: How to Use

### Running the Workflow Manually

1. Go to the **Actions** tab in your repository
2. Select **"Extract Discogs Releases"** workflow from the left sidebar
3. Click **"Run workflow"** button (top right)
4. (Optional) Override default values:
   - **Label ID**: Enter a different label ID to query
   - **File Name**: Specify a custom output filename
5. Click **"Run workflow"** to start
6. Wait for completion (duration depends on label size)
7. View results:
   - **CSV file**: Committed to repository automatically
   - **Artifacts**: Download from workflow run page (30-day retention)

### Managing the Schedule

The workflow is configured to run automatically **every Sunday at midnight UTC**.

#### To Disable Scheduled Runs:
1. Go to `.github/workflows/discogs-extract.yml`
2. Click **Edit** (pencil icon)
3. Comment out or remove the schedule section:
   ```yaml
   # schedule:
   #   - cron: '0 0 * * 0'
   ```
4. Commit the change

#### To Change the Schedule:
Edit the cron expression in `.github/workflows/discogs-extract.yml`:
```yaml
schedule:
  - cron: '0 0 * * 0'  # Sunday at midnight UTC
```

**Common schedules:**
- Daily at 2am UTC: `0 2 * * *`
- Every Monday at 9am UTC: `0 9 * * 1`
- First day of month at midnight: `0 0 1 * *`
- Every 6 hours: `0 */6 * * *`

🔗 [Cron syntax help](https://crontab.guru/)

### Your Current Configuration

**GitHub Secret:**
- `DISCOGS_TOKEN` - Your Discogs API token

**GitHub Action Variables:**
- `BASE_URL` - Discogs API endpoint (https://api.discogs.com)
- `USER_AGENT` - Your user agent string (SoundchaserUKDiscogsScript/1.0)
- `NOW_UK_SERIES` - Label ID to query (e.g., 563691)
- `NOW_UK_WHERE_TYPE` - Release type filter (e.g., "master")
- `NOW_UK_WHERE_ROLE` - Release role filter (e.g., "Main")
- `NOW_UK_WHERE_MATCH` - Title regex pattern (e.g., "Now That's What I Call Music\s*\d+")
- `NOW_UK_FILE_NAME` - Output filename without extension (e.g., "Now_UK_1to122_AllVersions_Tracks")

To modify these values:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Select **Variables** tab
3. Click on variable name to edit

---

## 🚀 For New Users: Setup Instructions

Want to use this tool for your own Discogs label queries? Follow these steps:

### Step 1: Fork or Clone This Repository

**Option A: Fork (Recommended)**
1. Click the **Fork** button (top right of this page)
2. GitHub will create a copy in your account
3. You can sync with upstream updates easily

**Option B: Clone**
```bash
git clone https://github.com/YOUR-USERNAME/Discogs-Powershell-Tool.git
cd Discogs-Powershell-Tool
```

### Step 2: Get a Discogs API Token

1. Go to [Discogs.com](https://www.discogs.com/) and log in
2. Navigate to **Settings** → **Developers**
3. Click **"Generate new token"**
4. Copy the token (you'll need it in the next step)
5. ⚠️ **Keep this token private!** Don't share it or commit it to code

🔗 [Discogs API Documentation](https://www.discogs.com/developers/)

### Step 3: Configure GitHub Secrets

1. In your forked repository, go to **Settings** tab
2. Navigate to **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Create the secret:
   - **Name**: `DISCOGS_TOKEN`
   - **Secret**: Paste your Discogs API token
5. Click **"Add secret"**

### Step 4: Configure GitHub Action Variables

Still in **Settings** → **Secrets and variables** → **Actions**, click the **Variables** tab.

Create these 7 variables by clicking **"New repository variable"** for each:

| Variable Name | Example Value | Description |
|--------------|---------------|-------------|
| `BASE_URL` | `https://api.discogs.com` | Discogs API endpoint (use this value) |
| `USER_AGENT` | `YourUsername/DiscogsScript/1.0` | Identifies your app to Discogs (use your username) |
| `NOW_UK_SERIES` | `563691` | The Discogs label ID you want to query |
| `NOW_UK_WHERE_TYPE` | `master` | Filter by release type (usually "master") |
| `NOW_UK_WHERE_ROLE` | `Main` | Filter by role (usually "Main") |
| `NOW_UK_WHERE_MATCH` | `Now That's What I Call Music\s*\d+` | Regex pattern to match release titles |
| `NOW_UK_FILE_NAME` | `My_Label_Releases` | Output CSV filename (without .csv) |

#### How to Find a Label ID:
1. Go to the label's page on Discogs.com
2. Look at the URL: `https://www.discogs.com/label/XXXXXX-Label-Name`
3. The number `XXXXXX` is the label ID

#### Customizing Filters:

**WHERE_TYPE**: Common values
- `master` - Master releases (recommended)
- `release` - Individual releases

**WHERE_ROLE**: Common values
- `Main` - Main releases from the label
- `Subsidiary` - Releases from subsidiary labels

**WHERE_MATCH**: Regex pattern examples
- Match all: `.*`
- Match numbered series: `Series Name\s*\d+`
- Match specific text: `^Compilation.*`

### Step 5: Run Your First Workflow

1. Go to **Actions** tab
2. You may need to enable Actions (click **"I understand my workflows, go ahead and enable them"**)
3. Select **"Extract Discogs Releases"** from the left sidebar
4. Click **"Run workflow"** → **"Run workflow"**
5. Watch the progress in real-time
6. Once complete:
   - CSV file will be in your repository
   - Download artifact from the workflow run page

### Step 6: Customize for Your Needs

Want to track multiple labels or series? You can:

1. **Duplicate the workflow file** with different names (e.g., `discogs-extract-label2.yml`)
2. **Create different sets of variables** (e.g., `LABEL2_SERIES`, `LABEL2_FILE_NAME`)
3. **Update the workflow** to use the new variables
4. Run multiple workflows independently!

---

## 🛠️ Troubleshooting

### Workflow fails with "DISCOGS_TOKEN environment variable is required"
- ✅ Check that you created the secret named exactly `DISCOGS_TOKEN`
- ✅ Check spelling and capitalization
- ✅ Try re-creating the secret

### Workflow fails with "401 Unauthorized"
- ❌ Your Discogs token is invalid or expired
- ✅ Generate a new token on Discogs.com
- ✅ Update the `DISCOGS_TOKEN` secret in GitHub

### No releases found / Empty CSV
- Check that `NOW_UK_SERIES` (label ID) is correct
- Check that your filters (`WHERE_TYPE`, `WHERE_ROLE`, `WHERE_MATCH`) match releases
- Try setting `WHERE_MATCH` to `.*` to match all releases
- Verify the label actually has releases on Discogs.com

### Workflow times out
- Large labels may take a long time to process
- Consider filtering to a specific series using `WHERE_MATCH`
- The workflow has a 6-hour timeout by default

### Rate limiting errors
- Discogs API has rate limits (60 requests/minute for authenticated requests)
- The script respects these limits, but very large labels may take time
- Consider running less frequently (e.g., weekly instead of daily)

---

## 📊 Output Format

The generated CSV contains the following columns:

| Column | Description |
|--------|-------------|
| `Issue` | Issue/volume number extracted from title |
| `Year` | Release year |
| `Format` | Physical format (CD, Vinyl, Cassette, etc.) |
| `Version` | Version label (e.g., "CD-Remaster", "Vinyl-Original") |
| `Disc` | Disc identifier (number for CDs, letter for vinyl) |
| `TrackNumber` | Track position on the disc |
| `Title` | Track title |
| `Artist` | Track artist name |
| `DiscogsReleaseID` | Discogs release ID for reference |

---

## 🤝 Contributing

Found a bug? Have a feature request? Contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is open source and available for anyone to use and modify.

---

## 🔗 Resources

- [Discogs API Documentation](https://www.discogs.com/developers/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Cron Schedule Generator](https://crontab.guru/)

---

## ⚠️ Important Notes

- **Respect Discogs API rate limits**: Don't abuse the API
- **User-Agent is required**: Always set a descriptive User-Agent
- **Keep your token secure**: Never commit tokens to your repository
- **Check Discogs Terms of Service**: Ensure your use complies with their terms
- **Generated CSV files contain public data**: Be aware of what you commit to public repos

---

**Questions?** Open an issue in this repository!
