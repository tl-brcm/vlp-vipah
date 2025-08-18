#!/usr/bin/env bash
set -euo pipefail

# ===== 0) Common Setup =====
# Source the common setup script for package installation
source "$(dirname "$0")/common_setup.sh"

# ===== 1) Install kubectl (stable series) =====
# Docs: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# Pick the current stable series (adjust if you want a specific minor)
KUBERNETES_SERIES="v1.33"  # stays within one minor of k3s stable
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_SERIES}/deb/Release.key" \
 | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_SERIES}/deb/ /" \
 | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y kubectl

# ===== 2) Install Helm (official script) =====
# Docs: https://helm.sh/docs/intro/install/
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ===== 3) Install k3s (latest stable), disable Traefik & ServiceLB =====
# Docs/flags come from the official install script (INSTALL_K3S_CHANNEL, --write-kubeconfig-mode, etc.)
NODE_IP="$(hostname -I | awk '{print $1}')"
export INSTALL_K3S_CHANNEL=stable
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --disable=traefik \
  --node-ip "${NODE_IP}"

# ===== 4) Prepare kubeconfig for your user =====
mkdir -p "${HOME}/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/k3s.yaml"
sudo chown "$USER:$USER" "${HOME}/.kube/k3s.yaml"
# Replace 127.0.0.1 with the actual node IP so kubectl works from anywhere
sed -i "s/127.0.0.1/${NODE_IP}/" "${HOME}/.kube/k3s.yaml"
export KUBECONFIG="${HOME}/.kube/k3s.yaml"

# ===== 5) Shell QoL: completions & aliases & krew =====
# These are appended once; re-run is safe.
BASHRC_SNIPPET='
# --- k8s helpers ---
export KUBECONFIG=$HOME/.kube/k3s.yaml
source <(kubectl completion bash)
alias k="kubectl"
complete -o default -F __start_kubectl k

alias h="helm"
source <(helm completion bash)
complete -o default -F __start_helm h

# krew (kubectl plugin manager)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
alias ks="kubens"
alias kx="kubectx"

# handy aliases
alias kp="kubectl get pods"
alias kpw="kp -w"
alias ke="kubectl get events"
'
grep -q "k8s helpers" ~/.bashrc || printf "%s\n" "$BASHRC_SNIPPET" >> ~/.bashrc

# Install krew + ctx/ns plugins (official method)
# Docs: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
(
  set -x
  cd "$(mktemp -d)"
  OS="$(uname | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
  KREW="krew-${OS}_${ARCH}"
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
  tar zxvf "${KREW}.tar.gz"
  ./"${KREW}" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
kubectl krew install ctx ns

# Append krew path and aliases to .bashrc if not already present
{
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"'
    echo 'alias kubectx="kubectl ctx"'
    echo 'alias kubens="kubectl ns"'
    echo 'alias kx="kubectl ctx"'
    echo 'alias ks="kubectl ns"'
} >> ~/.bashrc

echo "✅ Krew path and aliases added to ~/.bashrc"
echo "ℹ️  Run 'source ~/.bashrc' or open a new terminal to apply changes."

# ===== 6) MetalLB (latest) + address pool =====
# Docs: https://metallb.universe.tf/installation/
# METALLB_VER="$(curl -s https://api.github.com/repos/metallb/metallb/releases/latest | jq -r .tag_name)"
# kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VER}/config/manifests/metallb-native.yaml"
# kubectl -n metallb-system wait deploy/controller --for=condition=Available --timeout=180s

# Derive a /24-ish pool from the VM IP (edit LB_RANGE_OVERRIDE if your lab subnet differs!)
# IP="$(hostname -I | awk '{print $1}')"
# BASE="$(echo "$IP" | awk -F. '{print $1"."$2"."$3}')"
# LB_RANGE="${LB_RANGE_OVERRIDE:-${BASE}.240-${BASE}.250}"

# cat <<EOF | kubectl apply -f -
# apiVersion: metallb.io/v1beta1
# kind: IPAddressPool
# metadata:
#   name: vipah-pool
#   namespace: metallb-system
# spec:
#   addresses:
#   - ${LB_RANGE}
# ---
# apiVersion: metallb.io/v1beta1
# kind: L2Advertisement
# metadata:
#   name: vipah-adv
#   namespace: metallb-system
# spec: {}
# EOF

# ===== 7) Ingress controller (community ingress-nginx via Helm) =====
# Repo: https://github.com/kubernetes/ingress-nginx (chart on ArtifactHub)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress \
  --set controller.service.type=LoadBalancer

# Wait and show the LB IP for the controller
echo "Waiting for ingress-nginx LoadBalancer IP..."
kubectl -n ingress get svc ingress-nginx-controller -w &
sleep 10 || true

# ===== 8) Sanity checks =====
kubectl get nodes -o wide
kubectl get pods -A
kubectl -n metallb-system get all
kubectl -n ingress get svc

echo
echo "✔ Base lab ready. Open a NEW shell to load ~/.bashrc or run: source ~/.bashrc"
echo "   - Cluster IP: ${NODE_IP}"
echo "   - MetalLB pool: ${LB_RANGE}"
echo "Next: deploy VIP Authentication Hub into namespace 'ssp' with a LoadBalancer or Ingress."
