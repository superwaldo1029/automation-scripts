#!/bin/bash

# Development Environment Synchronization Script
# Keeps development tools and configurations up-to-date

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
DOTFILES_DIR="$HOME/dotfiles"
PROJECTS_DIR="$HOME/GitHub"
BACKUP_DIR="$HOME/.local/backup/dev-sync"

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_message "INFO" "Starting development environment sync..."

# Function to sync dotfiles
sync_dotfiles() {
    print_status "Syncing dotfiles..."
    
    if [ -d "$DOTFILES_DIR" ] && is_git_repo "$DOTFILES_DIR"; then
        cd "$DOTFILES_DIR"
        
        # Check for local changes
        if has_git_changes; then
            print_warning "Dotfiles have uncommitted changes"
            git status --porcelain
            
            if confirm "Commit changes automatically?"; then
                git add .
                git commit -m "Auto-commit: dotfiles sync $(date '+%Y-%m-%d %H:%M:%S')"
            fi
        fi
        
        # Pull latest changes
        print_status "Pulling latest dotfiles..."
        git pull origin main
        
        # Check if symlinks need updating
        print_status "Checking symlinks..."
        if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
            print_warning "Found non-symlinked config files"
            # Add logic to recreate symlinks if needed
        fi
        
        log_message "INFO" "Dotfiles sync completed"
    else
        print_warning "Dotfiles directory not found or not a git repo"
        log_message "WARNING" "Dotfiles sync skipped"
    fi
}

# Function to update Homebrew
update_homebrew() {
    if has_homebrew; then
        print_status "Updating Homebrew..."
        
        # Update Homebrew
        brew update
        
        # List outdated packages
        local outdated=$(brew outdated)
        if [ -n "$outdated" ]; then
            print_status "Outdated packages:"
            echo "$outdated"
            
            if confirm "Update all packages?" "y"; then
                brew upgrade
            fi
        else
            print_success "All Homebrew packages are up-to-date"
        fi
        
        # Clean up old versions
        print_status "Cleaning up old versions..."
        brew cleanup
        
        log_message "INFO" "Homebrew update completed"
    else
        print_warning "Homebrew not found"
        log_message "WARNING" "Homebrew update skipped"
    fi
}

# Function to update npm global packages
update_npm_globals() {
    if has_npm; then
        print_status "Updating npm global packages..."
        
        # Check for outdated packages
        local outdated=$(npm outdated -g 2>/dev/null)
        if [ -n "$outdated" ]; then
            print_status "Outdated npm packages:"
            echo "$outdated"
            
            if confirm "Update all global packages?" "y"; then
                npm update -g
            fi
        else
            print_success "All npm global packages are up-to-date"
        fi
        
        log_message "INFO" "npm global packages update completed"
    else
        print_warning "npm not found"
        log_message "WARNING" "npm update skipped"
    fi
}

# Function to update Ruby gems
update_ruby_gems() {
    if has_rbenv; then
        print_status "Updating Ruby gems..."
        
        # Get current Ruby version
        local ruby_version=$(rbenv version | cut -d' ' -f1)
        print_status "Current Ruby version: $ruby_version"
        
        # Update gems
        if confirm "Update Ruby gems?"; then
            gem update --system
            gem update
            
            # Clean up old versions
            gem cleanup
        fi
        
        log_message "INFO" "Ruby gems update completed"
    else
        print_warning "rbenv not found"
        log_message "WARNING" "Ruby gems update skipped"
    fi
}

# Function to update oh-my-zsh
update_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "Updating oh-my-zsh..."
        
        # Update oh-my-zsh
        cd "$HOME/.oh-my-zsh"
        git pull origin master
        
        # Update powerlevel10k theme if present
        if [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
            print_status "Updating Powerlevel10k theme..."
            cd "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
            git pull origin master
        fi
        
        log_message "INFO" "oh-my-zsh update completed"
    else
        print_warning "oh-my-zsh not found"
        log_message "WARNING" "oh-my-zsh update skipped"
    fi
}

