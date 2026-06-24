#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh — Bushido Brand KIND Cluster + Jenkins + ArgoCD
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   chmod +x setup.sh && ./setup.sh
#
# This script:
#   1. Checks prerequisites (kind, kubectl, helm, docker)
#   2. Creates a KIND cluster with 1 control-plane + 3 workers
#   3. Installs Jenkins via Helm with Blue Ocean + Kubernetes plugin
#   4. Installs ArgoCD via Helm for GitOps deployments
#   5. Bootstraps ArgoCD app-of-apps to deploy Bushido Brand
#   6. BLOCKS until ALL pods in jenkins, argocd, and bushido-brand are FULLY Ready
#   7. Prints the admin passwords and access URLs
#
# Docker restart resilience:
#   If you stop Docker and start it again, KIND containers restart automatically.
#   Run this script again with the cluster already existing — it detects the
#   existing cluster and just waits for all pods to come back online.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
pass()  { echo -e "${GREEN}[PASS]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="bushido-brand"

# ─── Step 1: Prerequisites ─────────────────────────────────────────────────
info "Checking prerequisites..."
command -v kind    >/dev/null 2>&1 || fail "kind is not installed. Install: https://kind.sigs.k8s.io/docs/user/quick-start/"
command -v kubectl >/dev/null 2>&1 || fail "kubectl is not installed. Install: https://kubernetes.io/docs/tasks/tools/"
command -v helm    >/dev/null 2>&1 || fail "helm is not installed. Install: https://helm.sh/docs/intro/install/"
command -v docker  >/dev/null 2>&1 || fail "docker is not installed. Install: https://docs.docker.com/get-docker/"
pass "All prerequisites met."

# ─── Step 2: Create KIND Cluster ───────────────────────────────────────────
info "Creating KIND cluster '${CLUSTER_NAME}' with 1 control-plane + 3 workers..."

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
  warn "Waiting for cluster nodes to be Ready after potential Docker restart..."
  kubectl wait --for=condition=Ready nodes --all --timeout=120s 2>/dev/null || {
    warn "Some nodes not ready yet — continuing anyway, pods will be waited on below."
  }
else
  kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml" --name "${CLUSTER_NAME}"
  pass "KIND cluster created."
fi

# ─── Step 3: Create Namespaces ─────────────────────────────────────────────
info "Creating required namespaces..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace bushido-brand --dry-run=client -o yaml | kubectl apply -f -
pass "Namespaces ready."

# ─── Step 4: Add Helm Repos ────────────────────────────────────────────────
info "Adding Helm repositories..."
helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update 2>/dev/null || true
pass "Helm repos updated."

# ─── Step 5: Install / Upgrade Jenkins ─────────────────────────────────────
RELEASE_NAME="bushido-jenkins"

if helm status "${RELEASE_NAME}" -n jenkins >/dev/null 2>&1; then
  warn "Jenkins release '${RELEASE_NAME}' already exists. Upgrading..."
  helm upgrade "${RELEASE_NAME}" jenkins/jenkins \
    --namespace jenkins \
    --values "${SCRIPT_DIR}/jenkins-values.yaml"
else
  info "Installing Jenkins via Helm..."
  helm install "${RELEASE_NAME}" jenkins/jenkins \
    --namespace jenkins \
    --values "${SCRIPT_DIR}/jenkins-values.yaml"
fi

pass "Jenkins installed."

# ─── Step 6: Install / Upgrade ArgoCD ──────────────────────────────────────
ARGOCD_RELEASE="bushido-argocd"

if helm status "${ARGOCD_RELEASE}" -n argocd >/dev/null 2>&1; then
  warn "ArgoCD release '${ARGOCD_RELEASE}' already exists. Upgrading..."
  helm upgrade "${ARGOCD_RELEASE}" argo/argo-cd \
    --namespace argocd \
    --version 7.8.1 \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30080 \
    --set server.service.nodePortHttps=30443 \
    --set configs.params.server.insecure=true
else
  info "Installing ArgoCD via Helm..."
  helm install "${ARGOCD_RELEASE}" argo/argo-cd \
    --namespace argocd \
    --version 7.8.1 \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30080 \
    --set server.service.nodePortHttps=30443 \
    --set configs.params.server.insecure=true
fi

pass "ArgoCD installed."

# ─── Step 7: Bootstrap GitOps Apps ──────────────────────────────────────────
info "Bootstrapping ArgoCD applications (app-of-apps)..."
kubectl apply -f "${SCRIPT_DIR}/../bushido-brand-pipeline/gitops-repo/argocd/project.yaml" 2>/dev/null || true
kubectl apply -f "${SCRIPT_DIR}/../bushido-brand-pipeline/gitops-repo/argocd/app-of-apps.yaml" 2>/dev/null || true
pass "ArgoCD applications bootstrapped."

warn "NOTE: Backend and DB apps will show sync errors until secrets are created."
warn "Create required secrets: kubectl create secret generic ... -n bushido-brand"
warn "See bushido-brand-pipeline/gitops-repo/README.md for the full secrets list."

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              COMPREHENSIVE WAIT — BLOCKS UNTIL ALL READY                ║
# ║      Does NOT exit until EVERY pod in EVERY namespace is Running        ║
# ║      180s timeout per namespace, polls every 10s, prints progress       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

wait_for_all_pods() {
  local namespace="$1"
  local timeout="${2:-300}"
  local interval=10
  local elapsed=0
  local first_no_pods=0

  info "Waiting for all pods in '${namespace}' to be Ready (timeout: ${timeout}s)..."
  echo ""

  while [ $elapsed -lt $timeout ]; do
    # Fetch pods safely — exit code hardened against missing namespaces
    local pod_list
    pod_list=$(kubectl get pods -n "${namespace}" --no-headers 2>/dev/null || true)

    local total
    total=$(echo "${pod_list}" | wc -l | tr -d ' ')

    # If no pods yet, the namespace might still be initializing
    if [ "${total}" -eq 0 ] || [ -z "${pod_list}" ]; then
      if [ "${first_no_pods}" -eq 0 ]; then
        first_no_pods="${elapsed}"
      fi
      # If no pods appear after 60s, skip this namespace
      if [ $((elapsed - first_no_pods)) -ge 60 ] 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} No pods appeared in '${namespace}' after 60s. Skipping."
        echo ""
        return 0
      fi
      if [ $((elapsed % 30)) -eq 0 ]; then
        echo -e "  ${BLUE}⏳${NC} [${elapsed}s/${timeout}s] ${namespace}: waiting for pods to appear..."
      fi
      sleep $interval
      elapsed=$((elapsed + interval))
      continue
    fi

    # Reset the "no pods" timer since pods appeared
    first_no_pods=0

    # Count non-ready pods (exclude Completed/Error jobs)
    local not_ready
    not_ready=$(echo "${pod_list}" | \
      awk '{ if ($3 != "Running" || $2 !~ /^[0-9]+\/[0-9]+$/ || $2 ~ /^0\//) print }' | \
      grep -v "Completed" | grep -v "Error" | wc -l | tr -d ' ')

    # Count ready pods
    local ready
    ready=$(echo "${pod_list}" | \
      awk '{ if ($2 ~ /^[0-9]+\/[0-9]+$/ && $2 !~ /^0\// && $3 == "Running") print }' | \
      grep -v "Completed" | wc -l | tr -d ' ')

    if [ "${not_ready}" -eq 0 ]; then
      echo -e "  ${GREEN}✓${NC} All ${total} pods in '${namespace}' are Ready! (${ready}/${total})"
      echo ""
      return 0
    fi

    # Print progress every 30s
    if [ $((elapsed % 30)) -eq 0 ]; then
      echo -e "  ${BLUE}⏳${NC} [${elapsed}s/${timeout}s] ${namespace}: ${ready}/${total} Ready, ${not_ready} pending"
      echo "${pod_list}" | \
        awk '{ if ($3 != "Running" || $2 ~ /^0\//) print "     " $1 " → " $3 " (" $2 ")" }' | \
        grep -v "Completed" | grep -v "Error" || true
      echo ""
    fi

    sleep ${interval}
    elapsed=$((elapsed + interval))
  done

  echo -e "  ${YELLOW}⚠${NC} Timed out waiting for '${namespace}' pods after ${timeout}s."
  echo "  Current state:"
  kubectl get pods -n "${namespace}" 2>/dev/null || true
  echo ""
  warn "Some pods in '${namespace}' are not ready yet."
  warn "Run 'kubectl get pods -n ${namespace} -w' to monitor them."
  return 1
}

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo -e "  ${BLUE}Waiting for all pods to be fully Ready...${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Wait for Jenkins pods
wait_for_all_pods "jenkins" 600

