# Project Backup & Git Automation with Security Scanning

Comprehensive automated backup system for git repositories with intelligent project management, safety features, and advanced security scanning capabilities.

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

### 🛡️ Advanced Security Scanning
- **Secrets detection** in code and git history (API keys, tokens, credentials)
- **File permission analysis** (world-writable files, suspicious executables)
- **Dependency vulnerability scanning** (npm, pip, bundle)
- **File integrity monitoring** with SHA256 checksums
- **Comprehensive security reporting** with remediation recommendations
- **Quarantine system** for suspicious files
- **Pattern-based detection** for 15+ secret types including AWS keys, GitHub tokens, SSH keys

### 📈 Comprehensive Reporting
- **Detailed status reports** with project statistics
- **Security scan reports** with visual indicators (✅ ⚠️ ℹ️)
- **JSON status tracking** for each repository
- **Visual status indicators** (✅ 🔄 📤 😴)
- **Backup operation logs** and security audit trails

### 🛡️ Safety Features
- **Backup branches** preserve work before operations
- **Configurable branch restrictions** (only main/master/develop/dev)
- **Throttling** to prevent excessive operations
- **Comprehensive logging** of all actions
- **File integrity verification** between scans

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

### Security Commands

```bash
# Run comprehensive security scan
./setup-project-backup.sh security

# Run encrypted backup
./setup-project-backup.sh encrypt

# Check security scan status
./setup-project-backup.sh security-status

# Scan specific repository for secrets
./security-scanner.sh --repo /path/to/repo

# Scan all repositories for secrets only
./security-scanner.sh --secrets

# Check file integrity for all repositories
./security-scanner.sh --integrity
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

## Security Scanning

### Overview
The security scanner performs comprehensive analysis of your repositories to detect potential security risks, secrets, and vulnerabilities.

### Security Report Format
The scanner generates detailed markdown reports with the following indicators:

| Repository | Secrets | File Security | Dependencies | Integrity |
|------------|---------|---------------|--------------|-----------|
| project-name | ⚠️ | ✅ | ✅ | ℹ️ |

**Legend:**
- ✅ **No issues detected**
- ⚠️ **Issues found** - requires attention  
- ℹ️ **Changes detected** (informational)

### Security Features

#### 🔍 Secrets Detection
Scans for over 15 types of secrets and credentials:
- **API Keys**: Generic API keys, access tokens, secret keys
- **AWS Credentials**: Access keys, secret access keys
- **GitHub Tokens**: Personal access tokens (ghp_, gho_, ghu_, ghs_, ghr_)
- **SSH Keys**: Private keys (RSA, DSA, EC, PGP, OpenSSH)
- **Database URLs**: MySQL, PostgreSQL, MongoDB connection strings
- **JWT Tokens**: JSON Web Tokens
- **Environment Variables**: Secrets in env files
- **Password Patterns**: Hardcoded passwords in configuration

#### 📁 File Security Analysis
- **Permission Checks**: World-writable files detection
- **Executable Analysis**: Suspicious executable permissions on text files
- **Hidden Credential Files**: Detection of .env, .key, .pem files
- **Large Binary Files**: Identification of potentially problematic large files

#### 📦 Dependency Vulnerability Scanning
- **Node.js**: npm audit integration for package.json
- **Python**: Known vulnerable package detection in requirements.txt
- **Ruby**: Bundle audit integration for Gemfile
- **Version Analysis**: Checks against known vulnerable versions

#### 🔒 File Integrity Monitoring
- **SHA256 Checksums**: Creates fingerprints for all repository files
- **Change Detection**: Monitors file modifications between scans
- **New File Alerts**: Identifies newly added files
- **Deletion Tracking**: Reports on removed files

### Security Logs and Reports

#### Security Reports
- `~/.local/backup/security/security-report-YYYYMMDD_HHMMSS.md`
- Executive summary with statistics
- Per-repository security status
- Detailed remediation recommendations
- Security best practices guidelines

#### Security Logs
- `~/.local/log/automation/security.log`
- Timestamped security events
- Detailed findings for each scan
- File integrity verification results

#### File Integrity Checksums
- `~/.local/backup/security/{repo-name}-checksums.sha256`
- SHA256 hashes for all tracked files
- Used for integrity verification
- Updated after each scan

### Quarantine System
Suspicious files can be automatically quarantined:
- Files moved to `~/.local/quarantine/YYYYMMDD_HHMMSS/`
- Reason for quarantine documented
- Original files preserved for analysis
- Manual review and restoration possible

### Security Best Practices
The scanner provides recommendations for:

1. **Secret Management**:
   - Rotate exposed credentials immediately
   - Use environment variables or secure vaults
   - Remove secrets from git history with BFG Repo-Cleaner
   - Add secrets to .gitignore

2. **File Security**:
   - Fix world-writable file permissions
   - Review executable permissions on text files
   - Move credential files outside repositories
   - Use .gitignore for sensitive patterns

3. **Dependency Security**:
   - Update vulnerable dependencies
   - Review security advisories
   - Implement dependency scanning in CI/CD
   - Regular security updates

### Testing Results
✅ **System Successfully Tested** (July 11, 2025)
- **5 repositories scanned** (DRscript, RSS_grabber, School_Work, config_files, dotfiles)
- **Potential secrets detected** in all repositories (requires review)
- **1 repository** with file security issues (DRscript)
- **0 dependency vulnerabilities** found
- **File integrity baselines** established for all repositories
- **Security service** running automatically every hour

## Security Considerations

- WIP commits are clearly marked as automated
- Backup branches are temporary and cleaned up
- Security scan data is stored locally and not transmitted
- File integrity monitoring preserves evidence of tampering
- Respects existing git configurations
- Only operates on repositories you own
- Secrets are detected but never logged in plain text

## Performance

- Minimal impact on system resources
- Efficient git operations
- Skips inactive projects by default
- Configurable throttling and frequency
- Security scans run in parallel with backups
- Incremental integrity checking
