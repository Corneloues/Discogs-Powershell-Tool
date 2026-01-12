# Discogs PowerShell Tool

Extract detailed release and track information from Discogs and export to CSV format, powered by GitHub Actions.

## 🎵 Overview

This tool automatically queries the [Discogs API](https://www.discogs.com/developers) to extract comprehensive release information from a specific record label, including all versions, formats, and track-level details. Perfect for music cataloging, research, or building databases of compilation series.

## ✨ Features

- 🔄 **Automated Data Extraction** - Fetches all releases from a Discogs label
- 🎯 **Flexible Filtering** - Configure release type, role, and title patterns  
- 📀 **Multi-Format Support** - Handles CD, Vinyl, Cassette, and more
- 📊 **Detailed Track Data** - Extracts disc, track number, title, and artist
- ⏰ **Scheduled Execution** - Runs automatically on your chosen schedule
- 🔐 **Secure Configuration** - Uses GitHub Secrets and Variables
- 📦 **CSV Export** - Clean, sorted output committed back to your repo

## 🔧 How It Works

1. Connects to Discogs API using your authentication token
2. Fetches all releases for the configured label ID
3. Filters releases by type, role, and title pattern (regex)
4. For each matching release, retrieves all versions/editions
5. Extracts detailed track information (disc, track #, title, artist, year)
6. Exports everything to a sorted CSV file
7. Commits the CSV back to the repository
8. Uploads CSV as a downloadable artifact (30-day retention)

---

## 🚀 Setup Instructions

### Prerequisites

- A GitHub account (you have this! ✓)
- A Discogs account - [Sign up here](https://www.discogs.com/users/create)
- Basic familiarity with GitHub repository settings

---

### For Repository Owner

#### Step 1: Get Your Discogs API Token

1. Log in to [Discogs.com](https://www.discogs.com)
2. Click your username → **Settings**
3. Navigate to **Developers** section
4. Click **Generate new token**
5. Copy the token (you'll need it in the next step)
6. ⚠️ **Important:** Never commit this token to your code or share it publicly!

#### Step 2: Configure GitHub Secret

1. Go to your repository on GitHub
2. Click **Settings** tab
3. In the left sidebar: **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Create the secret:
   - **Name:** `DISCOGS_TOKEN`
   - **Value:** Paste your Discogs API token
6. Click **Add secret**

✅ Your token is now encrypted and secure!

#### Step 3: Configure GitHub Action Variables

In the same **Secrets and variables** → **Actions** section:
1. Click the **Variables** tab
2. Click **New repository variable** for each of the following:

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `BASE_URL` | `https://api.discogs.com` | Discogs API base URL (should not change) |
| `USER_AGENT` | `YourUsernameDiscogsScript/1.0` | User agent for API requests (use your Discogs username) |
| `NOW_UK_SERIES` | `563691` | The Discogs label ID you want to query |
| `NOW_UK_WHERE_TYPE` | `master` | Filter by release type (usually "master") |
| `NOW_UK_WHERE_ROLE` | `Main` | Filter by role (usually "Main") |
| `NOW_UK_WHERE_MATCH` | `Now That's What I Call Music\s*\d+` | Regex pattern to match specific titles |
| `NOW_UK_FILE_NAME` | `Now_UK_AllVersions_Tracks` | Output CSV filename (without .csv extension) |

**Finding a Label ID:**
- Go to a label page on Discogs (e.g., `https://www.discogs.com/label/563691-Now-Thats-What-I-Call-Music`)
- The number in the URL is the label ID (563691 in this example)

---

## 🎮 Running the Workflow

### Manual Execution

1. Go to the **Actions** tab in your repository
2. Select **"Extract Discogs Releases"** workflow from the left sidebar
3. Click the **Run workflow** dropdown button
4. Select branch (usually `main`)
5. (Optional) Override `label_id` or `file_name` if needed
6. Click **Run workflow**
7. Wait for completion (time varies based on data size)
8. Download CSV from:
   - **Artifacts** section of the workflow run, OR
   - Find it committed directly to your repository

### Scheduled Execution

The workflow runs automatically:
- **Default Schedule:** Every Sunday at 00:00 UTC (midnight)
- **Cron Expression:** `0 0 * * 0`

#### To Disable the Schedule

1. Edit `.github/workflows/discogs-extract.yml`
2. Comment out the `schedule` section:
   ```yaml
   # schedule:
   #   - cron: '0 0 * * 0'
   ```
3. Commit and push the change

#### To Change the Schedule

1. Edit `.github/workflows/discogs-extract.yml`
2. Modify the cron expression. Examples:
   - Daily at 2 AM UTC: `0 2 * * *`
   - Every Monday at 9 AM UTC: `0 9 * * 1`
   - First day of month: `0 0 1 * *`
3. Use [crontab.guru](https://crontab.guru/) to create custom schedules
4. Commit and push the change

---

## 👥 For Others: Fork and Use This Tool

Want to use this tool for your own Discogs data extraction? Here's how!

### 1. Fork or Clone This Repository

**Option A: Fork (Recommended)**
- Click the **Fork** button at the top right of this repository
- This creates your own copy under your GitHub account

**Option B: Clone**
```bash
git clone https://github.com/Corneloues/Discogs-Powershell-Tool.git
cd Discogs-Powershell-Tool
```

### 2. Get Your Own Discogs API Token

Follow **Step 1** from the owner setup above to generate your personal token.

### 3. Configure Your Secrets and Variables

In **your forked/cloned repository**:

1. Add the **Secret** (Settings → Secrets and variables → Actions → Secrets):
   - `DISCOGS_TOKEN` = Your personal Discogs API token

2. Add all **Variables** (Settings → Secrets and variables → Actions → Variables):
   - `BASE_URL` = `https://api.discogs.com`
   - `USER_AGENT` = `YourDiscogsUsername/1.0` (**use YOUR username**)
   - `NOW_UK_SERIES` = The label ID you want to track
   - `NOW_UK_WHERE_TYPE` = `master` (or customize)
   - `NOW_UK_WHERE_ROLE` = `Main` (or customize)
   - `NOW_UK_WHERE_MATCH` = Regex pattern for titles you want to match
   - `NOW_UK_FILE_NAME` = Desired output filename (without .csv)

### 4. Customize for Your Use Case

**Example: Tracking a Different Label Series**

Want to track "Ministry of Sound" compilations instead?
1. Find the label ID on Discogs
2. Update variables:
   - `NOW_UK_SERIES` = new label ID
   - `NOW_UK_WHERE_MATCH` = `Ministry of Sound.*\d+`
   - `NOW_UK_FILE_NAME` = `Ministry_Of_Sound_Tracks`

**Example: Multiple Labels**

Duplicate the workflow file with different names:
- `.github/workflows/label-series-1.yml`
- `.github/workflows/label-series-2.yml`

Each can use different variable names or hardcoded values.

---

## 📄 Output Format

The generated CSV contains these columns:

| Column | Description | Example |
|--------|-------------|---------|
| `Issue` | Issue/volume number extracted from title | 50 |
| `Year` | Release year | 2001 |
| `Format` | Physical format | CD, Vinyl, Cassette |
| `Version` | Version label (format + edition type) | CD-Remaster, Vinyl-Original |
| `Disc` | Disc identifier | 1, 2, A, B |
| `TrackNumber` | Track number on disc | 5, 12 |
| `Title` | Track title | "Song Name" |
| `Artist` | Track artist (if available) | "Artist Name" |
| `DiscogsReleaseID` | Unique Discogs release ID | 123456 |

---

## 🛠️ Troubleshooting

### Workflow Fails with "DISCOGS_TOKEN environment variable is required"

**Problem:** Secret not configured or misnamed

**Solution:**
- Verify secret exists: Settings → Secrets and variables → Actions → Secrets
- Ensure it's named exactly `DISCOGS_TOKEN` (case-sensitive)
- Check you're looking at the correct repository (not a fork)

### Workflow Fails with "401 Unauthorized"

**Problem:** Invalid or expired Discogs token

**Solution:**
- Generate a new token on Discogs
- Update the `DISCOGS_TOKEN` secret in GitHub
- Make sure you're using a valid Discogs account

### CSV is Empty or Missing Expected Releases

**Problem:** Filter criteria too restrictive

**Solution:**
- Check `NOW_UK_WHERE_TYPE`, `NOW_UK_WHERE_ROLE`, and `NOW_UK_WHERE_MATCH` values
- Test your regex pattern at [regex101.com](https://regex101.com/)
- Verify the label ID is correct by visiting `https://www.discogs.com/label/{ID}`

### Workflow Times Out or Takes Too Long

**Problem:** Too much data to process

**Solution:**
- GitHub Actions have a 6-hour timeout limit
- For very large datasets, consider:
  - Narrowing your `WHERE_MATCH` filter
  - Processing in batches
  - Adding pagination limits

### "Permission denied" when pushing CSV back to repo

**Problem:** Workflow lacks write permissions

**Solution:**
- Check workflow file has `permissions: contents: write`
- Verify repository Settings → Actions → General → Workflow permissions is set to "Read and write permissions"

---

## 🔐 Security and Privacy

### Is My API Token Safe?

**Yes!** Here's why:
- ✅ **GitHub Secrets are encrypted** - GitHub uses strong encryption for all secrets
- ✅ **Secrets are masked in logs** - Your token will never appear in workflow logs
- ✅ **Secrets don't transfer to forks** - Forked repos don't inherit your secrets
- ✅ **Only workflow runs can access secrets** - They're not visible in the repo files

### Who Can Run My Workflow?

**Only you** (and collaborators with write access):
- ❌ Random GitHub users **cannot** trigger your workflows
- ❌ Viewers of your public repo **cannot** access your secrets
- ✅ **Only repository owners/collaborators** can manually run workflows
- ✅ Scheduled workflows run automatically without user intervention

### Can I Keep This Repository Public?

**Yes, absolutely!** This setup is safe for public repositories:
- Your **code is public** (which is great for sharing/learning)
- Your **secrets remain private** (encrypted and inaccessible)
- Your **workflow execution is controlled** (only you can trigger it)

### Best Practices

1. **Never commit tokens to code** - Always use GitHub Secrets
2. **Rotate tokens periodically** - Generate new tokens every 6-12 months
3. **Use descriptive User-Agent** - Helps Discogs identify your requests
4. **Respect API rate limits** - Discogs has usage limits (60 requests/minute for authenticated users)
5. **Review workflow runs** - Check the Actions tab for any errors or issues

---

## 📚 Additional Resources

- [Discogs API Documentation](https://www.discogs.com/developers)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Secrets Guide](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Cron Expression Generator](https://crontab.guru/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

---

## 📝 License

This project is open source and available for anyone to use, modify, and distribute.

---

## 🤝 Contributing

Found a bug or have a feature suggestion?
- Open an issue
- Submit a pull request
- Share your use case!

---

**Happy cataloging! 🎵**