# Function to sync VS Code extensions
sync_vscode_extensions() {
    if command_exists code; then
        print_status "Syncing VS Code extensions..."
        
        # Export current extensions
        local extensions_file="$BACKUP_DIR/vscode-extensions-$(date +%Y%m%d).txt"
        code --list-extensions > "$extensions_file"
        
        print_status "VS Code extensions backed up to: $extensions_file"
        
        # If dotfiles has an extensions list, sync it
        if [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
            print_status "Installing missing VS Code extensions..."
            while IFS= read -r extension; do
                if ! code --list-extensions | grep -q "^$extension$"; then
                    print_status "Installing: $extension"
                    code --install-extension "$extension"
                fi
            done < "$DOTFILES_DIR/vscode/extensions.txt"
        fi
        
        log_message "INFO" "VS Code extensions sync completed"
    else
        print_warning "VS Code CLI not found"
        log_message "WARNING" "VS Code extensions sync skipped"
    fi
}

# Function to sync Cursor extensions
sync_cursor_extensions() {
    if command_exists cursor; then
        print_status "Syncing Cursor extensions..."
        
        # Export current extensions
        local extensions_file="$BACKUP_DIR/cursor-extensions-$(date +%Y%m%d).txt"
        cursor --list-extensions > "$extensions_file"
        
        print_status "Cursor extensions backed up to: $extensions_file"
        
        log_message "INFO" "Cursor extensions sync completed"
    else
        print_warning "Cursor CLI not found"
        log_message "WARNING" "Cursor extensions sync skipped"
    fi
}

# Function to check GitHub CLI authentication
check_github_auth() {
    if command_exists gh; then
        print_status "Checking GitHub CLI authentication..."
        
        if gh auth status >/dev/null 2>&1; then
            print_success "GitHub CLI is authenticated"
        else
            print_warning "GitHub CLI is not authenticated"
            if confirm "Authenticate with GitHub now?"; then
                gh auth login
            fi
        fi
        
        log_message "INFO" "GitHub CLI auth check completed"
    else
        print_warning "GitHub CLI not found"
        log_message "WARNING" "GitHub CLI auth check skipped"
    fi
}

# Function to update development tools
update_dev_tools() {
    print_status "Checking for development tool updates..."
    
    # Check for macOS updates
    if is_macos; then
        print_status "Checking for macOS updates..."
        local updates=$(softwareupdate -l 2>/dev/null | grep -i "recommended")
        if [ -n "$updates" ]; then
            print_warning "macOS updates available:"
            echo "$updates"
            print_status "Run 'softwareupdate -i -a' to install updates"
        else
            print_success "macOS is up-to-date"
        fi
    fi
    
    # Check for Xcode command line tools
    if ! xcode-select -p >/dev/null 2>&1; then
        print_warning "Xcode command line tools not found"
        if confirm "Install Xcode command line tools?"; then
            xcode-select --install
        fi
    fi
    
    log_message "INFO" "Development tools check completed"
}

# Function to generate sync report
generate_sync_report() {
    local report_file="$BACKUP_DIR/sync-report-$(date +%Y%m%d_%H%M%S).md"
    
    print_status "Generating sync report..."
    
    cat > "$report_file" << EOF
# Development Environment Sync Report
Generated: $(date)

## System Information
- OS: $(get_system_info)
- Available Space: $(get_available_space)GB

## Tool Versions
- Homebrew: $(brew --version 2>/dev/null | head -1 || echo "Not installed")
- Node.js: $(node --version 2>/dev/null || echo "Not installed")
- npm: $(npm --version 2>/dev/null || echo "Not installed")
- Ruby: $(ruby --version 2>/dev/null || echo "Not installed")
- rbenv: $(rbenv --version 2>/dev/null || echo "Not installed")
- Git: $(git --version 2>/dev/null || echo "Not installed")
- GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo "Not installed")

## Dotfiles Status
- Directory: $DOTFILES_DIR
- Git Status: $(cd "$DOTFILES_DIR" 2>/dev/null && git status --porcelain | wc -l || echo "N/A") uncommitted changes
- Last Commit: $(cd "$DOTFILES_DIR" 2>/dev/null && git log -1 --format="%h %s" || echo "N/A")

## Package Counts
- Homebrew Packages: $(brew list 2>/dev/null | wc -l || echo "N/A")
- npm Global Packages: $(npm list -g --depth=0 2>/dev/null | grep -v "npm@" | wc -l || echo "N/A")
- Ruby Gems: $(gem list 2>/dev/null | wc -l || echo "N/A")
- VS Code Extensions: $(code --list-extensions 2>/dev/null | wc -l || echo "N/A")

## Notes
- Sync completed successfully
- All backups stored in: $BACKUP_DIR

EOF

    print_success "Sync report generated: $report_file"
    log_message "INFO" "Sync report generated"
}

# Main execution
main() {
    print_status "Development Environment Sync starting..."
    
    # Check prerequisites
    if ! check_internet; then
        print_error "No internet connection available"
        exit 1
    fi
    
    # Perform sync operations
    sync_dotfiles
    update_homebrew
    update_npm_globals
    update_ruby_gems
    update_oh_my_zsh
    sync_vscode_extensions
    sync_cursor_extensions
    check_github_auth
    update_dev_tools
    
    # Generate report
    generate_sync_report
    
    print_success "Development environment sync completed!"
    send_notification "Dev Sync" "Development environment sync completed successfully"
    
    log_message "INFO" "Development environment sync completed successfully"
}

# Run main function
main "$@"
