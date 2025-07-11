#!/bin/bash

# Setup Project Backup Service
# Manages the automated project backup and git operations

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
SERVICE_NAME="com.user.project-backup"
PROJECT_BACKUP_SCRIPT="$SCRIPT_DIR/git-backup.sh"
PLIST_FILE="$SCRIPT_DIR/$SERVICE_NAME.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/$SERVICE_NAME.plist"

# Function to create the LaunchAgent plist
create_plist() {
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    
    <key>Program</key>
    <string>$PROJECT_BACKUP_SCRIPT</string>
    
    <key>StartInterval</key>
    <integer>3600</integer>
    
    <key>RunAtLoad</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>$HOME/.local/log/automation/project-backup-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$HOME/.local/log/automation/project-backup-stderr.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>UserName</key>
    <string>$(whoami)</string>
    
    <key>ThrottleInterval</key>
    <integer>300</integer>
</dict>
</plist>
EOF
}

# Function to install the service
install_service() {
    print_status "Installing project backup service..."
    
    # Create directories
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$HOME/.local/log/automation"
    mkdir -p "$HOME/.local/backup/projects"
    
    # Create plist file
    create_plist
    
    # Make script executable
    chmod +x "$PROJECT_BACKUP_SCRIPT"
    
    # Copy plist file
    cp "$PLIST_FILE" "$INSTALLED_PLIST"
    
    # Load the service
    if load_service "$INSTALLED_PLIST" "$SERVICE_NAME"; then
        print_success "Project backup service installed successfully!"
        print_status "Service will run every hour"
        print_status "Logs will be saved to: $HOME/.local/log/automation/"
        print_status "Backup reports will be saved to: $HOME/.local/backup/projects/"
    else
        print_error "Failed to install service"
        return 1
    fi
}

# Function to uninstall the service
uninstall_service() {
    print_status "Uninstalling project backup service..."
    
    if unload_service "$INSTALLED_PLIST" "$SERVICE_NAME"; then
        rm -f "$INSTALLED_PLIST"
        rm -f "$PLIST_FILE"
        print_success "Service uninstalled successfully!"
    else
        print_error "Failed to uninstall service"
        return 1
    fi
}

# Function to show service status
show_status() {
    echo "Project Backup Service Status:"
    echo "=============================="
    
    if is_service_loaded "$SERVICE_NAME"; then
        print_success "Service is RUNNING"
        echo "  - Runs every hour"
        echo "  - Script: $PROJECT_BACKUP_SCRIPT"
        echo "  - Logs: $HOME/.local/log/automation/"
        echo "  - Backup reports: $HOME/.local/backup/projects/"
        
        # Show last few log entries
        if [ -f "$HOME/.local/log/automation/automation.log" ]; then
            echo ""
            echo "Recent log entries:"
            grep "project-backup\|Project backup" "$HOME/.local/log/automation/automation.log" | tail -5
        fi
        
        # Show recent backup reports
        if [ -d "$HOME/.local/backup/projects" ]; then
            echo ""
            echo "Recent backup reports:"
            ls -lt "$HOME/.local/backup/projects"/project-report-*.md 2>/dev/null | head -3
        fi
    else
        print_warning "Service is NOT running"
    fi
}

# Function to run project backup manually
run_manual_backup() {
    print_status "Running manual project backup..."
    "$PROJECT_BACKUP_SCRIPT"
}

# Function to backup specific project
backup_specific_project() {
    local project_path="$1"
    
    if [ -z "$project_path" ]; then
        print_error "Project path required"
        return 1
    fi
    
    if [ ! -d "$project_path" ]; then
        print_error "Project path does not exist: $project_path"
        return 1
    fi
    
    print_status "Running backup for specific project: $project_path"
    "$PROJECT_BACKUP_SCRIPT" --repo "$project_path"
}

# Function to force backup all projects
force_backup_all() {
    print_status "Running force backup for all projects (including inactive)..."
    "$PROJECT_BACKUP_SCRIPT" --force
}

# Function to show help
show_help() {
    echo "Project Backup Service Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  install             - Install and start the project backup service"
    echo "  uninstall           - Stop and remove the project backup service"
    echo "  status              - Show current service status"
    echo "  run                 - Run backup manually"
    echo "  backup PATH         - Backup specific project"
    echo "  force               - Force backup all projects (including inactive)"
    echo "  logs                - Show recent logs"
    echo "  reports             - Show recent backup reports"
    echo "  config              - Show current configuration"
    echo "  help                - Show this help message"
    echo ""
    echo "The service will:"
    echo "  - Run every hour automatically"
    echo "  - Find all git repositories in ~/GitHub and ~/dotfiles"
    echo "  - Auto-commit WIP changes for active projects"
    echo "  - Create backup branches for safety"
    echo "  - Push changes to remote repositories"
    echo "  - Clean up old backup branches"
    echo "  - Generate detailed status reports"
    echo ""
    echo "Configuration:"
    echo "  - Auto-commit branches: main, master, develop, dev"
    echo "  - Maximum backup branches per repo: 10"
    echo "  - Inactive threshold: 30 days"
    echo "  - Backup frequency: Every hour"
}

