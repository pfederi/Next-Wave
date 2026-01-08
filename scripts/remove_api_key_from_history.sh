#!/bin/bash

# Script to remove API key from Git history
# ⚠️ WARNING: This rewrites Git history!

echo "⚠️  This will rewrite Git history to remove Config.swift"
echo "⚠️  Make sure all team members are aware!"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "🔄 Removing Config.swift from Git history..."

# Use git filter-repo (recommended) or filter-branch
if command -v git-filter-repo &> /dev/null; then
    git filter-repo --path "Next Wave/Config.swift" --invert-paths --force
else
    echo "⚠️  git-filter-repo not found. Using filter-branch (slower)..."
    git filter-branch --force --index-filter \
        "git rm --cached --ignore-unmatch 'Next Wave/Config.swift'" \
        --prune-empty --tag-name-filter cat -- --all
fi

echo "✅ Config.swift removed from history"
echo ""
echo "Next steps:"
echo "1. Force push to remote: git push origin --force --all"
echo "2. Regenerate your OpenWeather API key at https://openweathermap.org/api"
echo "3. Update Config.swift locally with new key"
