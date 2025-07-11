# Project Backup & Git Automation

Automated backup system for git repositories with intelligent project management and safety features.

## Features

### 🔄 Automatic Git Operations
- **Auto-commit WIP changes** for active projects
- **Create backup branches** for safety
- **Push to remote repositories** automatically
- **Clean up old backup branches** (keep latest 10)
- **Stash uncommitted changes** when needed

### 📊 Intelligent Project Management
- **Detect inactive projects** (>30 days without changes)
- **Skip inactive projects** to avoid unnecessary commits
- **Force backup mode** for all projects when needed
- **Per-project backup** for specific repositories

### 📈 Comprehensive Reporting
- **Detailed status reports** with project statistics
- **JSON status tracking** for each repository
- **Visual status indicators** (✅ 🔄 📤 😴)
- **Backup operation logs** and history

### 🛡️ Safety Features
- **Backup branches** preserve work before operations
- **Configurable branch restrictions** (only main/master/develop/dev)
- **Throttling** to prevent excessive operations
- **Comprehensive logging** of all actions

## Installation

```bash
# Install the service (runs every hour)
./setup-project-backup.sh install

# Check service status
./setup-project-backup.sh status

# View configuration
./setup-project-backup.sh config
```

## Usage

### Basic Commands

```bash
# Run backup manually
./setup-project-backup.sh run

# Backup specific project
./setup-project-backup.sh backup /path/to/project

# Force backup all projects (including inactive)
./setup-project-backup.sh force

# View recent logs
./setup-project-backup.sh logs

# View backup reports
./setup-project-backup.sh reports
```

### Direct Script Usage

```bash
# Run with options
./git-backup.sh --force          # Include inactive projects
./git-backup.sh --repo /path     # Backup specific repository
./git-backup.sh --help           # Show help
```

## Configuration

### Default Settings
- **Search Directories**: `~/GitHub`, `~/dotfiles`
- **Auto-commit Branches**: `main`, `master`, `develop`, `dev`
- **Maximum Backup Branches**: 10 per repository
- **Inactive Threshold**: 30 days
- **Backup Frequency**: Every hour (3600 seconds)

### Customization

Edit the script variables or plist file to customize:

```bash
# Edit backup frequency
./setup-project-backup.sh configure

# View current settings
./setup-project-backup.sh config
```

## How It Works

### 1. Repository Discovery
- Scans `~/GitHub` and `~/dotfiles` for git repositories
- Identifies active vs inactive projects
- Gathers repository status information

### 2. Backup Operations
For each active repository:
1. **Check Status**: Get current branch, changes, commits ahead/behind
2. **Auto-commit**: Commit WIP changes with descriptive message
3. **Create Backup**: Create timestamped backup branch
4. **Push Changes**: Push to remote repository
5. **Cleanup**: Remove old backup branches

### 3. Reporting
- Generate detailed markdown reports
- Track statistics across all repositories
- Log all operations with timestamps

## Status Indicators

| Icon | Status | Description |
|------|--------|-------------|
| ✅ | Up to date | No changes, synced with remote |
| 🔄 | Has changes | Uncommitted changes detected |
| 📤 | Needs push | Commits ahead of remote |
| 😴 | Inactive | No changes for >30 days |

## Safety Features

### Backup Branches
- Created before any destructive operations
- Named with timestamp: `backup/YYYYMMDD_HHMMSS_branchname`
- Automatically cleaned up (keep latest 10)

### Branch Restrictions
- WIP commits only on main branches: `main`, `master`, `develop`, `dev`
- Feature branches are left untouched
- Prevents accidental commits on experimental branches

### Throttling
- 5-minute minimum between service runs
- Prevents excessive operations
- Respects git repository locks

## Logs and Reports

### Log Files
- `~/.local/log/automation/automation.log` - Main log
- `~/.local/log/automation/project-backup-stdout.log` - Standard output
- `~/.local/log/automation/project-backup-stderr.log` - Error output

### Backup Reports
- `~/.local/backup/projects/project-report-YYYYMMDD_HHMMSS.md`
- Detailed status for each repository
- Statistics and operation summary
- Generated after each backup run

### JSON Status Files
- `~/.local/backup/projects/repo-status-YYYYMMDD_HHMMSS.json`
- Machine-readable repository status
- Useful for integration with other tools

## Troubleshooting

### Service Won't Start
```bash
# Check service status
./setup-project-backup.sh status

# View logs
./setup-project-backup.sh logs

# Reinstall service
./setup-project-backup.sh uninstall
./setup-project-backup.sh install
```

### Push Authentication Issues
- Ensure GitHub CLI is authenticated: `gh auth status`
- Check SSH keys are properly configured
- Verify remote URLs are correct

### Permission Issues
```bash
# Make scripts executable
chmod +x git-backup.sh setup-project-backup.sh

# Check log file permissions
ls -la ~/.local/log/automation/
```

### No Repositories Found
- Verify `~/GitHub` and `~/dotfiles` directories exist
- Check if directories contain git repositories
- Use `--force` flag to include inactive repositories

## Advanced Usage

### Custom Search Directories
Edit the script to add more search directories:

```bash
# In git-backup.sh
PROJECTS_DIR="$HOME/GitHub"
WORK_DIR="$HOME/Work"      # Add custom directory
```

### Integration with Other Tools
- Use JSON status files for external monitoring
- Parse markdown reports for dashboard integration
- Combine with notification systems

### Selective Backup
```bash
# Backup only specific projects
./setup-project-backup.sh backup ~/GitHub/important-project

# Use with cron for custom scheduling
0 */2 * * * /path/to/git-backup.sh --force
```

## Security Considerations

- WIP commits are clearly marked as automated
- Backup branches are temporary and cleaned up
- No sensitive data is logged
- Respects existing git configurations
- Only operates on repositories you own

## Performance

- Minimal impact on system resources
- Efficient git operations
- Skips inactive projects by default
- Configurable throttling and frequency
