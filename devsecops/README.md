# DevSecOps — Bushido Brand

This directory contains the local configuration and setup guides for the security automation tools used in the Bushido Brand CI/CD pipeline.

## Directory Structure

```
devsecops/
├── README.md              ← This file
├── owasp/                 ← OWASP Dependency-Check (SCA)
│   ├── setup.md
│   └── suppressions.xml
├── sonarqube/             ← SonarQube Static Analysis (SAST)
│   ├── sonar-project.properties
│   └── quality-gate-setup.md
└── trivy/                 ← Trivy Container Scanner
    ├── .trivyignore
    └── setup.md
```

## Integrated Security Controls Matrix

| Tool | Scans | Pipeline Stage | Failure Behavior | Bypass Option |
|---|---|---|---|---|
| **OWASP DC** | Code library dependencies (SCA) | Pre-Build | Fails if CVSS score exceeds `8.0` | `owasp/suppressions.xml` |
| **SonarQube** | Static code analysis (SAST) | Pre-Build | Fails if strict Quality Gate fails | `sonarqube/sonar-project.properties` (exclusions) |
| **Trivy** | Container filesystem layers | Post-Build | Fails if `CRITICAL` vulnerability exists | `trivy/.trivyignore` |

## Shift-Left Strategy

Security scans are executed **before** the container image is compiled or deployed to Kubernetes namespaces. Finding vulnerabilities early avoids pushing weak packages to live clusters.

## Handling False Positives

### 1. OWASP Dependency-Check
If a dependency flags a CVE incorrectly, locate the CVE ID inside the generated HTML report. Insert a suppression block inside `devsecops/owasp/suppressions.xml` with a justification comment.

### 2. SonarQube
Manage code false positives directly in the SonarQube web console by flagging specific violations as **"False Positive"** or **"Won't Fix"**.

### 3. Trivy
Add the CVE ID to `devsecops/trivy/.trivyignore` along with a reason and a review-by date (90-day maximum policy).

## Pipeline Reference

The full pipeline configurations live in `devsecops/` and are consumed by the Jenkins shared library during CI/CD runs.

## Quick-Reference Commands

```bash
# Trivy — filesystem scan
trivy fs --severity CRITICAL,HIGH --ignorefile devsecops/trivy/.trivyignore backend/
trivy fs --severity CRITICAL,HIGH --ignorefile devsecops/trivy/.trivyignore frontend/

# OWASP Dependency-Check
dependency-check --scan backend/requirements.txt \
  --format HTML \
  --out reports/ \
  --suppression devsecops/owasp/suppressions.xml

# SonarQube — run scanner
sonar-scanner -Dsonar.projectKey=bushido-brand-backend
```
