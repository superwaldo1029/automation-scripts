#!/bin/bash

# Setup Development Environment Sync Service
# Manages the automated development environment synchronization

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
SERVICE_NAME="com.user.dev-sync"
DEV_SYNC_SCRIPT="$SCRIPT_DIR/dev-sync.sh"
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
    <string>$DEV_SYNC_SCRIPT</string>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    
    <key>RunAtLoad</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>$HOME/.local/log/automation/dev-sync-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$HOME/.local/log/automation/dev-sync-stderr.log</string>
    
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
</dict>
</plist>
EOF
}

# Function to install the service
install_service() {
    print_status "Installing dev-sync service..."
    
    # Create directories
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$HOME/.local/log/automation"
    
    # Create plist file
    create_plist
    
    # Make script executable
    chmod +x "$DEV_SYNC_SCRIPT"
    
    # Copy plist file
    cp "$PLIST_FILE" "$INSTALLED_PLIST"
    
    # Load the service
    if load_service "$INSTALLED_PLIST" "$SERVICE_NAME"; then
        print_success "Dev-sync service installed successfully!"
        print_status "Service will run daily at 9:00 AM"
        print_status "Logs will be saved to: $HOME/.local/log/automation/"
    else
        print_error "Failed to install service"
        return 1
    fi
}

# Function to uninstall the service
uninstall_service() {
    print_status "Uninstalling dev-sync service..."
    
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
    echo "Development Environment Sync Service Status:"
    echo "==========================================="
    
    if is_service_loaded "$SERVICE_NAME"; then
        print_success "Service is RUNNING"
        echo "  - Runs daily at 9:00 AM"
        echo "  - Script: $DEV_SYNC_SCRIPT"
        echo "  - Logs: $HOME/.local/log/automation/"
        
        # Show last few log entries
        if [ -f "$HOME/.local/log/automation/automation.log" ]; then
            echo ""
            echo "Recent log entries:"
            grep "dev-sync" "$HOME/.local/log/automation/automation.log" | tail -5
        fi
    else
        print_warning "Service is NOT running"
    fi
}

# Function to run dev-sync manually
run_manual_sync() {
    print_status "Running manual development environment sync..."
    "$DEV_SYNC_SCRIPT"
}

# Function to show help
show_help() {
    echo "Development Environment Sync Service Manager"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install   - Install and start the dev-sync service"
    echo "  uninstall - Stop and remove the dev-sync service"
    echo "  status    - Show current service status"
    echo "  run       - Run sync manually"
    echo "  logs      - Show recent logs"
    echo "  help      - Show this help message"
    echo ""
    echo "The service will:"
    echo "  - Run daily at 9:00 AM"
    echo "  - Sync dotfiles from git repository"
    echo "  - Update Homebrew packages"
    echo "  - Update npm global packages"
    echo "  - Update Ruby gems"
    echo "  - Update oh-my-zsh and themes"
    echo "  - Sync VS Code and Cursor extensions"
    echo "  - Check GitHub CLI authentication"
    echo "  - Generate sync reports"
}

# Function to show logs
show_logs() {
    if [ -f "$HOME/.local/log/automation/automation.log" ]; then
        echo "Dev-sync logs:"
        echo "=============="
        grep "dev-sync\|Development environment sync" "$HOME/.local/log/automation/automation.log" | tail -20
    else
        print_warning "No logs found. Service may not have run yet."
    fi
}

# Function to configure sync time
configure_time() {
    echo "Current sync time: 9:00 AM daily"
    echo ""
    echo "To change the sync time, edit the plist file:"
    echo "  $PLIST_FILE"
    echo ""
    echo "Modify the StartCalendarInterval section:"
    echo "  <key>Hour</key>"
    echo "  <integer>9</integer>  <!-- Change this (0-23) -->"
    echo "  <key>Minute</key>"
    echo "  <integer>0</integer>  <!-- Change this (0-59) -->"
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
        run_manual_sync
        ;;
    logs)
        show_logs
        ;;
    configure)
        configure_time
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