# Wait for ArgoCD pods (more components, give more time)
wait_for_all_pods "argocd" 600

# Wait for Bushido Brand app pods (if bootstrapped via ArgoCD)
wait_for_all_pods "bushido-brand" 300

# ─── Step 8: Get Jenkins Admin Password ─────────────────────────────────────
info "Retrieving Jenkins admin password..."
JENKINS_POD=$(kubectl get pods -n jenkins -l app.kubernetes.io/name=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
ADMIN_PASSWORD=""

if [ -n "${JENKINS_POD}" ]; then
  ADMIN_PASSWORD=$(kubectl exec "${JENKINS_POD}" -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  ADMIN_PASSWORD=$(kubectl get secret "${RELEASE_NAME}" -n jenkins -o jsonpath='{.data.jenkins-admin-password}' 2>/dev/null | base64 --decode || echo "")
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  ADMIN_PASSWORD="(check pod logs: kubectl logs ${JENKINS_POD} -n jenkins)"
fi

# ─── Step 9: Get ArgoCD Admin Password ──────────────────────────────────────
info "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl get secret "${ARGOCD_RELEASE}-argocd-initial-admin-secret" -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo "(see: kubectl get secret -n argocd)")

# ─── Step 10: Print Summary ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Bushido Brand — KIND Cluster + Jenkins + ArgoCD Ready${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${BLUE}Jenkins URL:${NC}    http://localhost:32000"
echo -e "  ${BLUE}Username:${NC}       admin"
echo -e "  ${BLUE}Password:${NC}       ${ADMIN_PASSWORD}"
echo ""
echo -e "  ${BLUE}ArgoCD URL:${NC}     http://localhost:30080"
echo -e "  ${BLUE}Username:${NC}       admin"
echo -e "  ${BLUE}Password:${NC}       ${ARGOCD_PASSWORD}"
echo ""
echo -e "  ${YELLOW}Cluster:${NC}        ${CLUSTER_NAME}"
echo -e "  ${YELLOW}Nodes:${NC}"
kubectl get nodes -o wide | awk '{print "    " $0}'
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo -e "  ${BLUE}Useful commands:${NC}"
echo ""
echo "    # Open Jenkins Blue Ocean UI"
echo "    open http://localhost:32000/blue"
echo ""
echo "    # Open ArgoCD UI"
echo "    open http://localhost:30080"
echo ""
echo "    # ArgoCD login (CLI)"
echo "    argocd login localhost:30080 --username admin --password ${ARGOCD_PASSWORD} --insecure"
echo ""
echo "    # Monitor pods after Docker restart"
echo "    kubectl get pods -A -w"
echo ""
echo "    # Load Docker images into KIND (instead of pushing to Docker Hub)"
echo "    kind load docker-image bushidobrand/bushido-brand-backend:latest --name ${CLUSTER_NAME}"
echo "    kind load docker-image bushidobrand/bushido-brand-frontend:latest --name ${CLUSTER_NAME}"
echo ""
echo "    # Destroy cluster when done"
echo "    kind delete cluster --name ${CLUSTER_NAME}"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo -e "  ${GREEN}Jenkins:${NC}  http://localhost:32000"
echo -e "  ${GREEN}ArgoCD:${NC}   http://localhost:30080"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
