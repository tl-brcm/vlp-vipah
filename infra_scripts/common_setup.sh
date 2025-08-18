#!/usr/bin/env bash
# This script is meant to be sourced by other scripts.

set -euo pipefail

# ===== Common Setup: Basics & Packages =====
echo "Updating package list..."
sudo apt-get update -y

echo "Installing common prerequisite packages..."
sudo apt-get install -y curl ca-certificates gnupg lsb-release bash-completion net-tools jq nmap
