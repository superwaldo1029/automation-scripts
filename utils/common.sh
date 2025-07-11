#!/bin/bash

# Common Utilities for Automation Scripts
# Shared functions used across all automation scripts

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# Logging configuration
export LOG_DIR="$HOME/.local/log/automation"
export LOG_FILE="$LOG_DIR/automation.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Function to log messages with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get size in human readable format
get_size() {
    if [ -d "$1" ] || [ -f "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Function to check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Function to check if Homebrew is installed
has_homebrew() {
    command_exists brew
}

# Function to check if npm is installed
has_npm() {
    command_exists npm
}

# Function to check if rbenv is installed
has_rbenv() {
    command_exists rbenv
}

# Function to check if git is installed
has_git() {
    command_exists git
}

# Function to prompt for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " yn
            yn=${yn:-y}
        else
            read -p "$prompt [y/N]: " yn
            yn=${yn:-n}
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to check if service is loaded
is_service_loaded() {
    local service_name="$1"
    launchctl list | grep -q "$service_name"
}

# Function to load a LaunchAgent
load_service() {
    local plist_path="$1"
    local service_name="$2"
    
    if ! is_service_loaded "$service_name"; then
        launchctl load "$plist_path"
        if is_service_loaded "$service_name"; then
            print_success "Service '$service_name' loaded successfully"
            return 0
        else
            print_error "Failed to load service '$service_name'"
            return 1
        fi
    else
        print_warning "Service '$service_name' is already loaded"
        return 0
    fi
}

# Function to unload a LaunchAgent
unload_service() {
    local plist_path="$1"
    local service_name="$2"
    
    if is_service_loaded "$service_name"; then
        launchctl unload "$plist_path"
        if ! is_service_loaded "$service_name"; then
            print_success "Service '$service_name' unloaded successfully"
            return 0
        else
            print_error "Failed to unload service '$service_name'"
            return 1
        fi
    else
        print_warning "Service '$service_name' is not loaded"
        return 0
    fi
}

# Function to backup a file
backup_file() {
    local file_path="$1"
    local backup_dir="$HOME/.local/backup/automation"
    local backup_path="$backup_dir/$(basename "$file_path").backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file_path" ]; then
        mkdir -p "$backup_dir"
        cp "$file_path" "$backup_path"
        print_debug "Backed up '$file_path' to '$backup_path'"
        return 0
    else
        print_warning "File '$file_path' does not exist, skipping backup"
        return 1
    fi
}

# Function to check internet connectivity
check_internet() {
    if ping -c 1 google.com >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to send macOS notification
send_notification() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"
    
    if is_macos; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    fi
}

# Function to check available disk space (in GB)
get_available_space() {
    local path="${1:-/}"
    df -g "$path" | tail -1 | awk '{print $4}'
}

# Function to check if we have enough disk space
check_disk_space() {
    local required_gb="$1"
    local available_gb=$(get_available_space)
    
    if [[ "$available_gb" -lt "$required_gb" ]]; then
        print_warning "Low disk space: ${available_gb}GB available, ${required_gb}GB required"
        return 1
    else
        return 0
    fi
}

# Function to create a symbolic link safely
create_symlink() {
    local source="$1"
    local target="$2"
    
    # Check if source exists
    if [ ! -e "$source" ]; then
        print_error "Source file '$source' does not exist"
        return 1
    fi
    
    # If target exists and is not a symlink, back it up
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        backup_file "$target"
        rm -f "$target"
    fi
    
    # Create the symlink
    ln -sf "$source" "$target"
    print_debug "Created symlink: '$target' -> '$source'"
}

# Function to check if a directory is a git repository
is_git_repo() {
    local dir="${1:-.}"
    [ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
}

# Function to get git branch name
get_git_branch() {
    local dir="${1:-.}"
    if is_git_repo "$dir"; then
        git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null
    fi
}

# Function to check if git repo has uncommitted changes
has_git_changes() {
    local dir="${1:-.}"
    if is_git_repo "$dir"; then
        ! git -C "$dir" diff --quiet 2>/dev/null || ! git -C "$dir" diff --cached --quiet 2>/dev/null
    else
        return 1
    fi
}

# Function to safely remove files older than X days
cleanup_old_files() {
    local directory="$1"
    local days="$2"
    local pattern="${3:-*}"
    
    if [ -d "$directory" ]; then
        local count=$(find "$directory" -name "$pattern" -type f -mtime +$days 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            print_debug "Removing $count files older than $days days from $directory"
            find "$directory" -name "$pattern" -type f -mtime +$days -delete 2>/dev/null
            return 0
        else
            print_debug "No files older than $days days found in $directory"
            return 1
        fi
    else
        print_warning "Directory '$directory' does not exist"
        return 1
    fi
}

# Function to get system information
get_system_info() {
    if is_macos; then
        echo "macOS $(sw_vers -productVersion)"
    else
        echo "Unknown OS"
    fi
}

# Initialize logging
log_message "INFO" "Common utilities loaded - $(get_system_info)"
