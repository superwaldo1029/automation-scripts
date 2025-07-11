# Personal Automation Scripts

A collection of automation scripts for macOS development environment management, system maintenance, and workflow optimization.

## 📁 Directory Structure

```
automation-scripts/
├── cleanup/              # System cleanup and maintenance
├── dev-sync/            # Development environment synchronization
├── project-backup/      # Project backup and git automation
├── workflow-optimizer/  # Daily workflow optimization
├── file-organizer/      # File organization and management
├── utils/               # Shared utilities and helpers
└── README.md           # This file
```

## 🤖 Available Automation Scripts

### 1. System Cleanup (`cleanup/`)
- **auto-cleanup.sh** - Automated system maintenance every 8 hours
- **setup-auto-cleanup.sh** - Service management for auto-cleanup
- Features: Empty trash, clean caches, remove old logs

### 2. Development Environment Sync (`dev-sync/`)
- **dev-sync.sh** - Synchronize development tools and configurations
- **update-tools.sh** - Update Homebrew, npm, Ruby gems, etc.
- Features: Keep development environment up-to-date

### 3. Project Backup (`project-backup/`)
- **git-backup.sh** - Automated git operations for projects
- **project-status.sh** - Generate project status reports
- Features: Auto-commit WIP, backup branches, cleanup

### 4. Workflow Optimizer (`workflow-optimizer/`)
- **daily-setup.sh** - Daily development environment preparation
- **app-preloader.sh** - Pre-warm commonly used applications
- Features: Optimize daily development workflow

### 5. File Organizer (`file-organizer/`)
- **smart-organize.sh** - Intelligent file organization
- **download-organizer.sh** - Auto-organize downloads by type/project
- Features: Extend Maid functionality, organize by patterns

### 6. Utilities (`utils/`)
- **common.sh** - Shared functions and utilities
- **logger.sh** - Logging utilities
- **config.sh** - Configuration management

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone [repository-url] ~/automation-scripts
   cd ~/automation-scripts
   ```

2. **Make scripts executable:**
   ```bash
   find . -name "*.sh" -exec chmod +x {} \;
   ```

3. **Install desired automation:**
   ```bash
   # System cleanup (runs every 8 hours)
   ./cleanup/setup-auto-cleanup.sh install
   
   # Development environment sync (daily)
   ./dev-sync/setup-dev-sync.sh install
   
   # Project backup (hourly for active projects)
   ./project-backup/setup-project-backup.sh install
   ```

## ⚙️ Configuration

Each automation script includes:
- Configuration files for customization
- Installation/uninstallation scripts
- Logging and error handling
- macOS LaunchAgent integration
- Comprehensive documentation

## 🔧 Requirements

- macOS 10.14 or later
- Homebrew (for development tools)
- Git (for project management)
- Node.js/npm (for development sync)
- Ruby/rbenv (for Ruby development)

## 📊 Benefits

- **Time Savings**: Automate repetitive tasks
- **Consistency**: Standardized environment management
- **Reliability**: Automated backups and maintenance
- **Organization**: Systematic file and project management
- **Efficiency**: Optimized daily workflows

## 🛡️ Safety

All scripts are designed with safety in mind:
- Non-destructive operations by default
- Comprehensive logging
- Easy rollback capabilities
- User confirmation for destructive operations
- Backup creation before major changes

## 📝 Contributing

This is a personal automation repository, but the scripts can be adapted for other environments. Each script includes detailed documentation and configuration options.

## 🔗 Integration

These scripts integrate with:
- **Dotfiles**: Configuration management
- **Homebrew**: Package management
- **Git**: Version control and project management
- **macOS**: Native scheduling and notifications
- **Development Tools**: IDE and editor synchronization

---

*Last updated: $(date)*
