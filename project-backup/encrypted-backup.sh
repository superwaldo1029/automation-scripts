#!/bin/bash

# Encrypted Backup System
# Creates secure, encrypted backups of sensitive project data

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
ENCRYPTED_BACKUP_DIR="$HOME/.local/backup/encrypted"
BACKUP_KEY_FILE="$HOME/.local/keys/backup-key.txt"
BACKUP_CONFIG_FILE="$SCRIPT_DIR/backup-config.json"
BACKUP_LOG="$HOME/.local/log/automation/encrypted-backup.log"

# Create directories
mkdir -p "$ENCRYPTED_BACKUP_DIR" "$(dirname "$BACKUP_KEY_FILE")" "$(dirname "$BACKUP_LOG")"

log_backup() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$BACKUP_LOG"
}

# Function to generate or retrieve backup encryption key
get_backup_key() {
    if [ ! -f "$BACKUP_KEY_FILE" ]; then
        print_status "Generating new backup encryption key..."
        
        # Generate a strong 256-bit key
        openssl rand -base64 32 > "$BACKUP_KEY_FILE"
        chmod 600 "$BACKUP_KEY_FILE"
        
        log_backup "INFO" "New backup encryption key generated"
        print_warning "IMPORTANT: Backup encryption key generated at $BACKUP_KEY_FILE"
        print_warning "Store this key securely - you cannot decrypt backups without it!"
    fi
    
    cat "$BACKUP_KEY_FILE"
}

# Function to create backup configuration
create_backup_config() {
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        cat > "$BACKUP_CONFIG_FILE" << 'EOF'
{
  "backup_sets": {
    "sensitive_configs": {
      "description": "Sensitive configuration files",
      "paths": [
        "~/.ssh",
        "~/.aws",
        "~/.config/gh",
        "~/.gitconfig",
        "~/.env*"
      ],
      "exclude_patterns": [
        "*.log",
        "*.tmp",
        ".DS_Store",
        "known_hosts"
      ],
      "encryption": true,
      "compression": true
    },
    "development_secrets": {
      "description": "Development environment secrets",
      "paths": [
        "~/GitHub/*/.env*",
        "~/GitHub/*/config/secrets*",
        "~/GitHub/*/keys",
        "~/GitHub/*/.secrets"
      ],
      "exclude_patterns": [
        "node_modules",
        ".git",
        "*.log"
      ],
      "encryption": true,
      "compression": true
    },
    "certificates": {
      "description": "SSL certificates and keys",
      "paths": [
        "~/.ssl",
        "~/certificates",
        "~/*.pem",
        "~/*.key",
        "~/*.crt"
      ],
      "exclude_patterns": [],
      "encryption": true,
      "compression": false
    }
  },
  "retention": {
    "daily": 7,
    "weekly": 4,
    "monthly": 12
  },
  "encryption": {
    "algorithm": "aes-256-cbc",
    "key_derivation": "pbkdf2",
    "iterations": 100000
  }
}
EOF
        print_success "Backup configuration created: $BACKUP_CONFIG_FILE"
    fi
}

# Function to parse JSON configuration
parse_backup_config() {
    if command -v jq >/dev/null 2>&1; then
        cat "$BACKUP_CONFIG_FILE"
    else
        print_warning "jq not found - using basic JSON parsing"
        cat "$BACKUP_CONFIG_FILE"
    fi
}

# Function to expand path patterns
expand_paths() {
    local paths=("$@")
    local expanded_paths=()
    
    for path in "${paths[@]}"; do
        # Expand tilde
        expanded_path=$(eval echo "$path")
        
        # Handle wildcards
        if [[ "$expanded_path" == *"*"* ]]; then
            # Use find for wildcard expansion
            while IFS= read -r -d '' found_path; do
                expanded_paths+=("$found_path")
            done < <(find $(dirname "$expanded_path") -path "$expanded_path" -print0 2>/dev/null)
        else
            if [ -e "$expanded_path" ]; then
                expanded_paths+=("$expanded_path")
            fi
        fi
    done
    
    printf '%s\n' "${expanded_paths[@]}"
}

