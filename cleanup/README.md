# Automated Cleanup System

This directory contains scripts for automated system maintenance and cleanup.

## Files

- `auto-cleanup.sh` - Main cleanup script that runs automatically
- `setup-auto-cleanup.sh` - Management script for the service
- `com.user.auto-cleanup.plist` - macOS LaunchAgent configuration
- `README.md` - This documentation

## Features

The automated cleanup system will:

- **Empty Trash** - Clears trash every 8 hours
- **Clean Homebrew Cache** - Removes old Homebrew downloads
- **Clean npm Cache** - Removes npm cache if larger than 500MB
- **Clean pip Cache** - Removes Python package cache
- **Clean Microsoft Office Logs** - Removes logs older than 7 days
- **Clean System Caches** - Removes safe, regenerable caches

## Usage

### Install the Service
```bash
./setup-auto-cleanup.sh install
```

### Check Service Status
```bash
./setup-auto-cleanup.sh status
```

### Run Cleanup Manually
```bash
./setup-auto-cleanup.sh run
```

### View Logs
```bash
./setup-auto-cleanup.sh logs
```

### Uninstall the Service
```bash
./setup-auto-cleanup.sh uninstall
```

## Configuration

The service is configured to run every 8 hours (28,800 seconds). To change the interval:

1. Edit `com.user.auto-cleanup.plist`
2. Change the `StartInterval` value:
   - Every 4 hours: `14400`
   - Every 8 hours: `28800` (current)
   - Every 12 hours: `43200`
   - Every 24 hours: `86400`
3. Reinstall the service

## Logs

Logs are stored in `~/.local/log/`:
- `auto-cleanup.log` - Main cleanup log
- `auto-cleanup-stdout.log` - Standard output
- `auto-cleanup-stderr.log` - Error output

## Safety

The cleanup script is designed to be safe and conservative:

- Only removes regenerable caches
- Preserves important data
- Logs all actions
- Uses safe deletion methods
- Includes size checks before cleaning large caches

## Troubleshooting

### Service Won't Start
```bash
# Check for syntax errors
launchctl load -w ~/Library/LaunchAgents/com.user.auto-cleanup.plist

# Check system logs
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h
```

### Permission Issues
```bash
# Make scripts executable
chmod +x auto-cleanup.sh setup-auto-cleanup.sh

# Check file ownership
ls -la ~/Library/LaunchAgents/com.user.auto-cleanup.plist
```

### Manual Testing
```bash
# Test the cleanup script directly
./auto-cleanup.sh

# Check the logs
tail -f ~/.local/log/auto-cleanup.log
```

## Customization

To customize what gets cleaned:

1. Edit `auto-cleanup.sh`
2. Comment out sections you don't want
3. Add new cleanup tasks following the existing pattern
4. Restart the service:
   ```bash
   ./setup-auto-cleanup.sh uninstall
   ./setup-auto-cleanup.sh install
   ```

## Security

The service runs as your user account and:
- Only accesses files you own
- Uses standard system paths
- Doesn't require administrator privileges
- Follows macOS security guidelines
