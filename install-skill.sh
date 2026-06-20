#!/bin/bash
# install-skill.sh - Runs the shipready skill installer for Linux/macOS users
# Usage: ./install-skill.sh [args]

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Run the node-based skill installer with any arguments passed
node "$DIR/bin/install.js" "$@"