# Function to create encrypted archive
create_encrypted_archive() {
    local backup_set="$1"
    local paths=("${@:2}")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="${backup_set}-${timestamp}"
    local temp_archive="/tmp/${archive_name}.tar.gz"
    local encrypted_archive="$ENCRYPTED_BACKUP_DIR/${archive_name}.tar.gz.enc"
    local manifest_file="$ENCRYPTED_BACKUP_DIR/${archive_name}.manifest"
    
    print_status "Creating encrypted backup for $backup_set..."
    
    # Create temporary manifest
    cat > "$manifest_file" << EOF
{
  "backup_set": "$backup_set",
  "timestamp": "$timestamp",
  "date": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "paths": [
$(printf '    "%s",\n' "${paths[@]}" | sed '$ s/,$//')
  ],
  "archive_size": "",
  "encrypted_size": "",
  "checksum": ""
}
EOF
    
    # Create compressed archive
    print_status "Compressing files..."
    if tar -czf "$temp_archive" -C / "${paths[@]/#//}" 2>/dev/null; then
        local archive_size=$(stat -f%z "$temp_archive" 2>/dev/null || stat -c%s "$temp_archive" 2>/dev/null)
        
        # Encrypt the archive
        print_status "Encrypting archive..."
        local backup_key=$(get_backup_key)
        
        if echo "$backup_key" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$temp_archive" -out "$encrypted_archive" -pass stdin; then
            local encrypted_size=$(stat -f%z "$encrypted_archive" 2>/dev/null || stat -c%s "$encrypted_archive" 2>/dev/null)
            local checksum=$(shasum -a 256 "$encrypted_archive" | cut -d' ' -f1)
            
            # Update manifest
            sed -i.bak "s/\"archive_size\": \"\"/\"archive_size\": \"$archive_size\"/" "$manifest_file"
            sed -i.bak "s/\"encrypted_size\": \"\"/\"encrypted_size\": \"$encrypted_size\"/" "$manifest_file"
            sed -i.bak "s/\"checksum\": \"\"/\"checksum\": \"$checksum\"/" "$manifest_file"
            rm -f "${manifest_file}.bak"
            
            # Clean up temporary file
            rm -f "$temp_archive"
            
            print_success "Encrypted backup created: $(basename "$encrypted_archive")"
            log_backup "INFO" "Encrypted backup created for $backup_set: $encrypted_archive"
            
            echo "$encrypted_archive"
            return 0
        else
            print_error "Failed to encrypt archive"
            rm -f "$temp_archive"
            return 1
        fi
    else
        print_error "Failed to create archive for $backup_set"
        return 1
    fi
}

# Function to decrypt and restore backup
decrypt_backup() {
    local encrypted_file="$1"
    local output_dir="$2"
    
    if [ ! -f "$encrypted_file" ]; then
        print_error "Encrypted backup file not found: $encrypted_file"
        return 1
    fi
    
    if [ -z "$output_dir" ]; then
        output_dir="/tmp/restored-$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$output_dir"
    
    print_status "Decrypting backup: $(basename "$encrypted_file")"
    
    local backup_key=$(get_backup_key)
    local temp_archive="/tmp/decrypted-$(basename "$encrypted_file" .enc)"
    
    # Decrypt the archive
    if echo "$backup_key" | openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$encrypted_file" -out "$temp_archive" -pass stdin; then
        print_status "Extracting to: $output_dir"
        
        # Extract the archive
        if tar -xzf "$temp_archive" -C "$output_dir"; then
            rm -f "$temp_archive"
            print_success "Backup restored to: $output_dir"
            log_backup "INFO" "Backup restored: $encrypted_file -> $output_dir"
            return 0
        else
            print_error "Failed to extract archive"
            rm -f "$temp_archive"
            return 1
        fi
    else
        print_error "Failed to decrypt backup - check encryption key"
        return 1
    fi
}

# Function to cleanup old backups based on retention policy
cleanup_old_backups() {
    print_status "Cleaning up old backups..."
    
    # Get retention settings (default values if jq not available)
    local daily_keep=7
    local weekly_keep=4
    local monthly_keep=12
    
    if command -v jq >/dev/null 2>&1; then
        daily_keep=$(jq -r '.retention.daily' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo 7)
        weekly_keep=$(jq -r '.retention.weekly' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo 4)
        monthly_keep=$(jq -r '.retention.monthly' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo 12)
    fi
    
    # Find all encrypted backup files
    local backup_files=($(find "$ENCRYPTED_BACKUP_DIR" -name "*.tar.gz.enc" -type f | sort))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        print_debug "No backup files found for cleanup"
        return 0
    fi
    
    local files_removed=0
    local current_time=$(date +%s)
    
    for backup_file in "${backup_files[@]}"; do
        local file_time=$(stat -f%B "$backup_file" 2>/dev/null || stat -c%Y "$backup_file" 2>/dev/null)
        local age_days=$(( (current_time - file_time) / 86400 ))
        
        local should_remove=false
        
        # Apply retention policy
        if [ $age_days -gt $((monthly_keep * 30)) ]; then
            should_remove=true
        elif [ $age_days -gt $((weekly_keep * 7)) ] && [ $((age_days % 7)) -ne 0 ]; then
            should_remove=true
        elif [ $age_days -gt $daily_keep ] && [ $age_days -lt $((weekly_keep * 7)) ]; then
            should_remove=true
        fi
        
        if [ "$should_remove" = true ]; then
            print_debug "Removing old backup: $(basename "$backup_file") (${age_days} days old)"
            rm -f "$backup_file"
            rm -f "${backup_file%.tar.gz.enc}.manifest"
            ((files_removed++))
        fi
    done
    
    if [ $files_removed -gt 0 ]; then
        print_success "Cleaned up $files_removed old backup files"
        log_backup "INFO" "Cleaned up $files_removed old backup files"
    else
        print_debug "No old backup files to remove"
    fi
}

