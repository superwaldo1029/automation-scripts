#!/bin/bash

# Daily Workflow Optimizer
# Optimizes development environment for maximum productivity

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
WORKSPACE_DIR="$HOME/GitHub"
DOTFILES_DIR="$HOME/dotfiles"
AUTOMATION_DIR="$HOME/automation-scripts"
DOWNLOADS_DIR="$HOME/Downloads"
DESKTOP_DIR="$HOME/Desktop"
PROJECTS_CONFIG="$HOME/.local/config/workflow-optimizer/projects.json"
DAILY_LOG="$HOME/.local/log/automation/daily-setup.log"

# Create necessary directories
mkdir -p "$(dirname "$PROJECTS_CONFIG")"
mkdir -p "$(dirname "$DAILY_LOG")"

log_message "INFO" "Starting daily workflow optimization..."

# Function to detect recent projects
detect_recent_projects() {
    print_status "Detecting recently active projects..."
    
    local recent_projects=()
    local search_dirs=("$WORKSPACE_DIR" "$DOTFILES_DIR" "$AUTOMATION_DIR")
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            # Find git repositories modified in last 7 days
            while IFS= read -r -d '' repo; do
                local repo_path=$(dirname "$repo")
                local repo_name=$(basename "$repo_path")
                local last_modified=$(find "$repo_path" -name "*.py" -o -name "*.js" -o -name "*.rb" -o -name "*.go" -o -name "*.java" -o -name "*.php" -o -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" 2>/dev/null | xargs stat -f "%m %N" 2>/dev/null | sort -nr | head -1 | cut -d' ' -f1)
                
                if [ -n "$last_modified" ]; then
                    local current_time=$(date +%s)
                    local days_ago=$(( (current_time - last_modified) / 86400 ))
                    
                    if [ $days_ago -le 7 ]; then
                        recent_projects+=("$repo_path|$repo_name|$days_ago")
                        print_debug "Found recent project: $repo_name ($days_ago days ago)"
                    fi
                fi
            done < <(find "$dir" -type d -name ".git" -print0 2>/dev/null)
        fi
    done
    
    # Save to config
    {
        echo "{"
        echo "  \"recent_projects\": ["
        for i in "${!recent_projects[@]}"; do
            IFS='|' read -r path name days <<< "${recent_projects[$i]}"
            echo "    {"
            echo "      \"path\": \"$path\","
            echo "      \"name\": \"$name\","
            echo "      \"days_ago\": $days"
            if [ $i -eq $((${#recent_projects[@]} - 1)) ]; then
                echo "    }"
            else
                echo "    },"
            fi
        done
        echo "  ],"
        echo "  \"last_updated\": \"$(date -Iseconds)\""
        echo "}"
    } > "$PROJECTS_CONFIG"
    
    print_success "Found ${#recent_projects[@]} recently active projects"
    log_message "INFO" "Detected ${#recent_projects[@]} recent projects"
}

# Function to pre-warm applications
prewarm_applications() {
    print_status "Pre-warming commonly used applications..."
    
    local apps_to_start=(
        "Warp"           # Terminal
        "Cursor"         # AI Editor
        "GitHub Desktop" # Git GUI
    )
    
    local started_apps=0
    
    for app in "${apps_to_start[@]}"; do
        if ! pgrep -f "$app" >/dev/null 2>&1; then
            print_status "Starting $app..."
            open -a "$app" 2>/dev/null && {
                ((started_apps++))
                print_debug "Started $app"
            } || {
                print_warning "Failed to start $app"
            }
            # Small delay to avoid overwhelming the system
            sleep 1
        else
            print_debug "$app is already running"
        fi
    done
    
    print_success "Pre-warmed $started_apps applications"
    log_message "INFO" "Pre-warmed $started_apps applications"
}

# Function to organize Downloads folder
organize_downloads() {
    print_status "Organizing Downloads folder..."
    
    if [ ! -d "$DOWNLOADS_DIR" ]; then
        print_warning "Downloads directory not found"
        return 1
    fi
    
    local organized_count=0
    local archive_dir="$DOWNLOADS_DIR/Archive/$(date +%Y/%m)"
    
    # Create archive directory
    mkdir -p "$archive_dir"
    
    # Move old files (>7 days) to archive
    find "$DOWNLOADS_DIR" -maxdepth 1 -type f -mtime +7 | while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            print_debug "Archiving old file: $filename"
            mv "$file" "$archive_dir/" 2>/dev/null && ((organized_count++))
        fi
    done
    
    # Organize by file type
    local file_types=(
        "*.pdf|Documents"
        "*.doc,*.docx,*.txt|Documents"
        "*.zip,*.tar,*.gz,*.dmg|Archives"
        "*.jpg,*.jpeg,*.png,*.gif|Images"
        "*.mp4,*.mov,*.avi|Videos"
        "*.mp3,*.wav,*.aac|Audio"
    )
    
    for type_rule in "${file_types[@]}"; do
        IFS='|' read -r pattern folder <<< "$type_rule"
        local target_dir="$DOWNLOADS_DIR/$folder"
        
        if compgen -G "$DOWNLOADS_DIR/$pattern" > /dev/null; then
            mkdir -p "$target_dir"
            for file in $DOWNLOADS_DIR/$pattern; do
                if [ -f "$file" ]; then
                    mv "$file" "$target_dir/" 2>/dev/null && ((organized_count++))
                fi
            done
        fi
    done
    
    print_success "Organized $organized_count files in Downloads"
    log_message "INFO" "Organized $organized_count files in Downloads"
}

# Function to clean up Desktop
cleanup_desktop() {
    print_status "Cleaning up Desktop..."
    
    if [ ! -d "$DESKTOP_DIR" ]; then
        print_warning "Desktop directory not found"
        return 1
    fi
    
    local cleanup_count=0
    local desktop_archive="$DESKTOP_DIR/Archive/$(date +%Y-%m-%d)"
    
    # Create archive directory
    mkdir -p "$desktop_archive"
    
    # Move old files (>3 days) from Desktop
    find "$DESKTOP_DIR" -maxdepth 1 -type f -mtime +3 | while IFS= read -r file; do
        if [ -f "$file" ] && [[ "$(basename "$file")" != .* ]]; then
            local filename=$(basename "$file")
            print_debug "Archiving desktop file: $filename"
            mv "$file" "$desktop_archive/" 2>/dev/null && ((cleanup_count++))
        fi
    done
    
    # Organize screenshots
    local screenshots_dir="$DESKTOP_DIR/Screenshots/$(date +%Y-%m)"
    mkdir -p "$screenshots_dir"
    
    find "$DESKTOP_DIR" -maxdepth 1 -name "Screenshot*" -o -name "Screen Shot*" | while IFS= read -r screenshot; do
        if [ -f "$screenshot" ]; then
            mv "$screenshot" "$screenshots_dir/" 2>/dev/null && ((cleanup_count++))
        fi
    done
    
    print_success "Cleaned up $cleanup_count items from Desktop"
    log_message "INFO" "Cleaned up $cleanup_count items from Desktop"
}

# Function to update project dependencies
update_project_dependencies() {
    print_status "Checking project dependencies..."
    
    if [ ! -f "$PROJECTS_CONFIG" ]; then
        print_warning "No recent projects config found"
        return 1
    fi
    
    local updated_projects=0
    
    # Parse JSON and update dependencies for recent projects
    if command_exists jq; then
        local projects=$(jq -r '.recent_projects[] | select(.days_ago <= 3) | .path' "$PROJECTS_CONFIG" 2>/dev/null)
        
        while IFS= read -r project_path; do
            if [ -d "$project_path" ] && [ -n "$project_path" ]; then
                local project_name=$(basename "$project_path")
                print_status "Checking dependencies for $project_name..."
                
                cd "$project_path"
                
                # Node.js project
                if [ -f "package.json" ] && has_npm; then
                    local outdated=$(npm outdated --json 2>/dev/null | jq -r 'keys[]' 2>/dev/null)
                    if [ -n "$outdated" ]; then
                        print_status "Updating npm dependencies for $project_name"
                        npm update 2>/dev/null && ((updated_projects++))
                    fi
                fi
                
                # Ruby project
                if [ -f "Gemfile" ] && command_exists bundle; then
                    print_status "Updating Ruby gems for $project_name"
                    bundle update 2>/dev/null && ((updated_projects++))
                fi
                
                # Python project
                if [ -f "requirements.txt" ] && command_exists pip; then
                    print_status "Checking Python requirements for $project_name"
                    pip install -r requirements.txt --upgrade --quiet 2>/dev/null && ((updated_projects++))
                fi
            fi
        done <<< "$projects"
    else
        print_warning "jq not available, skipping dependency updates"
    fi
    
    print_success "Updated dependencies for $updated_projects projects"
    log_message "INFO" "Updated dependencies for $updated_projects projects"
}

# Function to prepare development environment
prepare_dev_environment() {
    print_status "Preparing development environment..."
    
    local preparations=0
    
    # Start commonly used services
    if has_homebrew; then
        print_status "Starting development services..."
        
        # Check for common development services
        local services=("postgresql" "redis" "mysql")
        for service in "${services[@]}"; do
            if brew services list | grep -q "$service.*started"; then
                print_debug "$service is already running"
            elif brew services list | grep -q "$service"; then
                print_status "Starting $service..."
                brew services start "$service" 2>/dev/null && {
                    ((preparations++))
                    print_debug "Started $service"
                }
            fi
        done
    fi
    
    # Warm up commonly used directories
    print_status "Pre-loading directory indexes..."
    local common_dirs=("$WORKSPACE_DIR" "$DOTFILES_DIR" "$AUTOMATION_DIR")
    for dir in "${common_dirs[@]}"; do
        if [ -d "$dir" ]; then
            # Pre-load directory listing to warm up file system cache
            find "$dir" -type d -maxdepth 2 > /dev/null 2>&1 &
            ((preparations++))
        fi
    done
    
    # Update locate database for faster file searches
    if command_exists updatedb; then
        print_status "Updating locate database..."
        updatedb 2>/dev/null && ((preparations++))
    fi
    
    print_success "Completed $preparations environment preparations"
    log_message "INFO" "Completed $preparations environment preparations"
}

# Function to check system health
check_system_health() {
    print_status "Checking system health..."
    
    local health_issues=0
    local available_space=$(get_available_space)
    
    # Check disk space
    if [[ $available_space -lt 5 ]]; then
        print_warning "Low disk space: ${available_space}GB available"
        ((health_issues++))
    else
        print_success "Disk space OK: ${available_space}GB available"
    fi
    
    # Check memory usage
    local memory_pressure=$(memory_pressure 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    if [[ -n "$memory_pressure" ]] && [[ $memory_pressure -gt 80 ]]; then
        print_warning "High memory pressure: ${memory_pressure}%"
        ((health_issues++))
    fi
    
    # Check for software updates (non-intrusive)
    if is_macos; then
        local updates=$(softwareupdate -l 2>/dev/null | grep -c "recommended" || echo "0")
        if [[ $updates -gt 0 ]]; then
            print_warning "$updates macOS updates available"
            ((health_issues++))
        fi
    fi
    
    # Check for broken symlinks
    local broken_symlinks=$(find ~ -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)
    if [[ $broken_symlinks -gt 0 ]]; then
        print_warning "$broken_symlinks broken symlinks found in home directory"
        ((health_issues++))
    fi
    
    if [[ $health_issues -eq 0 ]]; then
        print_success "System health check passed"
    else
        print_warning "Found $health_issues potential issues"
    fi
    
    log_message "INFO" "System health check completed with $health_issues issues"
}

# Function to create daily summary
create_daily_summary() {
    local summary_file="$HOME/.local/log/automation/daily-summary-$(date +%Y%m%d).md"
    
    print_status "Creating daily workflow summary..."
    
    cat > "$summary_file" << EOF
# Daily Workflow Summary
Generated: $(date '+%Y-%m-%d %H:%M:%S')

## System Status
- Available Disk Space: $(get_available_space)GB
- System: $(get_system_info)
- User: $(whoami)

## Recent Projects
EOF
    
    if [ -f "$PROJECTS_CONFIG" ] && command_exists jq; then
        echo "" >> "$summary_file"
        jq -r '.recent_projects[] | "- **\(.name)** (\(.days_ago) days ago): `\(.path)`"' "$PROJECTS_CONFIG" >> "$summary_file" 2>/dev/null
    else
        echo "- No recent projects configuration found" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

## Applications Status
- Terminal: Warp $(pgrep -f "Warp" >/dev/null && echo "✅ Running" || echo "❌ Not running")
- Editor: Cursor $(pgrep -f "Cursor" >/dev/null && echo "✅ Running" || echo "❌ Not running")
- GitHub Desktop: $(pgrep -f "GitHub Desktop" >/dev/null && echo "✅ Running" || echo "❌ Not running")

## Development Services
EOF
    
    if has_homebrew; then
        echo "- PostgreSQL: $(brew services list | grep postgresql | awk '{print $2}' | sed 's/started/✅ Running/;s/stopped/❌ Stopped/')" >> "$summary_file"
        echo "- Redis: $(brew services list | grep redis | awk '{print $2}' | sed 's/started/✅ Running/;s/stopped/❌ Stopped/')" >> "$summary_file"
        echo "- MySQL: $(brew services list | grep mysql | awk '{print $2}' | sed 's/started/✅ Running/;s/stopped/❌ Stopped/')" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

## Optimizations Performed
- ✅ Recent projects detected
- ✅ Applications pre-warmed
- ✅ Downloads organized
- ✅ Desktop cleaned
- ✅ Dependencies checked
- ✅ Environment prepared
- ✅ System health checked

## Quick Commands
\`\`\`bash
# Jump to recent projects
$(if [ -f "$PROJECTS_CONFIG" ] && command_exists jq; then
    jq -r '.recent_projects[] | select(.days_ago <= 3) | "cd \"\(.path)\""' "$PROJECTS_CONFIG" 2>/dev/null | head -3
fi)

# Development shortcuts
gh repo list --limit 5
npm list -g --depth=0
brew services list
\`\`\`

---
*Generated by Workflow Optimizer*
EOF
    
    print_success "Daily summary created: $summary_file"
    log_message "INFO" "Daily summary created"
}

# Function to send morning notification
send_morning_notification() {
    local project_count=0
    if [ -f "$PROJECTS_CONFIG" ] && command_exists jq; then
        project_count=$(jq '.recent_projects | length' "$PROJECTS_CONFIG" 2>/dev/null || echo "0")
    fi
    
    local message="Daily workflow optimization complete! Found $project_count recent projects. System ready for development."
    
    send_notification "Workflow Optimizer" "$message" "Glass"
    print_success "Morning notification sent"
}

# Main execution function
main() {
    print_status "Starting daily workflow optimization..."
    
    # Record start time
    local start_time=$(date +%s)
    
    # Run optimization steps
    detect_recent_projects
    prewarm_applications
    organize_downloads
    cleanup_desktop
    update_project_dependencies
    prepare_dev_environment
    check_system_health
    create_daily_summary
    send_morning_notification
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "Daily workflow optimization completed in ${duration}s"
    log_message "INFO" "Daily workflow optimization completed in ${duration}s"
}

# Handle command line arguments
case "${1:-}" in
    --projects-only)
        detect_recent_projects
        exit 0
        ;;
    --apps-only)
        prewarm_applications
        exit 0
        ;;
    --organize-only)
        organize_downloads
        cleanup_desktop
        exit 0
        ;;
    --deps-only)
        update_project_dependencies
        exit 0
        ;;
    --health-only)
        check_system_health
        exit 0
        ;;
    --summary-only)
        create_daily_summary
        exit 0
        ;;
    --help|-h)
        echo "Daily Workflow Optimizer"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --projects-only   Only detect recent projects"
        echo "  --apps-only      Only pre-warm applications"
        echo "  --organize-only  Only organize downloads and desktop"
        echo "  --deps-only      Only update project dependencies"
        echo "  --health-only    Only check system health"
        echo "  --summary-only   Only create daily summary"
        echo "  --help           Show this help message"
        echo ""
        echo "Features:"
        echo "  - Detect recently active projects"
        echo "  - Pre-warm commonly used applications"
        echo "  - Organize Downloads and Desktop"
        echo "  - Update project dependencies"
        echo "  - Prepare development environment"
        echo "  - Check system health"
        echo "  - Generate daily summary report"
        exit 0
        ;;
esac

# Run main function
main "$@"
