# GitOps Infrastructure Deployment Control for bushido-brand

This repository utilizes ArgoCD to enforce GitOps declarations for the microservice layers of bushido-brand.

## Deployment Control Flow Diagram

```
 [Jenkins Build Complete]
            │
            ▼
    [Tag Update in Git]  ─────>  [GitHub Webhook Notify]
            │                               │
            ▼                               ▼
┌───────────────────────┐       ┌───────────────────────┐
│  GitOps Repo values   │       │   ArgoCD Root App     │
│ (source of truth)     │       │     (app-of-apps)     │
└───────────────────────┘       └───────────────────────┘
            │                               │
            │                               ▼
            │                   ┌───────────────────────┐
            │                   │ ArgoCD App Project    │
            │                   └───────────────────────┘
            │                               │
            ▼                               ▼
 ┌─────────────────────┐         ┌─────────────────────┐
 │  backend-app Config │ <─────> │ frontend-app Config │
 └─────────────────────┘         └─────────────────────┘
            │                               │
            ▼                               ▼
 ┌─────────────────────┐         ┌─────────────────────┐
 │ Deploy backend pods │         │ Deploy frontend     │
 │ K8s                 │         │ pods K8s            │
 └─────────────────────┘         └─────────────────────┘
```

## Repository Structure
```
gitops-repo/
├── charts/
│   ├── backend/                  ← Backend Flask API helm chart (port 5000)
│   ├── db/                       ← MySQL 8.0 database helm chart (port 3306)
│   └── frontend/                 ← Frontend Nginx helm chart (port 80)
├── argocd/
│   ├── project.yaml             ← Custom project governance
│   ├── apps/
│   │   ├── backend-app.yaml     ← Backend delivery mapping
│   │   ├── db-app.yaml          ← Database delivery mapping
│   │   └── frontend-app.yaml    ← Frontend delivery mapping
│   └── app-of-apps.yaml         ← System bootstrap app
└── README.md
```

## Deployment Options

### Option A — ArgoCD (GitOps, recommended for production)
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

### Option B — Helm (standalone, no ArgoCD)
```bash
helm upgrade --install bushido-brand-db ./charts/db      --namespace bushido-brand --create-namespace
helm upgrade --install bushido-brand-backend ./charts/backend --namespace bushido-brand
helm upgrade --install bushido-brand-frontend ./charts/frontend --namespace bushido-brand
```

## Secrets Management

Before deploying, create the required secrets:

```bash
# Database credentials
kubectl create secret generic mysql-root-password \
  --namespace bushido-brand \
  --from-literal=password='<your-root-password>'
kubectl create secret generic mysql-user-password \
  --namespace bushido-brand \
  --from-literal=password='<your-user-password>'

# Backend secrets
kubectl create secret generic backend-database-url \
  --namespace bushido-brand \
  --from-literal=database-url='mysql+pymysql://bushido_user:<password>@db/bushido_db'
kubectl create secret generic backend-secret-key \
  --namespace bushido-brand \
  --from-literal=secret-key='<generate-a-strong-random-secret>'
kubectl create secret generic backend-jwt-secret-key \
  --namespace bushido-brand \
  --from-literal=jwt-secret-key='<generate-a-strong-random-secret>'
```

For GitOps-native encryption, integrate [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or the [External Secrets Operator](https://external-secrets.io/).

## System Bootstrapping (ArgoCD)
To deploy the entire environment onto your active Kubernetes cluster:

1. Create target namespace boundary:
   ```bash
   kubectl create namespace bushido-brand
   ```
2. Create required secrets (see Secrets Management above).
3. Apply root bootstrapper manifest:
   ```bash
   kubectl apply -f argocd/app-of-apps.yaml
   ```

## Standard CLI Tasks

* **Manual Sync Injection:**
  ```bash
  argocd app sync bushido-brand-backend
  argocd app sync bushido-brand-db
  argocd app sync bushido-brand-frontend
  ```
* **Rollback Target deployment:**
  ```bash
  argocd app rollback bushido-brand-backend <revision-id>
  ```
* **Port-forward for local testing:**
  ```bash
  kubectl port-forward -n bushido-brand service/frontend 8080:80
  kubectl port-forward -n bushido-brand service/backend  8081:80
  ```

## App-of-Apps Scaling Pattern
To register a new microservice under delivery control:
1. Generate standard Helm directories inside `gitops-repo/charts/<service>`.
2. Generate corresponding deployment manifests inside `gitops-repo/argocd/apps/<service>-app.yaml`.
3. Commit and push. ArgoCD automatically tracks modifications and provisions elements.
