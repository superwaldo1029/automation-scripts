#!/bin/bash

# Security Scanner & Secrets Detection
# Enhances the project backup system with security scanning capabilities

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Configuration
SECURITY_REPORT_DIR="$HOME/.local/backup/security"
SECRETS_PATTERNS_FILE="$SCRIPT_DIR/secrets-patterns.txt"
SECURITY_LOG="$HOME/.local/log/automation/security.log"
QUARANTINE_DIR="$HOME/.local/quarantine"

# Create directories
mkdir -p "$SECURITY_REPORT_DIR" "$QUARANTINE_DIR"
mkdir -p "$(dirname "$SECURITY_LOG")"

log_security() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$SECURITY_LOG"
}

# Function to create secrets detection patterns
create_secrets_patterns() {
    cat > "$SECRETS_PATTERNS_FILE" << 'EOF'
# API Keys and Tokens
[aA][pP][iI][_-]?[kK][eE][yY].*['\"][0-9a-zA-Z]{20,}['\"]
[aA][cC][cC][eE][sS][sS][_-]?[tT][oO][kK][eE][nN].*['\"][0-9a-zA-Z]{20,}['\"]
[sS][eE][cC][rR][eE][tT][_-]?[kK][eE][yY].*['\"][0-9a-zA-Z]{20,}['\"]
[pP][rR][iI][vV][aA][tT][eE][_-]?[kK][eE][yY].*['\"][0-9a-zA-Z]{20,}['\"]

# AWS Keys
AKIA[0-9A-Z]{16}
[aA][wW][sS][_-]?[aA][cC][cC][eE][sS][sS][_-]?[kK][eE][yY][_-]?[iI][dD].*['\"][A-Z0-9]{20}['\"]
[aA][wW][sS][_-]?[sS][eE][cC][rR][eE][tT][_-]?[aA][cC][cC][eE][sS][sS][_-]?[kK][eE][yY].*['\"][0-9a-zA-Z/+=]{40}['\"]

# GitHub Tokens
ghp_[0-9a-zA-Z]{36}
gho_[0-9a-zA-Z]{36}
ghu_[0-9a-zA-Z]{36}
ghs_[0-9a-zA-Z]{36}
ghr_[0-9a-zA-Z]{36}

# SSH Private Keys
-----BEGIN RSA PRIVATE KEY-----
-----BEGIN DSA PRIVATE KEY-----
-----BEGIN EC PRIVATE KEY-----
-----BEGIN PGP PRIVATE KEY BLOCK-----
-----BEGIN OPENSSH PRIVATE KEY-----

# Database URLs
mysql://[a-zA-Z0-9]+:[a-zA-Z0-9]+@[a-zA-Z0-9.-]+
postgresql://[a-zA-Z0-9]+:[a-zA-Z0-9]+@[a-zA-Z0-9.-]+
mongodb://[a-zA-Z0-9]+:[a-zA-Z0-9]+@[a-zA-Z0-9.-]+

# JWT Tokens
eyJ[0-9a-zA-Z_-]+\.eyJ[0-9a-zA-Z_-]+\.[0-9a-zA-Z_-]+

# Generic Secrets (more permissive)
[pP]assword['\"]?\s*[:=]\s*['\"][^'\"]{8,}['\"]
[tT]oken['\"]?\s*[:=]\s*['\"][^'\"]{16,}['\"]
[kK]ey['\"]?\s*[:=]\s*['\"][^'\"]{16,}['\"]

# Environment Variables
[A-Z][A-Z0-9_]*_KEY=.*
[A-Z][A-Z0-9_]*_SECRET=.*
[A-Z][A-Z0-9_]*_TOKEN=.*
[A-Z][A-Z0-9_]*_PASSWORD=.*
EOF
}

# Function to scan for secrets in a repository
scan_secrets() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local secrets_found=()
    
    if ! is_git_repo "$repo_path"; then
        return 1
    fi
    
    print_status "Scanning $repo_name for secrets..."
    
    # Create patterns file if it doesn't exist
    if [ ! -f "$SECRETS_PATTERNS_FILE" ]; then
        create_secrets_patterns
    fi
    
    cd "$repo_path"
    
    # Scan files for secrets patterns
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        [[ "$pattern" =~ ^#.*$ ]] || [[ -z "$pattern" ]] && continue
        
        # Search for pattern in files
        local matches=$(grep -r -E "$pattern" . \
            --exclude-dir=.git \
            --exclude-dir=node_modules \
            --exclude-dir=.venv \
            --exclude-dir=venv \
            --exclude-dir=__pycache__ \
            --exclude="*.log" \
            --exclude="*.tmp" \
            2>/dev/null || true)
        
        if [ -n "$matches" ]; then
            secrets_found+=("$matches")
        fi
    done < "$SECRETS_PATTERNS_FILE"
    
    # Check git history for secrets (last 10 commits)
    local git_secrets=$(git log --all --full-history -p -10 | grep -E -f "$SECRETS_PATTERNS_FILE" 2>/dev/null || true)
    if [ -n "$git_secrets" ]; then
        secrets_found+=("GIT_HISTORY: $git_secrets")
    fi
    
    # Report findings
    if [ ${#secrets_found[@]} -gt 0 ]; then
        log_security "WARNING" "Potential secrets found in $repo_name"
        printf '%s\n' "${secrets_found[@]}"
        return 1
    else
        log_security "INFO" "No secrets detected in $repo_name"
        return 0
    fi
}

# Function to check file permissions and security
check_file_security() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local security_issues=()
    
    print_status "Checking file security for $repo_name..."
    
    cd "$repo_path"
    
    # Check for world-writable files
    local writable_files=$(find . -type f -perm -002 2>/dev/null | grep -v ".git" || true)
    if [ -n "$writable_files" ]; then
        security_issues+=("WORLD_WRITABLE_FILES: $writable_files")
    fi
    
    # Check for executable files that shouldn't be
    local suspicious_executables=$(find . -name "*.txt" -o -name "*.md" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" | xargs ls -l | grep "^-rwx" || true)
    if [ -n "$suspicious_executables" ]; then
        security_issues+=("SUSPICIOUS_EXECUTABLES: $suspicious_executables")
    fi
    
    # Check for hidden files that might contain secrets
    local hidden_files=$(find . -name ".*" -type f ! -path "./.git/*" | grep -E "\.(env|key|pem|p12|pfx)$" || true)
    if [ -n "$hidden_files" ]; then
        security_issues+=("HIDDEN_CREDENTIAL_FILES: $hidden_files")
    fi
    
    # Check for large files that might be binaries
    local large_files=$(find . -type f -size +10M ! -path "./.git/*" 2>/dev/null || true)
    if [ -n "$large_files" ]; then
        security_issues+=("LARGE_FILES: $large_files")
    fi
    
    # Report findings
    if [ ${#security_issues[@]} -gt 0 ]; then
        log_security "WARNING" "Security issues found in $repo_name"
        printf '%s\n' "${security_issues[@]}"
        return 1
    else
        log_security "INFO" "No file security issues in $repo_name"
        return 0
    fi
}

# Function to scan dependencies for vulnerabilities
scan_dependencies() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local vulnerabilities=()
    
    print_status "Scanning dependencies for $repo_name..."
    
    cd "$repo_path"
    
    # Check for package.json (Node.js)
    if [ -f "package.json" ]; then
        if command -v npm >/dev/null 2>&1; then
            local npm_audit=$(npm audit --audit-level=moderate 2>/dev/null || echo "npm audit failed")
            if [[ "$npm_audit" != *"found 0 vulnerabilities"* ]] && [[ "$npm_audit" != "npm audit failed" ]]; then
                vulnerabilities+=("NPM_VULNERABILITIES: $npm_audit")
            fi
        fi
    fi
    
    # Check for requirements.txt (Python)
    if [ -f "requirements.txt" ]; then
        if command -v pip >/dev/null 2>&1; then
            # Check for known vulnerable packages
            local known_vulnerable=("django<3.0" "requests<2.20" "pillow<6.2.0" "jinja2<2.10.1")
            for package in "${known_vulnerable[@]}"; do
                if grep -q "$package" requirements.txt 2>/dev/null; then
                    vulnerabilities+=("PYTHON_VULNERABLE_PACKAGE: $package found in requirements.txt")
                fi
            done
        fi
    fi
    
    # Check for Gemfile (Ruby)
    if [ -f "Gemfile" ]; then
        if command -v bundle >/dev/null 2>&1; then
            local bundle_audit=$(bundle audit 2>/dev/null || echo "bundle audit failed")
            if [[ "$bundle_audit" != *"No vulnerabilities found"* ]] && [[ "$bundle_audit" != "bundle audit failed" ]]; then
                vulnerabilities+=("RUBY_VULNERABILITIES: $bundle_audit")
            fi
        fi
    fi
    
    # Report findings
    if [ ${#vulnerabilities[@]} -gt 0 ]; then
        log_security "WARNING" "Dependency vulnerabilities found in $repo_name"
        printf '%s\n' "${vulnerabilities[@]}"
        return 1
    else
        log_security "INFO" "No dependency vulnerabilities in $repo_name"
        return 0
    fi
}

# Function to create file integrity checksums
create_file_checksums() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local checksum_file="$SECURITY_REPORT_DIR/${repo_name}-checksums.sha256"
    
    print_status "Creating file integrity checksums for $repo_name..."
    
    cd "$repo_path"
    
    # Create checksums for important files
    find . -type f ! -path "./.git/*" ! -name "*.log" ! -name "*.tmp" -exec sha256sum {} \; > "$checksum_file" 2>/dev/null
    
    log_security "INFO" "File checksums created for $repo_name: $checksum_file"
}

# Function to verify file integrity
verify_file_integrity() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local checksum_file="$SECURITY_REPORT_DIR/${repo_name}-checksums.sha256"
    local integrity_issues=()
    
    if [ ! -f "$checksum_file" ]; then
        print_debug "No previous checksums found for $repo_name"
        return 0
    fi
    
    print_status "Verifying file integrity for $repo_name..."
    
    cd "$repo_path"
    
    # Check each file's integrity
    while IFS= read -r line; do
        local expected_hash=$(echo "$line" | cut -d' ' -f1)
        local file_path=$(echo "$line" | cut -d' ' -f3-)
        
        if [ -f "$file_path" ]; then
            local current_hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1)
            if [ "$expected_hash" != "$current_hash" ]; then
                integrity_issues+=("MODIFIED: $file_path")
            fi
        else
            integrity_issues+=("DELETED: $file_path")
        fi
    done < "$checksum_file"
    
    # Check for new files
    local new_files=$(find . -type f ! -path "./.git/*" ! -name "*.log" ! -name "*.tmp" -newer "$checksum_file" 2>/dev/null || true)
    if [ -n "$new_files" ]; then
        while IFS= read -r file; do
            integrity_issues+=("NEW: $file")
        done <<< "$new_files"
    fi
    
    # Report findings
    if [ ${#integrity_issues[@]} -gt 0 ]; then
        log_security "INFO" "File changes detected in $repo_name (this may be normal)"
        printf '%s\n' "${integrity_issues[@]}"
        return 1
    else
        log_security "INFO" "File integrity verified for $repo_name"
        return 0
    fi
}

# Function to quarantine suspicious files
quarantine_file() {
    local file_path="$1"
    local reason="$2"
    local quarantine_subdir="$QUARANTINE_DIR/$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$quarantine_subdir"
    
    if [ -f "$file_path" ]; then
        cp "$file_path" "$quarantine_subdir/"
        echo "$reason" > "$quarantine_subdir/$(basename "$file_path").reason"
        log_security "WARNING" "File quarantined: $file_path -> $quarantine_subdir (Reason: $reason)"
        
        # Optionally remove the original (commented out for safety)
        # rm "$file_path"
        
        return 0
    else
        log_security "ERROR" "Cannot quarantine non-existent file: $file_path"
        return 1
    fi
}

# Function to generate security report
generate_security_report() {
    local repos=("$@")
    local report_file="$SECURITY_REPORT_DIR/security-report-$(date +%Y%m%d_%H%M%S).md"
    local total_repos=${#repos[@]}
    local repos_with_secrets=0
    local repos_with_security_issues=0
    local repos_with_vulnerabilities=0
    
    print_status "Generating security report..."
    
    cat > "$report_file" << 'EOF'
# Security Scan Report

Generated: $(date)

## Executive Summary

This report contains the results of security scanning performed on all repositories.

## Repositories Scanned

| Repository | Secrets | File Security | Dependencies | Integrity |
|------------|---------|---------------|--------------|-----------|
EOF
    
    # Scan each repository
    for repo in "${repos[@]}"; do
        local repo_name=$(basename "$repo")
        local secrets_status="✅"
        local security_status="✅"
        local deps_status="✅"
        local integrity_status="✅"
        
        # Scan for secrets
        if ! scan_secrets "$repo" >/dev/null 2>&1; then
            secrets_status="⚠️"
            ((repos_with_secrets++))
        fi
        
        # Check file security
        if ! check_file_security "$repo" >/dev/null 2>&1; then
            security_status="⚠️"
            ((repos_with_security_issues++))
        fi
        
        # Scan dependencies
        if ! scan_dependencies "$repo" >/dev/null 2>&1; then
            deps_status="⚠️"
            ((repos_with_vulnerabilities++))
        fi
        
        # Verify integrity
        if ! verify_file_integrity "$repo" >/dev/null 2>&1; then
            integrity_status="ℹ️"
        fi
        
        # Update checksums for next run
        create_file_checksums "$repo"
        
        echo "| $repo_name | $secrets_status | $security_status | $deps_status | $integrity_status |" >> "$report_file"
    done
    
    # Add summary statistics
    cat >> "$report_file" << EOF

## Summary Statistics

- **Total Repositories Scanned**: $total_repos
- **Repositories with Potential Secrets**: $repos_with_secrets
- **Repositories with Security Issues**: $repos_with_security_issues
- **Repositories with Vulnerable Dependencies**: $repos_with_vulnerabilities

## Legend

- ✅ No issues detected
- ⚠️ Issues found - requires attention
- ℹ️ Changes detected (informational)

## Recommendations

### If Secrets Were Found:
1. Immediately rotate any exposed credentials
2. Remove secrets from git history using tools like BFG Repo-Cleaner
3. Move secrets to environment variables or secure vaults
4. Add secrets to .gitignore

### If Security Issues Were Found:
1. Fix file permissions (remove world-writable access)
2. Review executable permissions on non-executable files
3. Move credential files outside of repository
4. Consider using .gitignore for sensitive file patterns

### If Vulnerabilities Were Found:
1. Update vulnerable dependencies to latest secure versions
2. Review security advisories for affected packages
3. Consider using dependency security scanning in CI/CD

## Security Best Practices

1. **Never commit secrets**: Use environment variables or secret management
2. **Regular scanning**: Run security scans on every commit
3. **Dependency updates**: Keep dependencies updated
4. **Access control**: Limit repository access to necessary personnel
5. **File permissions**: Follow principle of least privilege

---

*Report generated by Security Scanner - $(date)*
EOF
    
    print_success "Security report generated: $report_file"
    log_security "INFO" "Security report generated for $total_repos repositories"
    
    # Send notification if critical issues found
    if [ $repos_with_secrets -gt 0 ] || [ $repos_with_security_issues -gt 0 ]; then
        send_notification "Security Alert" "Security issues found in $((repos_with_secrets + repos_with_security_issues)) repositories"
    fi
}

# Function to find all git repositories (reuse from main script)
find_git_repos() {
    local search_dirs=("$HOME/GitHub" "$HOME/dotfiles")
    local repos=()
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' repo; do
                repos+=($(dirname "$repo"))
            done < <(find "$dir" -type d -name ".git" -print0 2>/dev/null)
        fi
    done
    
    printf '%s\n' "${repos[@]}"
}

# Main execution function
main() {
    print_status "Starting security scan..."
    
    # Create patterns file
    create_secrets_patterns
    
    # Find all repositories
    local repos=($(find_git_repos))
    
    if [ ${#repos[@]} -eq 0 ]; then
        print_warning "No git repositories found"
        exit 0
    fi
    
    print_status "Scanning ${#repos[@]} repositories for security issues..."
    
    # Generate security report
    generate_security_report "${repos[@]}"
    
    print_success "Security scan completed!"
    log_security "INFO" "Security scan completed for ${#repos[@]} repositories"
}

# Handle command line arguments
case "${1:-}" in
    --repo)
        if [ -n "${2:-}" ] && [ -d "$2" ]; then
            print_status "Scanning specific repository: $2"
            scan_secrets "$2"
            check_file_security "$2"
            scan_dependencies "$2"
            verify_file_integrity "$2"
            create_file_checksums "$2"
        else
            print_error "Repository path required and must exist"
            exit 1
        fi
        ;;
    --secrets)
        repos=($(find_git_repos))
        for repo in "${repos[@]}"; do
            scan_secrets "$repo"
        done
        ;;
    --integrity)
        repos=($(find_git_repos))
        for repo in "${repos[@]}"; do
            verify_file_integrity "$repo"
        done
        ;;
    --help|-h)
        echo "Security Scanner for Project Backup"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --repo PATH    Scan specific repository"
        echo "  --secrets      Scan all repositories for secrets only"
        echo "  --integrity    Check file integrity for all repositories"
        echo "  --help         Show this help message"
        echo ""
        echo "Features:"
        echo "  - Secrets detection in code and git history"
        echo "  - File permission and security checks"
        echo "  - Dependency vulnerability scanning"
        echo "  - File integrity monitoring"
        echo "  - Comprehensive security reporting"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
