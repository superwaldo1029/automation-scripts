#!/bin/bash

# Auto Cleanup Script
# Safely empties trash and cleans up system caches
# Created: $(date)

# Set up logging
LOG_FILE="$HOME/.local/log/auto-cleanup.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to get size in human readable format
get_size() {
    if [ -d "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

log_message "Starting auto-cleanup..."

# 1. Empty Trash
TRASH_SIZE=$(get_size "$HOME/.Trash")
if [ "$TRASH_SIZE" != "0B" ]; then
    log_message "Emptying trash (was $TRASH_SIZE)..."
    rm -rf "$HOME/.Trash/"* 2>/dev/null
    log_message "Trash emptied successfully"
else
    log_message "Trash is already empty"
fi

# 2. Clean Homebrew cache (if available)
if command -v brew >/dev/null 2>&1; then
    log_message "Cleaning Homebrew cache..."
    brew cleanup --prune=7 >/dev/null 2>&1
    log_message "Homebrew cache cleaned"
fi

# 3. Clean npm cache (if available and large)
if command -v npm >/dev/null 2>&1; then
    NPM_CACHE_SIZE=$(get_size "$HOME/.npm")
    # Only clean if cache is larger than 500MB
    if [ -d "$HOME/.npm" ] && [ $(du -s "$HOME/.npm" 2>/dev/null | cut -f1) -gt 500000 ]; then
        log_message "Cleaning large npm cache (was $NPM_CACHE_SIZE)..."
        npm cache clean --force >/dev/null 2>&1
        log_message "npm cache cleaned"
    fi
fi

# 4. Clean Python pip cache (if available)
if [ -d "$HOME/Library/Caches/pip" ]; then
    PIP_CACHE_SIZE=$(get_size "$HOME/Library/Caches/pip")
    if [ "$PIP_CACHE_SIZE" != "0B" ]; then
        log_message "Cleaning pip cache (was $PIP_CACHE_SIZE)..."
        rm -rf "$HOME/Library/Caches/pip"/* 2>/dev/null
        log_message "pip cache cleaned"
    fi
fi

# 5. Clean Microsoft Office logs (if they exist and are large)
OFFICE_LOGS_DIR="$HOME/Library/Containers/com.microsoft.*/Data/Library/Logs/Diagnostics"
if ls $OFFICE_LOGS_DIR/*/*.log >/dev/null 2>&1; then
    # Find logs older than 7 days
    OFFICE_LOGS=$(find $OFFICE_LOGS_DIR -name "*.log" -mtime +7 2>/dev/null)
    if [ -n "$OFFICE_LOGS" ]; then
        log_message "Cleaning old Microsoft Office logs (>7 days)..."
        find $OFFICE_LOGS_DIR -name "*.log" -mtime +7 -delete 2>/dev/null
        log_message "Office logs cleaned"
    fi
fi

# 6. Clean system caches (conservative)
if [ -d "$HOME/Library/Caches" ]; then
    log_message "Cleaning selected system caches..."
    # Only clean safe, regenerable caches
    rm -rf "$HOME/Library/Caches/com.apple.Safari/WebKitCache" 2>/dev/null
    rm -rf "$HOME/Library/Caches/CloudKit" 2>/dev/null
    log_message "System caches cleaned"
fi

# 7. Update locate database (if available)
if command -v updatedb >/dev/null 2>&1; then
    log_message "Updating locate database..."
    updatedb >/dev/null 2>&1
fi

log_message "Auto-cleanup completed successfully"
log_message "==========================================="
