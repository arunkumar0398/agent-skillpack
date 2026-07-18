#!/bin/bash
# Script to push agent-skillpack to GitHub
# Run this after authenticating with: gh auth login

set -e

REPO_NAME="agent-skillpack"
DESCRIPTION="Universal AI agent skill pack — 68+ engineering skills compatible with 8 coding agents"

echo "Creating GitHub repository..."
"C:/Users/sivaa/AppData/Local/Temp/gh/bin/gh.exe" repo create "$REPO_NAME" --public --description "$DESCRIPTION" --source=. --remote=origin --push

echo "Done! Repository created at: https://github.com/sivaa/$REPO_NAME"
