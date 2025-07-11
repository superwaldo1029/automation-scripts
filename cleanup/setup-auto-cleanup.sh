#!/bin/bash

# Setup Auto-Cleanup Service
# Installs and manages the automated cleanup service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/auto-cleanup.sh"
PLIST_FILE="$SCRIPT_DIR/com.user.auto-cleanup.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/com.user.auto-cleanup.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Function to check if service is loaded
is_service_loaded() {
    launchctl list | grep -q "com.user.auto-cleanup"
}

# Function to install the service
install_service() {
    print_status "Installing auto-cleanup service..."
    
    # Create directories
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$HOME/.local/log"
    
    # Make scripts executable
    chmod +x "$CLEANUP_SCRIPT"
    
    # Copy plist file
    cp "$PLIST_FILE" "$INSTALLED_PLIST"
    
    # Load the service
    launchctl load "$INSTALLED_PLIST"
    
    if is_service_loaded; then
        print_status "Service installed successfully!"
        print_status "Auto-cleanup will run every 8 hours"
        print_status "Logs will be saved to: $HOME/.local/log/auto-cleanup.log"
    else
        print_error "Failed to install service"
        return 1
    fi
}

# Function to uninstall the service
uninstall_service() {
    print_status "Uninstalling auto-cleanup service..."
    
    if is_service_loaded; then
        launchctl unload "$INSTALLED_PLIST"
    fi
    
    rm -f "$INSTALLED_PLIST"
    
    if ! is_service_loaded; then
        print_status "Service uninstalled successfully!"
    else
        print_error "Failed to uninstall service"
        return 1
    fi
}

# Function to show service status
show_status() {
    echo "Auto-Cleanup Service Status:"
    echo "=========================="
    
    if is_service_loaded; then
        print_status "Service is RUNNING"
        echo "  - Runs every 8 hours"
        echo "  - Script: $CLEANUP_SCRIPT"
        echo "  - Logs: $HOME/.local/log/auto-cleanup.log"
        
        # Show last few log entries
        if [ -f "$HOME/.local/log/auto-cleanup.log" ]; then
            echo ""
            echo "Recent log entries:"
            tail -5 "$HOME/.local/log/auto-cleanup.log"
        fi
    else
        print_warning "Service is NOT running"
    fi
}

# Function to run cleanup manually
run_manual_cleanup() {
    print_status "Running manual cleanup..."
    "$CLEANUP_SCRIPT"
}

# Function to show help
show_help() {
    echo "Auto-Cleanup Service Manager"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install   - Install and start the auto-cleanup service"
    echo "  uninstall - Stop and remove the auto-cleanup service"
    echo "  status    - Show current service status"
    echo "  run       - Run cleanup manually"
    echo "  logs      - Show recent logs"
    echo "  help      - Show this help message"
    echo ""
    echo "The service will:"
    echo "  - Empty trash every 8 hours"
    echo "  - Clean Homebrew cache"
    echo "  - Clean npm cache (if >500MB)"
    echo "  - Clean pip cache"
    echo "  - Clean old Microsoft Office logs"
    echo "  - Clean safe system caches"
}

# Function to show logs
show_logs() {
    if [ -f "$HOME/.local/log/auto-cleanup.log" ]; then
        echo "Auto-cleanup logs:"
        echo "=================="
        tail -20 "$HOME/.local/log/auto-cleanup.log"
    else
        print_warning "No logs found. Service may not have run yet."
    fi
}

# Main script logic
case "${1:-help}" in
    install)
        if is_service_loaded; then
            print_warning "Service is already installed"
            show_status
        else
            install_service
        fi
        ;;
    uninstall)
        if is_service_loaded; then
            uninstall_service
        else
            print_warning "Service is not installed"
        fi
        ;;
    status)
        show_status
        ;;
    run)
        run_manual_cleanup
        ;;
    logs)
        show_logs
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