# Function to show logs
show_logs() {
    if [ -f "$HOME/.local/log/automation/automation.log" ]; then
        echo "Project backup logs:"
        echo "==================="
        grep "project-backup\|Project backup" "$HOME/.local/log/automation/automation.log" | tail -20
        
        echo ""
        echo "Standard output logs:"
        echo "===================="
        if [ -f "$HOME/.local/log/automation/project-backup-stdout.log" ]; then
            tail -10 "$HOME/.local/log/automation/project-backup-stdout.log"
        else
            echo "No stdout logs found"
        fi
        
        echo ""
        echo "Error logs:"
        echo "==========="
        if [ -f "$HOME/.local/log/automation/project-backup-stderr.log" ]; then
            tail -10 "$HOME/.local/log/automation/project-backup-stderr.log"
        else
            echo "No error logs found"
        fi
    else
        print_warning "No logs found. Service may not have run yet."
    fi
}

# Function to show recent backup reports
show_reports() {
    local backup_dir="$HOME/.local/backup/projects"
    
    if [ -d "$backup_dir" ]; then
        echo "Recent backup reports:"
        echo "====================="
        
        # Show list of recent reports
        local reports=($(ls -t "$backup_dir"/project-report-*.md 2>/dev/null | head -5))
        
        if [ ${#reports[@]} -gt 0 ]; then
            for report in "${reports[@]}"; do
                local report_name=$(basename "$report")
                local report_date=$(echo "$report_name" | sed 's/project-report-\(.*\)\.md/\1/')
                echo "  - $report_name ($(date -j -f "%Y%m%d_%H%M%S" "$report_date" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$report_date"))"
            done
            
            echo ""
            echo "To view a report:"
            echo "  cat \"$backup_dir/project-report-YYYYMMDD_HHMMSS.md\""
            echo ""
            echo "Latest report preview:"
            echo "====================="
            head -20 "${reports[0]}"
        else
            echo "No backup reports found"
        fi
    else
        print_warning "Backup directory not found: $backup_dir"
    fi
}

# Function to show current configuration
show_config() {
    echo "Project Backup Configuration:"
    echo "============================"
    echo "Service Name: $SERVICE_NAME"
    echo "Backup Script: $PROJECT_BACKUP_SCRIPT"
    echo "Search Directories:"
    echo "  - $HOME/GitHub"
    echo "  - $HOME/dotfiles"
    echo "Auto-commit Branches: main, master, develop, dev"
    echo "Maximum Backup Branches: 10"
    echo "Inactive Threshold: 30 days"
    echo "Backup Frequency: Every hour (3600 seconds)"
    echo "Logs Directory: $HOME/.local/log/automation/"
    echo "Backup Reports: $HOME/.local/backup/projects/"
    echo ""
    echo "Service Status: $(is_service_loaded "$SERVICE_NAME" && echo "Running" || echo "Not Running")"
}

# Function to configure backup frequency
configure_frequency() {
    echo "Current backup frequency: Every hour (3600 seconds)"
    echo ""
    echo "To change the backup frequency, edit the plist file:"
    echo "  $PLIST_FILE"
    echo ""
    echo "Modify the StartInterval value:"
    echo "  <key>StartInterval</key>"
    echo "  <integer>3600</integer>  <!-- Change this value -->"
    echo ""
    echo "Common intervals:"
    echo "  - Every 30 minutes: 1800"
    echo "  - Every hour: 3600 (current)"
    echo "  - Every 2 hours: 7200"
    echo "  - Every 4 hours: 14400"
    echo ""
    echo "Then restart the service:"
    echo "  $0 uninstall"
    echo "  $0 install"
}

# Main script logic
case "${1:-help}" in
    install)
        if is_service_loaded "$SERVICE_NAME"; then
            print_warning "Service is already installed"
            show_status
        else
            install_service
        fi
        ;;
    uninstall)
        if is_service_loaded "$SERVICE_NAME"; then
            uninstall_service
        else
            print_warning "Service is not installed"
        fi
        ;;
    status)
        show_status
        ;;
    run)
        run_manual_backup
        ;;
    backup)
        if [ -n "$2" ]; then
            backup_specific_project "$2"
        else
            print_error "Project path required"
            echo "Usage: $0 backup /path/to/project"
            exit 1
        fi
        ;;
    force)
        force_backup_all
        ;;
    logs)
        show_logs
        ;;
    reports)
        show_reports
        ;;
    config)
        show_config
        ;;
    configure)
        configure_frequency
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
