#!/bin/bash

# GNOME Extensions Backup & Restore Script
# (c) 2026 Konstantin Adamov
#
# This script can save your installed GNOME extensions IDs and reinstall them later
# Only user extentions will be saved, system extentions will be skipped
#
# MIT License

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEFAULT_BACKUP_FILE="${SCRIPT_DIR}/gnome-extensions-backup.txt"
BACKUP_FILE="${DEFAULT_BACKUP_FILE}"
INSTALL_SCRIPT="/tmp/install-gnome-ext.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function show_help() {
    echo "GNOME Extensions Backup & Restore Tool"
    echo ""
    echo "Usage: $0 [OPTION] [FILE]"
    echo ""
    echo "Options:"
    echo "  save [FILE]       Save current user extensions to backup file"
    echo "  list              List all currently installed user extensions"
    echo "  install [FILE]    Automatically install extensions from backup file (requires internet)"
    echo "  help              Show this help message"
    echo ""
    echo "FILE: Optional path to backup file. If not provided, defaults to:"
    echo "      $DEFAULT_BACKUP_FILE"
    echo ""
    echo "Note: The 'list' command shows currently installed extensions (not backup file)."
    echo "      System extensions in /usr/share are automatically excluded."
    echo ""
    echo "Examples:"
    echo "  $0 save                          # Save to default file"
    echo "  $0 save my-extensions.txt        # Save to custom file in script directory"
    echo "  $0 save /tmp/backup.txt          # Save to absolute path"
    echo "  $0 list                          # Show all installed user extensions"
    echo "  $0 install                       # Install from default backup file"
    echo "  $0 install backup.txt            # Install from custom file"
}

function save_extensions() {
    echo -e "${YELLOW}Saving installed GNOME extensions...${NC}"
    
    if ! command -v gnome-extensions &> /dev/null; then
        echo -e "${RED}Error: gnome-extensions command not found${NC}"
        exit 1
    fi
    
    # Get list of user extensions only (skip system extensions)
    > "$BACKUP_FILE"  # Clear the file first
    
    while IFS= read -r extension_id; do
        # Check if extension is in user directory (not system)
        local ext_path=$(gnome-extensions info "$extension_id" 2>/dev/null | grep "Path:" | awk '{print $2}')
        
        # Skip if it's a system extension (in /usr/share)
        if [[ ! "$ext_path" =~ ^/usr/share ]]; then
            echo "$extension_id" >> "$BACKUP_FILE"
        fi
    done < <(gnome-extensions list)
    
    if [ $? -eq 0 ]; then
        local count=$(wc -l < "$BACKUP_FILE")
        echo -e "${GREEN}Successfully saved $count user extensions to: $BACKUP_FILE${NC}"
        echo ""
        echo "Extensions saved:"
        cat "$BACKUP_FILE"
    else
        echo -e "${RED}Error: Failed to save extensions${NC}"
        exit 1
    fi
}

function list_extensions() {
    if ! command -v gnome-extensions &> /dev/null; then
        echo -e "${RED}Error: gnome-extensions command not found${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Currently installed user GNOME extensions:${NC}"
    echo ""
    
    local count=0
    while IFS= read -r extension_id; do
        # Check if extension is in user directory (not system)
        local ext_path=$(gnome-extensions info "$extension_id" 2>/dev/null | grep "Path:" | awk '{print $2}')
        
        # Skip if it's a system extension (in /usr/share)
        if [[ "$ext_path" =~ ^/usr/share ]]; then
            continue
        fi
        
        count=$((count + 1))
        
        # Get extension state (active/inactive)
        if gnome-extensions info "$extension_id" 2>/dev/null | grep -q "State: ACTIVE"; then
            status="${GREEN}[ACTIVE]${NC}"
        else
            status="${RED}[INACTIVE]${NC}"
        fi
        
        echo -e "$count. $extension_id $status"
    done < <(gnome-extensions list)
    
    echo ""
    echo -e "Total: $count user extensions"
}

function install_extensions() {
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
        echo "Run '$0 save' first to create a backup."
        exit 1
    fi
    
    echo -e "${YELLOW}Installing GNOME extensions from backup...${NC}"
    
    # Get and show current GNOME Shell version
    GNOME_VERSION=$(gnome-shell --version 2>/dev/null | cut -d' ' -f3)
    if [ -n "$GNOME_VERSION" ]; then
        echo -e "GNOME Shell version: ${GREEN}$GNOME_VERSION${NC}"
    fi
    echo ""
    
    # Check for required tools
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed${NC}"
        exit 1
    fi
    
    # Create installation helper script
    cat > "$INSTALL_SCRIPT" << 'INSTALL_EOF'
#!/bin/bash
EXTENSION_ID="$1"
GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)

