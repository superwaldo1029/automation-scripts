#!/bin/bash

# Project Backup & Git Automation Script
# Automatically backs up projects and manages git operations

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
PROJECTS_DIR="$HOME/GitHub"
BACKUP_DIR="$HOME/.local/backup/projects"
DOTFILES_DIR="$HOME/dotfiles"
AUTO_COMMIT_BRANCHES=("main" "master" "develop" "dev")
MAX_BRANCHES_TO_KEEP=10
INACTIVE_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_message "INFO" "Starting project backup and git automation..."

# Function to find all git repositories
find_git_repos() {
    local search_dirs=("$PROJECTS_DIR" "$DOTFILES_DIR")
    local repos=()
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' repo; do
                repos+=("$repo")
            done < <(find "$dir" -type d -name ".git" -print0 2>/dev/null)
        fi
    done
    
    # Convert .git paths to repo paths
    for i in "${!repos[@]}"; do
        repos[$i]=$(dirname "${repos[$i]}")
    done
    
    printf '%s\n' "${repos[@]}"
}

# Function to get repository status
get_repo_status() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local status_file="$BACKUP_DIR/repo-status-$(date +%Y%m%d_%H%M%S).json"
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    
    local branch=$(get_git_branch "$repo_path")
    local has_changes=$(has_git_changes "$repo_path" && echo "true" || echo "false")
    local last_commit=$(git log -1 --format="%h %s" 2>/dev/null || echo "No commits")
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "No remote")
    local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    local staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
    local modified=$(git diff --name-only 2>/dev/null | wc -l)
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    local stashes=$(git stash list 2>/dev/null | wc -l)
    
    # Get last modification time
    local last_modified=$(find "$repo_path" -name "*.py" -o -name "*.js" -o -name "*.rb" -o -name "*.go" -o -name "*.java" -o -name "*.php" -o -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs stat -f "%m %N" 2>/dev/null | sort -nr | head -1 | cut -d' ' -f1)
    
    # Calculate days since last modification
    local days_inactive=0
    if [ -n "$last_modified" ]; then
        local current_time=$(date +%s)
        days_inactive=$(( (current_time - last_modified) / 86400 ))
    fi
    
    # Create status object
    cat >> "$status_file" << EOF
{
  "repo": "$repo_name",
  "path": "$repo_path",
  "branch": "$branch",
  "has_changes": $has_changes,
  "last_commit": "$last_commit",
  "remote_url": "$remote_url",
  "untracked_files": $untracked,
  "staged_files": $staged,
  "modified_files": $modified,
  "commits_ahead": $ahead,
  "commits_behind": $behind,
  "stashes": $stashes,
  "days_inactive": $days_inactive,
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    echo "$repo_name|$repo_path|$branch|$has_changes|$days_inactive|$ahead|$behind|$stashes"
}

# Function to auto-commit work in progress
auto_commit_wip() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    local branch=$(get_git_branch "$repo_path")
    
    # Check if it's a branch we should auto-commit to
    local should_commit=false
    for allowed_branch in "${AUTO_COMMIT_BRANCHES[@]}"; do
        if [[ "$branch" == "$allowed_branch" ]]; then
            should_commit=true
            break
        fi
    done
    
    if [[ "$should_commit" == "false" ]]; then
        print_debug "Skipping auto-commit for $repo_name (branch: $branch)"
        return 0
    fi
    
    if has_git_changes "$repo_path"; then
        print_status "Auto-committing WIP for $repo_name"
        
        # Add all changes
        git add .
        
        # Create WIP commit
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        git commit -m "WIP: Auto-commit backup - $timestamp

This is an automated backup commit created by the project backup system.
Contains work in progress that may not be ready for production.

Branch: $branch
Files modified: $(git diff --cached --name-only | wc -l)
Timestamp: $timestamp"
        
        log_message "INFO" "Auto-committed WIP for $repo_name"
        return 0
    else
        print_debug "No changes to commit for $repo_name"
        return 1
    fi
}

# Function to create backup branches
create_backup_branch() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    local current_branch=$(get_git_branch "$repo_path")
    local backup_branch="backup/$(date +%Y%m%d_%H%M%S)_$current_branch"
    
    # Only create backup if there are changes or we're on a main branch
    if has_git_changes "$repo_path" || [[ " ${AUTO_COMMIT_BRANCHES[@]} " =~ " $current_branch " ]]; then
        print_status "Creating backup branch for $repo_name: $backup_branch"
        
        # Create backup branch
        git checkout -b "$backup_branch"
        
        # Add and commit any remaining changes
        if has_git_changes "$repo_path"; then
            git add .
            git commit -m "Backup branch created - $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        
        # Switch back to original branch
        git checkout "$current_branch"
        
        log_message "INFO" "Created backup branch $backup_branch for $repo_name"
        return 0
    else
        print_debug "No backup branch needed for $repo_name"
        return 1
    fi
}

