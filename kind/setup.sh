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
#   6. Waits for Jenkins to be ready
#   7. Prints the admin passwords and access URLs
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
pass()  { echo -e "${GREEN}[PASS]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ─── Step 1: Prerequisites ─────────────────────────────────────────────────
info "Checking prerequisites..."

command -v kind    >/dev/null 2>&1 || fail "kind is not installed. Install: https://kind.sigs.k8s.io/docs/user/quick-start/"
command -v kubectl >/dev/null 2>&1 || fail "kubectl is not installed. Install: https://kubernetes.io/docs/tasks/tools/"
command -v helm    >/dev/null 2>&1 || fail "helm is not installed. Install: https://helm.sh/docs/intro/install/"
command -v docker  >/dev/null 2>&1 || fail "docker is not installed. Install: https://docs.docker.com/get-docker/"

pass "All prerequisites met."

# ─── Step 2: Create KIND Cluster ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="bushido-brand"

info "Creating KIND cluster '${CLUSTER_NAME}' with 1 control-plane + 3 workers..."

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml" --name "${CLUSTER_NAME}"
  pass "KIND cluster created."
fi

# ─── Step 3: Create Namespace ──────────────────────────────────────────────
info "Creating 'jenkins' namespace..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
pass "Namespace 'jenkins' ready."

# ─── Step 4: Add Helm Repos ────────────────────────────────────────────────
info "Adding Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
helm repo update 2>/dev/null || true
pass "Helm repos updated."

# ─── Step 5: Install Jenkins ────────────────────────────────────────────────
RELEASE_NAME="bushido-jenkins"

if helm status "${RELEASE_NAME}" -n jenkins >/dev/null 2>&1; then
  warn "Jenkins release '${RELEASE_NAME}' already exists. Upgrading..."
  helm upgrade "${RELEASE_NAME}" jenkins/jenkins \
    --namespace jenkins \
    --values "${SCRIPT_DIR}/jenkins-values.yaml" \
    --wait \
    --timeout 10m
else
  info "Installing Jenkins via Helm..."
  helm install "${RELEASE_NAME}" jenkins/jenkins \
    --namespace jenkins \
    --values "${SCRIPT_DIR}/jenkins-values.yaml" \
    --wait \
    --timeout 10m
fi

pass "Jenkins installed."

# ─── Step 6: Add ArgoCD Helm Repository ──────────────────────────────────────
info "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update 2>/dev/null || true
pass "ArgoCD Helm repo added."

# ─── Step 7: Create ArgoCD Namespace ─────────────────────────────────────────
info "Creating 'argocd' namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
pass "Namespace 'argocd' ready."

# ─── Step 8: Install ArgoCD ──────────────────────────────────────────────────
ARGOCD_RELEASE="bushido-argocd"

if helm status "${ARGOCD_RELEASE}" -n argocd >/dev/null 2>&1; then
  warn "ArgoCD release '${ARGOCD_RELEASE}' already exists. Upgrading..."
  helm upgrade "${ARGOCD_RELEASE}" argo/argo-cd \
    --namespace argocd \
    --version 7.8.1 \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30080 \
    --set server.service.nodePortHttps=30443 \
    --set configs.params.server.insecure=true \
    --wait \
    --timeout 5m
else
  info "Installing ArgoCD via Helm..."
  helm install "${ARGOCD_RELEASE}" argo/argo-cd \
    --namespace argocd \
    --version 7.8.1 \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30080 \
    --set server.service.nodePortHttps=30443 \
    --set configs.params.server.insecure=true \
    --wait \
    --timeout 5m
fi

pass "ArgoCD installed."

# ─── Step 9: Get ArgoCD Admin Password ───────────────────────────────────────
info "Waiting for ArgoCD server pod to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s 2>/dev/null || {
  warn "Timed out waiting for ArgoCD server pod. Checking status..."
  kubectl get pods -n argocd
}

ARGOCD_PASSWORD=$(kubectl get secret "${ARGOCD_RELEASE}-argocd-initial-admin-secret" -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo "(see kubectl get secret -n argocd)")

# ─── Step 10: Bootstrap GitOps Apps ──────────────────────────────────────────
info "Bootstrapping ArgoCD applications (app-of-apps)..."
kubectl apply -f "${SCRIPT_DIR}/../bushido-brand-pipeline/gitops-repo/argocd/project.yaml" 2>/dev/null || true
kubectl apply -f "${SCRIPT_DIR}/../bushido-brand-pipeline/gitops-repo/argocd/app-of-apps.yaml" 2>/dev/null || true
pass "ArgoCD applications bootstrapped."

warn "NOTE: Backend and DB apps will show sync errors until secrets are created."
warn "Create required secrets: kubectl create secret generic ... -n bushido-brand"
warn "See bushido-brand-pipeline/gitops-repo/README.md for the full secrets list."

# ─── Step 11: Wait for Jenkins Pod ───────────────────────────────────────────
info "Waiting for Jenkins pod to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=jenkins -n jenkins --timeout=300s 2>/dev/null || {
  warn "Timed out waiting for pod. Checking status..."
  kubectl get pods -n jenkins
}

# ─── Step 12: Get Jenkins Admin Password ─────────────────────────────────────
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

# ─── Step 13: Print Summary ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Bushido Brand — KIND Cluster + Jenkins + ArgoCD Ready${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${BLUE}Jenkins URL:${NC}    http://localhost:32000"
echo -e "  ${BLUE}Username:${NC}       admin"
echo -e "  ${BLUE}Password:${NC}       ${ADMIN_PASSWORD}"
echo ""
echo -e "  ${YELLOW}Cluster:${NC}        ${CLUSTER_NAME}"
echo -e "  ${YELLOW}Nodes:${NC}"
kubectl get nodes -o wide | awk '{print "    " $0}'
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo -e "  ${BLUE}Useful commands:${NC}"
echo ""
echo "    # Open Blue Ocean UI"
echo "    open http://localhost:32000/blue"
echo ""
echo "    # Get Jenkins logs"
echo "    kubectl logs -n jenkins deployment/bushido-jenkins"
echo ""
echo "    # Load Docker images into KIND (instead of pushing to Docker Hub)"
echo "    kind load docker-image my-image:tag --name ${CLUSTER_NAME}"
echo ""
echo "    # Simulate a push for local dev:"
echo "    kind load docker-image bushidobrand/bushido-brand-backend:latest --name ${CLUSTER_NAME}"
echo ""
echo "    # Destroy cluster when done"
echo "    kind delete cluster --name ${CLUSTER_NAME}"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo -e "  ${GREEN}Open Jenkins:${NC}    http://localhost:32000"
echo -e "  ${GREEN}Blue Ocean:${NC}     http://localhost:32000/blue"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
