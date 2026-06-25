<p align="center">
  <img src="https://img.shields.io/badge/status-production-brightgreen?style=for-the-badge" alt="Status">
  <img src="https://img.shields.io/badge/Flask-2.x-000000?style=for-the-badge&logo=flask" alt="Flask">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql" alt="MySQL">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker" alt="Docker">
  <img src="https://img.shields.io/badge/Jenkins-CI-D24939?style=for-the-badge&logo=jenkins" alt="Jenkins">
  <img src="https://img.shields.io/badge/ArgoCD-GitOps-FC6A31?style=for-the-badge&logo=argo" alt="ArgoCD">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes" alt="K8s">
</p>

<h1 align="center">⚔️ BUSHIDO BRAND ⚔️</h1>
<p align="center">
  <em>Urban streetwear meets Japanese warrior ethos — a full-stack e-commerce platform</em>
</p>

---

## 🚀 Overview

**Bushido Brand** is a production-grade, 3-tier e-commerce web application for a fictional streetwear brand inspired by the samurai code. It combines a sleek frontend with a secure backend, containerized infrastructure, and a full DevSecOps CI/CD pipeline.

| Tier | Tech | Role |
|------|------|------|
| 🎨 **Frontend** | HTML5, CSS3, Vanilla JS, GSAP | Static storefront with animations |
| ⚙️ **Backend** | Python, Flask, SQLAlchemy, JWT | REST API for products, auth, cart, orders |
| 🗄️ **Database** | MySQL 8.0 | Persistent data store |
| 🔁 **CI/CD** | Jenkins + Docker + ArgoCD | Automated build, test, deploy |
| 🛡️ **DevSecOps** | SonarQube, Trivy, OWASP DC | Security scanning at every stage |

---

## ✨ Features

### 🛍️ Storefront
- Responsive product catalog with category filtering
- Interactive shopping cart with local state management
- User authentication (register / login / JWT sessions)
- Product detail pages with dynamic content
- Contact form with backend integration
- GSAP-powered animations and parallax effects

### 🔐 Security
- JWT-based authentication & authorization
- Non-root container execution
- Read-only filesystem in production containers
- Dropped Linux capabilities (least privilege)
- CORS-configured API access

### 🚀 DevOps
- **Docker Compose** — one-command local development
- **Helm charts** — Kubernetes deployment via ArgoCD GitOps
- **Jenkins pipeline** — build, scan, push, deploy automatically
- **SonarQube** — static code analysis with quality gates
- **Trivy** — container vulnerability scanning
- **OWASP DC** — dependency vulnerability scanning

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        🌐 User                               │
└────────────┬──────────────────────────────────┬──────────────┘
             │                                  │
             ▼                                  ▼
┌───────────────────────┐         ┌───────────────────────────┐
│     Nginx (80)        │         │     phpMyAdmin (8081)     │
│   Static files +      │         │   Database management     │
│   API proxy /api/     │         └───────────────────────────┘
└───────────┬───────────┘
            │ /api/
            ▼
┌───────────────────────┐         ┌───────────────────────────┐
│   Flask API (5000)    │◄───────►│     MySQL 8.0 (3306)      │
│  JWT Auth + RESTful   │         │   Init SQL + Seed data    │
└───────────────────────┘         └───────────────────────────┘
```

---

## 🧱 Project Structure

```
bushido-brand/
├── frontend/                    # 🎨 Nginx static site
│   ├── Dockerfile
│   ├── nginx.conf
│   └── src/
│       ├── css/                 #   Stylesheets (hero, navbar, cart, etc.)
│       ├── js/                  # ⚡ Client-side logic & GSAP animations
│       ├── components/          # 🧩 Reusable HTML components
│       └── pages/               # 📄 Full pages (index, about, products, etc.)
│
├── backend/                     # ⚙️ Flask REST API
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                   # Application entry point
│   ├── config.py                # Configuration management
│   └── src/
│       ├── middleware/           # 🔒 Auth, CORS middleware
│       ├── models/              #   SQLAlchemy models
│       ├── routes/              # 🚏 API route handlers
│       └── utils/               # 🛠️ Helper functions & validators
│
├── db/                          # 🗄️ Database
│   ├── init.sql                 # Schema initialization
│   └── seed.sql                 #   Product seed data (15 products)
│
├── kind/                        # ☸️ Local KIND cluster
│   ├── setup.sh                 # One-command cluster bootstrap
│   ├── kind-config.yaml         # Cluster configuration
│   └── jenkins-values.yaml      # Jenkins Helm values
│
├── bushido-brand-pipeline/      # 🔁 CI/CD Pipeline
│   ├── Jenkinsfile.template     # Pipeline template
│   ├── gitops-repo/             # GitOps manifests
│   │   ├── charts/              # 📦 Helm charts (frontend, backend, db)
│   │   └── argocd/              # 🎯 ArgoCD application definitions
│   └── jenkins-shared-lib/      # 📚 Jenkins shared library
│
├── devsecops/                   # 🛡️ Security configs
│   ├── sonarqube/               #   SonarQube SAST configuration
│   ├── owasp/                   #   OWASP Dependency-Check (SCA)
│   └── trivy/                   #   Trivy container scanning
│
├── docker-compose.yml           # 🐳 Local dev environment
├── Jenkinsfile                  # 🔁 CI/CD pipeline definition
└── universal-devsecops-prompt.md # 📋 DevSecOps prompt template
```

---

## 🚦 Getting Started

### 🐳 Local Development (Docker Compose)

```bash
# 1. Clone the repo
git clone https://github.com/HamzaMaLik121/bushido-brand-app-.git
cd bushido-brand-app-

