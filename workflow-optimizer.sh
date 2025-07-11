#!/bin/zsh

# Workflow Optimizer Script

# Pull latest changes for all repositories in a specific directory
function update_repos() {
  local dir="$1"
  
  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist, skipping repository updates."
    return
  fi
  
  # Use nullglob to handle empty directories gracefully
  setopt nullglob
  
  for repo in "$dir"/*; do
    if [ -d "$repo/.git" ]; then
      echo "Updating $(basename "$repo")..."
      cd "$repo"
      # Try main branch first, then master if main doesn't exist
      git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  Could not pull from origin"
      cd - > /dev/null
    fi
  done
  
  unsetopt nullglob
}

# Function to clean up temporary files
function cleanup_temp_files() {
  local dir="$1"
  
  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist, skipping temp file cleanup."
    return
  fi
  
  echo "Cleaning up temporary files in $dir..."
  local deleted_count=$(find "$dir" -type f \( -name '*.tmp' -o -name '*.log' \) -delete -print | wc -l)
  echo "  Deleted $deleted_count temporary files."
}

# Function to notify user
function notify_user() {
  local message="$1"
  osascript -e "display notification \"$message\" with title \"Workflow Optimizer\""
}

# Main function
function main() {
  local github_dir="$HOME/GitHub"
  local temp_dir="$HOME/Downloads"  # Use Downloads as temp cleanup since /tmp would be too aggressive

  echo "Starting workflow optimization..."

  update_repos "$github_dir"
  notify_user "Repositories updated."

  cleanup_temp_files "$temp_dir"
  notify_user "Temporary files cleaned up."

  echo "Workflow optimization complete."
}

# Execute the main function
main