# Get extension info from extensions.gnome.org
INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${EXTENSION_ID}&shell_version=${GNOME_VERSION}"
EXTENSION_INFO=$(curl -s "$INFO_URL")

# Check if extension exists at all
if [ -z "$EXTENSION_INFO" ]; then
    echo "  ✗ Extension not found on extensions.gnome.org"
    return 1
fi

# Check for error response (extension doesn't support this version)
if echo "$EXTENSION_INFO" | grep -q '"error"'; then
    # Try to get info about available versions
    ALL_INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${EXTENSION_ID}"
    ALL_INFO=$(curl -s "$ALL_INFO_URL")
    
    if [ -n "$ALL_INFO" ] && ! echo "$ALL_INFO" | grep -q '"error"'; then
        # Extract shell versions map to show supported versions
        SUPPORTED_VERSIONS=$(echo "$ALL_INFO" | grep -o '"[0-9][0-9]*":' | tr -d '":' | sort -n | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$SUPPORTED_VERSIONS" ]; then
            echo "  ✗ Not compatible with GNOME Shell $GNOME_VERSION"
            echo "    Supported versions: $SUPPORTED_VERSIONS"
        else
            echo "  ✗ Not compatible with GNOME Shell $GNOME_VERSION"
        fi
    else
        echo "  ✗ Extension not found or not compatible with GNOME Shell $GNOME_VERSION"
    fi
    return 1
fi

DOWNLOAD_URL=$(echo "$EXTENSION_INFO" | grep -o '"download_url":"[^"]*' | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ✗ No download URL available for GNOME Shell $GNOME_VERSION"
    return 1
fi

DOWNLOAD_URL="https://extensions.gnome.org${DOWNLOAD_URL}"

# Download and install
TEMP_DIR=$(mktemp -d)
ZIP_FILE="${TEMP_DIR}/extension.zip"

curl -s -L "$DOWNLOAD_URL" -o "$ZIP_FILE"

if [ ! -f "$ZIP_FILE" ]; then
    echo "  ✗ Download failed"
    rm -rf "$TEMP_DIR"
    return 1
fi

# Install the extension
gnome-extensions install --force "$ZIP_FILE" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "  ✓ Installed successfully"
    rm -rf "$TEMP_DIR"
    return 0
else
    echo "  ✗ Installation failed"
    rm -rf "$TEMP_DIR"
    return 1
fi
INSTALL_EOF
    
    chmod +x "$INSTALL_SCRIPT"
    
    # Install each extension
    local success=0
    local failed=0
    local total=$(wc -l < "$BACKUP_FILE")
    local current=0
    
    while IFS= read -r extension_id; do
        current=$((current + 1))
        echo -e "${YELLOW}[$current/$total]${NC} Installing: $extension_id"
        
        # Check if already installed
        if gnome-extensions info "$extension_id" &>/dev/null; then
            echo "  ℹ Already installed (skipping)"
            success=$((success + 1))
            continue
        fi
        
        bash "$INSTALL_SCRIPT" "$extension_id"
        if [ $? -eq 0 ]; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done < "$BACKUP_FILE"
    
    # Cleanup
    rm -f "$INSTALL_SCRIPT"
    
    # Summary
    echo "================================"
    echo -e "${GREEN}Installation complete!${NC}"
    echo "Total: $total"
    echo -e "${GREEN}Success: $success${NC}"
    if [ $failed -gt 0 ]; then
        echo -e "${RED}Failed: $failed${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Note: You may need to restart GNOME Shell (Alt+F2, type 'r', press Enter)${NC}"
    echo -e "${YELLOW}      or log out and log back in for extensions to appear.${NC}"
}

# Main script logic
COMMAND="${1:-help}"
CUSTOM_FILE="${2}"

# If a custom file is provided, resolve its path
if [ -n "$CUSTOM_FILE" ]; then
    # If it's not an absolute path, make it relative to script directory
    if [[ "$CUSTOM_FILE" != /* ]]; then
        BACKUP_FILE="${SCRIPT_DIR}/${CUSTOM_FILE}"
    else
        BACKUP_FILE="$CUSTOM_FILE"
    fi
fi

case "$COMMAND" in
    save)
        save_extensions
        ;;
    list)
        list_extensions
        ;;
    install)
        install_extensions
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Error: Unknown option '$COMMAND'${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