# Function to push to remote backup
push_to_remote() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    
    # Check if remote exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No remote origin found for $repo_name"
        return 1
    fi
    
    # Check if we have commits to push
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    if [[ "$ahead" -gt 0 ]]; then
        print_status "Pushing $ahead commits for $repo_name"
        
        # Push current branch
        local current_branch=$(get_git_branch "$repo_path")
        if git push origin "$current_branch" 2>/dev/null; then
            print_success "Successfully pushed $repo_name"
            log_message "INFO" "Pushed $ahead commits for $repo_name"
        else
            print_warning "Failed to push $repo_name (may need authentication)"
            log_message "WARNING" "Failed to push $repo_name"
        fi
        
        # Push backup branches
        local backup_branches=$(git branch | grep "backup/" | sed 's/^..//')
        for branch in $backup_branches; do
            if git push origin "$branch" 2>/dev/null; then
                print_debug "Pushed backup branch: $branch"
            fi
        done
    else
        print_debug "No commits to push for $repo_name"
    fi
}

# Function to clean up old backup branches
cleanup_old_branches() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    
    # Get all backup branches sorted by date (newest first)
    local backup_branches=($(git branch | grep "backup/" | sed 's/^..//' | sort -r))
    
    if [[ ${#backup_branches[@]} -gt $MAX_BRANCHES_TO_KEEP ]]; then
        print_status "Cleaning up old backup branches for $repo_name"
        
        # Keep only the latest branches
        local branches_to_delete=("${backup_branches[@]:$MAX_BRANCHES_TO_KEEP}")
        
        for branch in "${branches_to_delete[@]}"; do
            print_debug "Deleting old backup branch: $branch"
            git branch -D "$branch" 2>/dev/null
        done
        
        log_message "INFO" "Cleaned up ${#branches_to_delete[@]} old backup branches for $repo_name"
    fi
}

# Function to stash uncommitted changes
stash_changes() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    cd "$repo_path"
    
    if has_git_changes "$repo_path"; then
        local stash_message="Auto-stash backup - $(date '+%Y-%m-%d %H:%M:%S')"
        
        print_status "Stashing uncommitted changes for $repo_name"
        git stash push -m "$stash_message"
        
        log_message "INFO" "Stashed changes for $repo_name"
        return 0
    else
        return 1
    fi
}

# Function to generate project status report
generate_project_report() {
    local report_file="$BACKUP_DIR/project-report-$(date +%Y%m%d_%H%M%S).md"
    
    print_status "Generating project status report..."
    
    cat > "$report_file" << 'EOF'
# Project Backup Status Report

Generated: $(date)

## Summary

| Repository | Branch | Status | Days Inactive | Commits Ahead | Commits Behind | Stashes |
|------------|--------|--------|---------------|---------------|----------------|---------|
EOF
    
    # Process each repository
    local repos=($(find_git_repos))
    local total_repos=${#repos[@]}
    local active_repos=0
    local repos_with_changes=0
    local repos_need_push=0
    
    for repo in "${repos[@]}"; do
        local status_info=$(get_repo_status "$repo")
        IFS='|' read -r name path branch has_changes days_inactive ahead behind stashes <<< "$status_info"
        
        # Count statistics
        if [[ $days_inactive -lt $INACTIVE_DAYS ]]; then
            ((active_repos++))
        fi
        
        if [[ "$has_changes" == "true" ]]; then
            ((repos_with_changes++))
        fi
        
        if [[ $ahead -gt 0 ]]; then
            ((repos_need_push++))
        fi
        
        # Add to report
        local status_emoji="✅"
        if [[ "$has_changes" == "true" ]]; then
            status_emoji="🔄"
        elif [[ $ahead -gt 0 ]]; then
            status_emoji="📤"
        elif [[ $days_inactive -gt $INACTIVE_DAYS ]]; then
            status_emoji="😴"
        fi
        
        echo "| $name | $branch | $status_emoji | $days_inactive | $ahead | $behind | $stashes |" >> "$report_file"
    done
    
    # Add summary statistics
    cat >> "$report_file" << EOF

## Statistics

- **Total Repositories**: $total_repos
- **Active Repositories**: $active_repos (last $INACTIVE_DAYS days)
- **Repositories with Changes**: $repos_with_changes
- **Repositories Need Push**: $repos_need_push
- **Inactive Repositories**: $((total_repos - active_repos))

## Legend

- ✅ Up to date
- 🔄 Has uncommitted changes
- 📤 Has commits to push
- 😴 Inactive (>$INACTIVE_DAYS days)

## Actions Taken

This backup run performed the following actions:
- Auto-committed WIP changes for active repositories
- Created backup branches where needed
- Pushed changes to remote repositories
- Cleaned up old backup branches
- Generated this status report

## Notes

- WIP commits are only created for main branches: ${AUTO_COMMIT_BRANCHES[*]}
- Backup branches are kept for active repositories
- Maximum backup branches per repository: $MAX_BRANCHES_TO_KEEP
- Repositories inactive for >$INACTIVE_DAYS days are marked as inactive

---

*Report generated by Project Backup System*
EOF
    
    print_success "Project report generated: $report_file"
    log_message "INFO" "Project report generated with $total_repos repositories"
}

# Function to backup specific project
backup_project() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if ! is_git_repo "$repo_path"; then
        print_warning "Not a git repository: $repo_path"
        return 1
    fi
    
    print_status "Backing up project: $repo_name"
    
    # Get initial status
    local status_info=$(get_repo_status "$repo_path")
    IFS='|' read -r name path branch has_changes days_inactive ahead behind stashes <<< "$status_info"
    
    # Skip inactive repositories unless forced
    if [[ $days_inactive -gt $INACTIVE_DAYS ]] && [[ "${FORCE_BACKUP:-false}" != "true" ]]; then
        print_debug "Skipping inactive repository: $repo_name ($days_inactive days)"
        return 0
    fi
    
    # Perform backup operations
    local actions_performed=0
    
    # 1. Auto-commit WIP if there are changes
    if auto_commit_wip "$repo_path"; then
        ((actions_performed++))
    fi
    
    # 2. Create backup branch if needed
    if create_backup_branch "$repo_path"; then
        ((actions_performed++))
    fi
    
    # 3. Push to remote
    if push_to_remote "$repo_path"; then
        ((actions_performed++))
    fi
    
    # 4. Clean up old branches
    cleanup_old_branches "$repo_path"
    
    if [[ $actions_performed -gt 0 ]]; then
        print_success "Backup completed for $repo_name ($actions_performed actions)"
        log_message "INFO" "Backup completed for $repo_name with $actions_performed actions"
    else
        print_debug "No backup actions needed for $repo_name"
    fi
}

# Main execution function
main() {
    print_status "Starting project backup automation..."
    
    # Check prerequisites
    if ! has_git; then
        print_error "Git is not installed"
        exit 1
    fi
    
    if ! check_internet; then
        print_warning "No internet connection - remote operations will be skipped"
    fi
    
    # Find all git repositories
    local repos=($(find_git_repos))
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        print_warning "No git repositories found"
        exit 0
    fi
    
    print_status "Found ${#repos[@]} git repositories"
    
    # Process each repository
    for repo in "${repos[@]}"; do
        backup_project "$repo"
    done
    
    # Generate status report
    generate_project_report
    
    print_success "Project backup automation completed!"
    send_notification "Project Backup" "Backup completed for ${#repos[@]} repositories"
    
    log_message "INFO" "Project backup automation completed for ${#repos[@]} repositories"
}

# Handle command line arguments
case "${1:-}" in
    --force)
        export FORCE_BACKUP=true
        print_status "Force backup mode enabled (including inactive repositories)"
        ;;
    --repo)
        if [[ -n "${2:-}" ]]; then
            if [[ -d "$2" ]]; then
                backup_project "$2"
                exit 0
            else
                print_error "Repository path does not exist: $2"
                exit 1
            fi
        else
            print_error "Repository path required with --repo option"
            exit 1
        fi
        ;;
    --help|-h)
        echo "Project Backup & Git Automation"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --force      Backup all repositories including inactive ones"
        echo "  --repo PATH  Backup specific repository"
        echo "  --help       Show this help message"
        echo ""
        echo "Features:"
        echo "  - Auto-commit WIP changes"
        echo "  - Create backup branches"
        echo "  - Push to remote repositories"
        echo "  - Clean up old backup branches"
        echo "  - Generate status reports"
        exit 0
        ;;
esac

# Run main function
main "$@"
