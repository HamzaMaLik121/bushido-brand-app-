# Bushido Brand — Local KIND Cluster + Jenkins + ArgoCD

## Prerequisites

Install these tools:

| Tool | Install Command | Why |
|---|---|---|
| **Docker** | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) | Container runtime |
| **kind** | `brew install kind` or [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/) | Local Kubernetes |
| **kubectl** | `brew install kubectl` or [install guide](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| **helm** | `brew install helm` or [install guide](https://helm.sh/docs/intro/install/) | Package manager for K8s |

## Quick Start

```bash
# 1. Go to the kind directory
cd kind

# 2. Make the script executable
chmod +x setup.sh

# 3. Run it
./setup.sh
```

Wait ~5 minutes for everything to spin up.

## Access

After the script finishes:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jenkins** | [http://localhost:32000](http://localhost:32000) | `admin` / printed in terminal |
| **Blue Ocean** | [http://localhost:32000/blue](http://localhost:32000/blue) | Same as Jenkins |
| **ArgoCD** | [http://localhost:30080](http://localhost:30080) | `admin` / printed in terminal |
| **Bushido App** | http://localhost (after deploying charts) | — |

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  KIND Cluster (bushido-brand)                            │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│  │  Jenkins   │  │   ArgoCD   │  │ Bushido    │         │
│  │  (jenkins) │  │  (argocd)  │  │ (bushido-  │         │
│  │  ns)       │  │  ns)       │  │ brand ns)  │         │
│  │            │  │            │  │            │         │
│  │ NodePort   │  │ NodePort   │  │ Helm +     │         │
│  │ 32000      │  │ 30080      │  │ GitOps     │         │
│  └────────────┘  └────────────┘  └────────────┘         │
│                                                          │
│   3 Worker Nodes — 1 Control-Plane                       │
└──────────────────────────────────────────────────────────┘
```

## What's Installed

### KIND Cluster
- 1 control-plane node + 3 worker nodes
- Port 32000 mapped for Jenkins
- Port 30080 mapped for ArgoCD

### Jenkins
- **Blue Ocean** UI for visual pipeline views
- **Kubernetes plugin** — dynamic build agent pods
- **Docker-in-Docker (DinD)** — builds images inside the cluster
- **Pre-installed tools** in build agents: Docker, Trivy, YQ, ArgoCD CLI, Sonar Scanner

### ArgoCD
- **GitOps** — syncs cluster state with Git
- **App-of-apps** pattern — bootstrap entire system from one manifest
- **Auto-sync** — detects and applies Git changes automatically
- **ArgoCD CLI** available inside Jenkins build agents for pipeline sync

### Build Agent Pod Template

When a Jenkins pipeline runs with `agent { label 'docker-agent' }`, it spins up a pod containing:

| Container | Tool | Purpose |
|---|---|---|
| `jnlp` | Jenkins agent | Runs pipeline steps |
| `docker` | Docker CLI | Build images |
| `trivy` | Trivy | Vulnerability scan |
| `yq` | YQ | YAML manipulation |
| `argocd` | ArgoCD CLI | Sync deployments |
| `sonar` | Sonar Scanner | Code analysis |

## Using the Pipeline (Local Dev)

Since you're on KIND, you don't need to push to Docker Hub. Use `kind load docker-image` instead:

```bash
# Build and load the backend image
cd backend
docker build -t bushidobrand/bushido-brand-backend:local .
kind load docker-image bushidobrand/bushido-brand-backend:local --name bushido-brand

# Build and load the frontend image
cd ../frontend
docker build -t bushidobrand/bushido-brand-frontend:local .
kind load docker-image bushidobrand/bushido-brand-frontend:local --name bushido-brand
```

## Deploy the App

The `setup.sh` script bootstraps ArgoCD with the app-of-apps manifest automatically.
ArgoCD will sync the Helm charts from the gitops-repo and deploy everything:

| App | Helm Chart | Status |
|-----|-----------|--------|
| **bushido-brand-db** | `charts/db` | MySQL 8.0 StatefulSet |
| **bushido-brand-backend** | `charts/backend` | Flask API Deployment |
| **bushido-brand-frontend** | `charts/frontend` | Nginx Deployment |

To check sync status:

```bash
argocd app list
argocd app sync bushido-brand-backend
```

Or deploy manually without ArgoCD:

```bash
helm upgrade --install bushido-brand-db ../bushido-brand-pipeline/gitops-repo/charts/db \
  --namespace bushido-brand --create-namespace
helm upgrade --install bushido-brand-backend ../bushido-brand-pipeline/gitops-repo/charts/backend \
  --namespace bushido-brand
helm upgrade --install bushido-brand-frontend ../bushido-brand-pipeline/gitops-repo/charts/frontend \
  --namespace bushido-brand
```

## ArgoCD CLI Usage

```bash
# Login (password auto-retrieved by setup.sh)
argocd login localhost:30080 --username admin --password <from-setup-output> --insecure

# View all apps
argocd app list

# Sync a specific app
argocd app sync bushido-brand-backend

# Get app details
argocd app get bushido-brand-frontend
```

## Teardown

```bash
# Delete everything
kind delete cluster --name bushido-brand
```

## Troubleshooting

| Problem | Solution |
|---|---|
| Port 32000 already in use | Change `serviceNodePort` in `jenkins-values.yaml` |
| Port 30080 already in use | Change `nodePortHttp` in setup.sh |
| Jenkins pod not starting | `kubectl logs -n jenkins deployment/bushido-jenkins` |
| ArgoCD pod not starting | `kubectl logs -n argocd deployment/bushido-argocd-server` |
| Build agents can't connect | `kubectl describe pod -n jenkins <agent-pod>` |
| Docker daemon not available | Verify DinD sidecar is running: `kubectl get pods -n jenkins` |
| ArgoCD apps not syncing | Check `kubectl get applications -n argocd` |
| Can't find Jenkins password | `kubectl get secret bushido-jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' \| base64 --decode` |
| Can't find ArgoCD password | `kubectl get secret bushido-argocd-argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' \| base64 --decode` |
