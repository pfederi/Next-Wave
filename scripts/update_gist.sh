#!/bin/bash

# Script to update GitHub Gist with Release Notes
# Usage: ./scripts/update_gist.sh

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📝 Updating Release Notes Gist...${NC}"

# Create a temporary file without the [Unreleased] section
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Remove the [Unreleased] section from RELEASE_NOTES.md
awk '
    /^## \[Unreleased\]/ { skip=1; next }
    /^## Version/ { skip=0 }
    !skip { print }
' RELEASE_NOTES.md > "$TEMP_FILE"

echo -e "${BLUE}✨ Removed [Unreleased] section from Gist upload${NC}"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it with: brew install gh"
    echo "Then authenticate with: gh auth login"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Gist ID (you need to set this after first creation)
GIST_ID="6350baf38ec57b4c80f1e7db52127a6f"

# If no Gist ID is set, create a new one
if [ -z "$GIST_ID" ]; then
    echo -e "${BLUE}Creating new Gist...${NC}"
    GIST_URL=$(gh gist create "$TEMP_FILE" --public --desc "NextWave App - Release History" --filename "RELEASE_NOTES.md" | grep -o 'https://gist.github.com/[^ ]*')
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gist created successfully!${NC}"
        echo -e "${GREEN}URL: $GIST_URL${NC}"
        
        # Extract Gist ID from URL
        GIST_ID=$(echo $GIST_URL | grep -o '[^/]*$')
        echo ""
        echo -e "${BLUE}💡 Add this line to the script to enable updates:${NC}"
        echo "GIST_ID=\"$GIST_ID\""
        echo ""
        echo -e "${BLUE}Raw URL for your website:${NC}"
        echo "https://gist.githubusercontent.com/pfederi/$GIST_ID/raw/RELEASE_NOTES.md"
    else
        echo -e "${RED}❌ Failed to create Gist${NC}"
        exit 1
    fi
else
    # Update existing Gist using GitHub API
    echo -e "${BLUE}Updating existing Gist (ID: $GIST_ID)...${NC}"
    
    # Read the temp file content
    CONTENT=$(cat "$TEMP_FILE" | jq -Rs .)
    
    # Update gist using GitHub API
    gh api \
        --method PATCH \
        -H "Accept: application/vnd.github+json" \
        "/gists/$GIST_ID" \
        -f "description=NextWave App - Release History" \
        --raw-field "files[RELEASE_NOTES.md][content]=$(cat "$TEMP_FILE")" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gist updated successfully!${NC}"
        echo -e "${GREEN}URL: https://gist.github.com/pfederi/$GIST_ID${NC}"
        echo ""
        echo -e "${BLUE}Raw URL for your website:${NC}"
        echo "https://gist.githubusercontent.com/pfederi/$GIST_ID/raw/RELEASE_NOTES.md"
    else
        echo -e "${RED}❌ Failed to update Gist${NC}"
        echo -e "${BLUE}Trying alternative method...${NC}"
        
        # Fallback: Use gh gist edit with file
        cp "$TEMP_FILE" /tmp/RELEASE_NOTES.md
        gh gist edit $GIST_ID /tmp/RELEASE_NOTES.md
        rm /tmp/RELEASE_NOTES.md
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Gist updated successfully (fallback method)!${NC}"
        else
            echo -e "${RED}❌ Both methods failed${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${GREEN}✨ Done!${NC}"
