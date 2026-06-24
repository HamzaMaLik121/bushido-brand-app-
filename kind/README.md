# Bushido Brand — Local KIND Cluster + Jenkins

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

| Service | URL |
|---|---|
| **Jenkins** | [http://localhost:32000](http://localhost:32000) |
| **Blue Ocean** | [http://localhost:32000/blue](http://localhost:32000/blue) |
| **Username** | `admin` |
| **Password** | Printed in the terminal output |

## Architecture

```
┌──────────────────────────────────────────┐
│  KIND Cluster (bushido-brand)            │
│                                          │
│  ┌──────────────────┐                    │
│  │ Control-Plane    │                    │
│  └────────┬─────────┘                    │
│           │                              │
│  ┌────────┼────────┬─────────┐           │
│  │        │        │         │           │
│  ▼        ▼        ▼         ▼           │
│ ┌────┐  ┌────┐  ┌────┐   ┌────┐         │
│ │Pod │  │Pod │  │Pod │   │Pod │         │
│ │    │  │    │  │    │   │    │         │
│ │    │  │    │  │    │   │    │         │
│ │ ①  │  │ ②  │  │ ③  │   │ ④  │         │
│ └────┘  └────┘  └────┘   └────┘         │
│ Worker1  Worker2  Worker3  Jenkins      │
│                                         │
│    NodePort 32000 ───── localhost:32000  │
└──────────────────────────────────────────┘
```

## What's Installed

### KIND Cluster
- 1 control-plane node
- 3 worker nodes
- Port 32000 mapped for Jenkins

### Jenkins
- **Blue Ocean** UI for visual pipeline views
- **Kubernetes plugin** — spins up dynamic build agent pods
- **Docker-in-Docker (DinD)** — builds container images inside the cluster
- **Pre-installed tools** in build agents: Docker CLI, Trivy, YQ, ArgoCD, Sonar Scanner

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

## Add Your App to the Cluster

```bash
# Deploy using Helm (charts are the source of truth)
helm upgrade --install bushido-brand-db ../bushido-brand-pipeline/gitops-repo/charts/db \
  --namespace bushido-brand --create-namespace
helm upgrade --install bushido-brand-backend ../bushido-brand-pipeline/gitops-repo/charts/backend \
  --namespace bushido-brand
helm upgrade --install bushido-brand-frontend ../bushido-brand-pipeline/gitops-repo/charts/frontend \
  --namespace bushido-brand
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
| Jenkins pod not starting | `kubectl logs -n jenkins deployment/bushido-jenkins` |
| Build agents can't connect | Check `kubectl describe pod -n jenkins <agent-pod>` |
| Docker daemon not available | Verify DinD sidecar is running: `kubectl get pods -n jenkins` |
| Can't find admin password | `kubectl get secret bushido-jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' \| base64 --decode` |