# 2. Copy and configure environment variables
cp .env.example .env
# Edit .env with your secrets

# 3. Start everything
docker-compose up --build
```

| Service     | URL                     |
|-------------|-------------------------|
| 🌐 Website  | http://localhost        |
| 🗄️ phpMyAdmin | http://localhost:8081 |

### ☸️ Local KIND Cluster

```bash
cd kind
chmod +x setup.sh
./setup.sh
```

This spins up a 3-worker KIND cluster with Jenkins pre-installed.

---

## 🔁 CI/CD Pipeline

```
                    ┌──────────────┐
                    │   Git Push   │
                    └──────┬───────┘
                           ▼
              ┌────────────────────────┐
              │   Jenkins Pipeline     │
              │                        │
              │  ┌──────────────────┐  │
              │  │ OWASP Dep Check  │  │
              │  ├──────────────────┤  │
              │  │ SonarQube Scan   │  │
              │  ├──────────────────┤  │
              │  │ Quality Gate     │  │
              │  ├──────────────────┤  │
              │  │ Docker Build     │  │
              │  ├──────────────────┤  │
              │  │ Trivy Scan       │  │
              │  ├──────────────────┤  │
              │  │ Push to Registry │  │
              │  ├──────────────────┤  │
              │  │ Update GitOps    │──┼──► Helm values.yaml
              │  ├──────────────────┤  │
              │  │ Sync ArgoCD      │──┼──► K8s Cluster
              │  └──────────────────┘  │
              └────────────────────────┘
```

| Stage | Tool | Purpose |
|-------|------|---------|
| 🔍 | OWASP Dependency Check | Scans third-party dependencies for known CVEs |
| 📊 | SonarQube | Static code analysis with quality gates |
| 🐳 | Docker Build | Container image creation |
| 🔬 | Trivy | Container image vulnerability scanning |
| 📦 | Docker Hub | Secure image registry |
| 🌿 | GitOps Update | Bumps image tag in Helm values |
| 🔄 | ArgoCD Sync | Synchronizes K8s cluster with Git state |

---

## 📦 Tech Stack

| Category | Technologies |
|----------|--------------|
| **Frontend** | HTML5, CSS3 (Grid/Flexbox), Vanilla JavaScript, GSAP |
| **Backend** | Python, Flask, Gunicorn, SQLAlchemy, PyJWT |
| **Database** | MySQL 8.0 |
| **Infrastructure** | Docker, Docker Compose, Nginx, KIND |
| **Orchestration** | Kubernetes, Helm, ArgoCD |
| **CI/CD** | Jenkins, Shared Libraries |
| **Security** | SonarQube, Trivy, OWASP Dependency Check |
| **Monitoring** | Slack Notifications |

---

## 🛡️ DevSecOps

Security is built into every stage of the pipeline:

- **Shift-left testing** — security scans run before the build, not after deployment
- **Least privilege containers** — non-root users, read-only rootfs, dropped capabilities
- **Dependency scanning** — OWASP DC catches vulnerable libraries before they ship
- **Code quality gates** — SonarQube enforces zero-bug, zero-vulnerability policy
- **Image hardening** — Trivy scans every container layer for CVEs

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m 'feat: add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

<p align="center">
  Built with ❤️ using the <strong>Bushido Code</strong> — discipline, honor, and craftsmanship in every line.
</p>
<p align="center">
  <a href="https://github.com/HamzaMaLik121/bushido-brand-app-">
    <img src="https://img.shields.io/github/stars/HamzaMaLik121/bushido-brand-app-?style=social" alt="Stars">
  </a>
</p>
