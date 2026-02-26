#!/bin/bash
# Setup script to clone/update libraries for local development.
# Usage:
#   ./setup-libs.sh           - Clone/check out all libraries
#   ./setup-libs.sh -u        - Update all libraries
#   ./setup-libs.sh -c        - Clean up local libraries

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/Libs"

# Define libraries as associative array
declare -A LIBRARIES=(
    [LibStub]="https://github.com/zerosnake0/LibStub.git"
    [CallbackHandler-1.0]="https://github.com/zerosnake0/CallbackHandler-1.0.git"
    [LibDataBroker-1.1]="https://github.com/tekkub/libdatabroker-1-1.git"
    [LibDBIcon-1.0]="https://github.com/zerosnake0/LibDBIcon-1.0.git"
    [Ace3]="https://github.com/WoWUIDev/Ace3.git"
)

UPDATE=false
CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--update)
            UPDATE=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            echo "Setup script to manage local libraries for development"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -u, --update    Update all existing libraries"
            echo "  -c, --clean     Remove all local libraries"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed"
    echo "Please install Git from https://git-scm.com/"
    exit 1
fi

# Create Libs directory if it doesn't exist
if [ ! -d "$LIB_DIR" ]; then
    echo "Creating $LIB_DIR directory..."
    mkdir -p "$LIB_DIR"
fi

if [ "$CLEAN" = true ]; then
    echo "Cleaning up local libraries..."
    for lib in "${!LIBRARIES[@]}"; do
        lib_path="$LIB_DIR/$lib"
        if [ -d "$lib_path" ]; then
            echo "Removing $lib..."
            rm -rf "$lib_path"
            echo "✓ Removed $lib"
        fi
    done
    echo "Cleanup complete!"
else
    echo "Setting up local libraries..."
    if [ "$UPDATE" = true ]; then
        echo "(Update mode enabled)"
    fi
    
    for lib in "${!LIBRARIES[@]}"; do
        lib_path="$LIB_DIR/$lib"
        lib_url="${LIBRARIES[$lib]}"
        
        if [ -d "$lib_path" ]; then
            if [ "$UPDATE" = true ]; then
                echo "Updating $lib..."
                cd "$lib_path"
                git pull --quiet
                cd - > /dev/null
                echo "✓ Updated $lib"
            else
                echo "✓ $lib already exists"
            fi
        else
            echo "Cloning $lib..."
            git clone --quiet "$lib_url" "$lib_path"
            echo "✓ Cloned $lib"
        fi
    done
    
    echo "Setup complete!"
fi
