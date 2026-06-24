# DevSecOps Pipeline Integration Guides for bushido-brand

This directory lists security automation controls that check codebase compliance, static patterns, and container health configurations.

## Integrated Security Controls Matrix

| Tool | Scans | Pipeline Stage | Failure Behavior | Bypass Option |
|---|---|---|---|---|
| **OWASP DC** | Code libraries dependencies | Pre-Build | Fails if CVSS score exceeds `8.0` | `owasp-suppressions.xml` |
| **SonarQube** | Static code validation (SAST) | Pre-Build | Fails if strict Quality Gate fails | Exclusions properties file |
| **Trivy** | Container filesystem layers | Post-Build | Fails if `CRITICAL` issue exists | `.trivyignore` registration |

## Shift-Left Strategy
Security scans are executed **before** the container image is compiled or deployed to Kubernetes namespaces. Finding vulnerabilities early in the cycle avoids pushing weak packages to live clusters.

## Handling False Positives

### 1. OWASP dependency-check:
If a dependency flags a CVE incorrectly, locate the CVE code inside the generated HTML report. Insert a suppression block inside the corresponding `suppressions.xml` file.

### 2. SonarQube:
Manage code false positives directly in the SonarQube web console by flagging specific violations as "False Positive" or "Won't Fix".

### 3. Trivy:
Add the CVE tag directly into the `.trivyignore` file along with the necessary documentation and review dates.
