#!/bin/bash

# Exit on error
set -e

# Check if we're in the wp-content/plugins directory
if [[ $(basename "$PWD") != "plugins" || $(basename "$(dirname "$PWD")") != "wp-content" ]]; then
  echo "Error: This script must be run from the wp-content/plugins directory"
  exit 1
fi

# Check if git repo exists
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Check if wp-cli is installed
if ! command -v wp > /dev/null 2>&1; then
  echo "Error: WP-CLI is not installed. Please install it first."
  exit 1
fi

echo "=== Starting WordPress plugin updates ==="

# Read .gitignore file from the repository root
GIT_ROOT=$(git rev-parse --show-toplevel)
GITIGNORE_FILE="$GIT_ROOT/.gitignore"

if [ ! -f "$GITIGNORE_FILE" ]; then
  echo "Warning: .gitignore file not found at $GITIGNORE_FILE"
  IGNORED_PLUGINS=""
else
  # Extract plugin names from .gitignore file
  # Skipping lines that start with ** or other git patterns
  IGNORED_PLUGINS=$(grep -v "^\*\*/" "$GITIGNORE_FILE" | grep -v "^$" | grep -v "^#")
  
  if [ -n "$IGNORED_PLUGINS" ]; then
    echo "The following plugins will be skipped based on .gitignore:"
    echo "$IGNORED_PLUGINS"
    echo ""
  fi
fi

# Get list of plugins that have updates available
PLUGINS_TO_UPDATE=$(wp plugin list --update=available --field=name 2>/dev/null)

if [ -z "$PLUGINS_TO_UPDATE" ]; then
  echo "No plugins require updates. Exiting."
  exit 0
fi

echo "Found plugins requiring updates:"
echo "$PLUGINS_TO_UPDATE"
echo ""

# Update each plugin and commit if successful
for PLUGIN in $PLUGINS_TO_UPDATE; do
  # Check if the plugin is in the ignore list
  if echo "$IGNORED_PLUGINS" | grep -q "^$PLUGIN$"; then
    echo "Skipping ignored plugin: $PLUGIN"
    echo ""
    continue
  fi
  
  echo "Updating plugin: $PLUGIN"
  
  # Get current version before update
  CURRENT_VERSION=$(wp plugin get $PLUGIN --field=version)
  
  if wp plugin update $PLUGIN; then
    # Get new version after update
    NEW_VERSION=$(wp plugin get $PLUGIN --field=version)
    
    echo "Successfully updated $PLUGIN from v$CURRENT_VERSION to v$NEW_VERSION"
    
    # Add to git and commit
    git add -A
    git commit -m "Update plugin: $PLUGIN from v$CURRENT_VERSION to v$NEW_VERSION"
    echo "Committed update for $PLUGIN"
    echo ""
  else
    echo "Failed to update plugin: $PLUGIN. Skipping commit."
    echo ""
  fi
done

# Push changes to remote repository
echo "Pushing changes to remote repository..."
git push

echo "=== WordPress plugin update process completed ==="
