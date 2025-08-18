#!/usr/bin/env bash
set -euo pipefail

# ===== 0) Common Setup =====
# Source the common setup script for package installation
source "$(dirname "$0")/common_setup.sh"

# This script assumes you have passwordless SSH access (key-based authentication)
# from this worker node to the master node.

read -p "Enter the username for the master node (e.g., 'ubuntu'): " MASTER_USER
if [ -z "$MASTER_USER" ]; then
  echo "Master node username cannot be empty."
  exit 1
fi

# ===== 1) Discover K3s Master Node =====
echo "Scanning for K3s master on the local network (port 6443)..."
# Get this node's primary IP and subnet
NODE_IP=$(hostname -I | awk '{print $1}')
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)

if [ -z "$SUBNET" ]; then
    echo "Could not determine subnet. Please ensure the node has a configured network interface."
    exit 1
fi

# Scan the subnet for the k3s API server port
MASTER_IP=$(nmap -p 6443 --open ${SUBNET} -n | awk '/Nmap scan report for/{print $5}' | head -n 1)

if [ -z "$MASTER_IP" ]; then
  echo "Could not find a K3s master node on the network."
  echo "Please ensure the master node is running and accessible on port 6443."
  exit 1
fi

echo "Found K3s master at: ${MASTER_IP}"

# ===== 2) Retrieve Join Token from Master =====
echo "Fetching cluster token from master node..."
TOKEN_FILE="/tmp/node-token"
if ! scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${MASTER_USER}@${MASTER_IP}:/var/lib/rancher/k3s/server/node-token" "${TOKEN_FILE}"; then
    echo "Failed to retrieve token from master."
    echo "Please verify the username ('${MASTER_USER}') and ensure passwordless SSH is configured."
    exit 1
fi

K3S_TOKEN=$(cat "${TOKEN_FILE}")
rm "${TOKEN_FILE}" # Clean up the token file immediately

if [ -z "$K3S_TOKEN" ]; then
    echo "Token retrieved from master was empty. Cannot join cluster."
    exit 1
fi

echo "Successfully retrieved cluster token."

# ===== 3) Install k3s Agent =====
echo "Installing k3s agent and joining the cluster..."
export K3S_URL="https://{MASTER_IP}:6443"
export K3S_TOKEN
export INSTALL_K3S_CHANNEL=stable

curl -sfL https://get.k3s.io | sh -

# ===== 4) Verification =====
echo "Waiting for 15 seconds for the agent to register..."
sleep 15

echo "✅ Worker node installation complete."
echo "Run 'kubectl get nodes' on the master node to verify that this node has joined the cluster."