# Function to list available backups
list_backups() {
    print_status "Available encrypted backups:"
    echo "============================"
    
    local backup_files=($(find "$ENCRYPTED_BACKUP_DIR" -name "*.tar.gz.enc" -type f | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        print_warning "No encrypted backups found"
        return 0
    fi
    
    printf "%-30s %-15s %-10s %s\n" "Backup File" "Date" "Size" "Backup Set"
    printf "%-30s %-15s %-10s %s\n" "$(printf '%.30s' '------------------------------')" "$(printf '%.15s' '---------------')" "$(printf '%.10s' '----------')" "----------"
    
    for backup_file in "${backup_files[@]}"; do
        local filename=$(basename "$backup_file")
        local backup_set=$(echo "$filename" | cut -d'-' -f1)
        local timestamp=$(echo "$filename" | cut -d'-' -f2- | sed 's/.tar.gz.enc$//')
        local size=$(ls -lh "$backup_file" | awk '{print $5}')
        local date_str=$(date -j -f "%Y%m%d_%H%M%S" "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp")
        
        printf "%-30s %-15s %-10s %s\n" "$filename" "$date_str" "$size" "$backup_set"
        
        # Show manifest info if available
        local manifest_file="${backup_file%.tar.gz.enc}.manifest"
        if [ -f "$manifest_file" ] && command -v jq >/dev/null 2>&1; then
            local description=$(jq -r '.backup_set' "$manifest_file" 2>/dev/null)
            local path_count=$(jq -r '.paths | length' "$manifest_file" 2>/dev/null)
            printf "  └─ %s (%s paths)\n" "$description" "$path_count"
        fi
    done
}

# Function to verify backup integrity
verify_backup_integrity() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    local manifest_file="${backup_file%.tar.gz.enc}.manifest"
    
    if [ ! -f "$manifest_file" ]; then
        print_warning "Manifest file not found for backup: $backup_file"
        return 1
    fi
    
    print_status "Verifying backup integrity: $(basename "$backup_file")"
    
    # Check file checksum
    local stored_checksum=$(jq -r '.checksum' "$manifest_file" 2>/dev/null)
    local current_checksum=$(shasum -a 256 "$backup_file" | cut -d' ' -f1)
    
    if [ "$stored_checksum" = "$current_checksum" ]; then
        print_success "Checksum verification passed"
    else
        print_error "Checksum verification failed!"
        print_error "Expected: $stored_checksum"
        print_error "Actual:   $current_checksum"
        return 1
    fi
    
    # Test decryption (without extracting)
    local backup_key=$(get_backup_key)
    if echo "$backup_key" | openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$backup_file" -out /dev/null -pass stdin 2>/dev/null; then
        print_success "Decryption test passed"
        log_backup "INFO" "Backup integrity verified: $backup_file"
        return 0
    else
        print_error "Decryption test failed"
        return 1
    fi
}

# Function to backup all configured sets
backup_all_sets() {
    create_backup_config
    
    print_status "Starting encrypted backup of all configured sets..."
    
    # Basic parsing without jq
    local backup_sets=("sensitive_configs" "development_secrets" "certificates")
    local total_backups=0
    local successful_backups=0
    
    for backup_set in "${backup_sets[@]}"; do
        print_status "Processing backup set: $backup_set"
        
        # Define paths for each backup set
        local paths=()
        case "$backup_set" in
            "sensitive_configs")
                paths=("$HOME/.ssh" "$HOME/.aws" "$HOME/.config/gh" "$HOME/.gitconfig")
                ;;
            "development_secrets")
                # Find .env files in GitHub directory
                while IFS= read -r -d '' env_file; do
                    paths+=("$env_file")
                done < <(find "$HOME/GitHub" -name ".env*" -type f -print0 2>/dev/null)
                ;;
            "certificates")
                # Find certificate files
                while IFS= read -r -d '' cert_file; do
                    paths+=("$cert_file")
                done < <(find "$HOME" -maxdepth 2 \( -name "*.pem" -o -name "*.key" -o -name "*.crt" \) -type f -print0 2>/dev/null)
                ;;
        esac
        
        # Filter existing paths
        local existing_paths=()
        for path in "${paths[@]}"; do
            if [ -e "$path" ]; then
                existing_paths+=("$path")
            fi
        done
        
        if [ ${#existing_paths[@]} -gt 0 ]; then
            if create_encrypted_archive "$backup_set" "${existing_paths[@]}"; then
                ((successful_backups++))
            fi
        else
            print_debug "No files found for backup set: $backup_set"
        fi
        
        ((total_backups++))
    done
    
    # Cleanup old backups
    cleanup_old_backups
    
    print_success "Encrypted backup completed: $successful_backups/$total_backups backup sets processed"
    log_backup "INFO" "Encrypted backup completed: $successful_backups/$total_backups sets successful"
    
    # Send notification
    send_notification "Encrypted Backup" "Completed $successful_backups/$total_backups backup sets"
}

# Function to show backup status
show_backup_status() {
    echo "Encrypted Backup System Status"
    echo "=============================="
    echo
    
    # Check if encryption key exists
    if [ -f "$BACKUP_KEY_FILE" ]; then
        print_success "Encryption key: Available"
    else
        print_warning "Encryption key: Not generated"
    fi
    
    # Check backup directory
    echo "Backup directory: $ENCRYPTED_BACKUP_DIR"
    if [ -d "$ENCRYPTED_BACKUP_DIR" ]; then
        local backup_count=$(find "$ENCRYPTED_BACKUP_DIR" -name "*.tar.gz.enc" -type f | wc -l)
        echo "Total backups: $backup_count"
        
        if [ $backup_count -gt 0 ]; then
            local total_size=$(du -sh "$ENCRYPTED_BACKUP_DIR" 2>/dev/null | cut -f1)
            echo "Total size: $total_size"
            
            # Show newest backup
            local newest_backup=$(find "$ENCRYPTED_BACKUP_DIR" -name "*.tar.gz.enc" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
            if [ -n "$newest_backup" ]; then
                local newest_date=$(stat -f%Sm -t"%Y-%m-%d %H:%M:%S" "$newest_backup" 2>/dev/null)
                echo "Latest backup: $(basename "$newest_backup") ($newest_date)"
            fi
        fi
    else
        print_warning "Backup directory does not exist"
    fi
    
    echo
    echo "Configuration file: $BACKUP_CONFIG_FILE"
    if [ -f "$BACKUP_CONFIG_FILE" ]; then
        print_success "Configuration: Available"
    else
        print_warning "Configuration: Not created"
    fi
}

# Main execution function
main() {
    print_status "Starting encrypted backup system..."
    
    # Check prerequisites
    if ! command -v openssl >/dev/null 2>&1; then
        print_error "OpenSSL is required for encryption"
        exit 1
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        print_error "tar is required for archiving"
        exit 1
    fi
    
    # Run backup for all configured sets
    backup_all_sets
    
    print_success "Encrypted backup system completed!"
    log_backup "INFO" "Encrypted backup system run completed"
}

# Handle command line arguments
case "${1:-}" in
    --backup-set)
        if [ -n "${2:-}" ]; then
            backup_set="$2"
            shift 2
            create_encrypted_archive "$backup_set" "$@"
        else
            print_error "Backup set name required"
            exit 1
        fi
        ;;
    --decrypt)
        if [ -n "${2:-}" ]; then
            decrypt_backup "$2" "${3:-}"
        else
            print_error "Encrypted backup file required"
            exit 1
        fi
        ;;
    --list)
        list_backups
        ;;
    --verify)
        if [ -n "${2:-}" ]; then
            verify_backup_integrity "$2"
        else
            print_error "Backup file required for verification"
            exit 1
        fi
        ;;
    --status)
        show_backup_status
        ;;
    --cleanup)
        cleanup_old_backups
        ;;
    --key)
        echo "Backup encryption key location: $BACKUP_KEY_FILE"
        if [ -f "$BACKUP_KEY_FILE" ]; then
            print_warning "Key exists. Keep this file secure!"
        else
            print_status "Key will be generated on first backup"
        fi
        ;;
    --help|-h)
        echo "Encrypted Backup System"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --backup-set NAME PATH...  Create encrypted backup of specific paths"
        echo "  --decrypt FILE [OUTPUT]    Decrypt backup file to output directory"
        echo "  --list                     List all available backups"
        echo "  --verify FILE              Verify backup integrity"
        echo "  --status                   Show backup system status"
        echo "  --cleanup                  Clean up old backups per retention policy"
        echo "  --key                      Show encryption key information"
        echo "  --help                     Show this help message"
        echo ""
        echo "Features:"
        echo "  - AES-256-CBC encryption with PBKDF2 key derivation"
        echo "  - Automatic backup sets for sensitive data"
        echo "  - Retention policy management"
        echo "  - Integrity verification with checksums"
        echo "  - Secure key management"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
