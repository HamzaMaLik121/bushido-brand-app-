# Trivy — Setup Guide

> **Version installed:** 0.71.2 (via Homebrew)
> **Jenkins agent image:** `aquasec/trivy:0.58.2` (in Jenkins agent pod template)

## Overview

[Trivy](https://github.com/aquasecurity/trivy) is a comprehensive vulnerability scanner for
containers, filesystems, Git repositories, and dependency trees. It is executed during the
**CI — Build & Scan** stages of the Jenkins pipeline, scanning Docker images **after** they
are built.

## Local Installation (macOS)

```bash
# Install via Homebrew (already done on this machine)
brew install trivy

# Verify installation
trivy --version
# → Version: 0.71.2
```

## Usage

### Scan a Docker image

```bash
# Scan a local Docker image (use your image:tag)
trivy image bushidobrand/bushido-brand-backend:latest

# Scan with JSON output for CI processing (pipeline uses commit SHA tags)
trivy image --format json --output reports/trivy-report.json bushidobrand/bushido-brand-backend:a1b2c3d

# Scan with severity filtering
trivy image --severity CRITICAL,HIGH bushidobrand/bushido-brand-backend:latest
```

### Scan a filesystem

```bash
# Scan the backend directory
trivy fs backend/

# Scan with root-level ignore file
trivy fs --ignorefile devsecops/trivy/.trivyignore backend/

# Scan with pipeline's ignore file (from project root)
trivy fs --ignorefile devsecops/trivy/.trivyignore backend/
```

### Scan a Git repository

```bash
trivy repo https://github.com/BushidoBrand/bushido-brand
```

### Update vulnerability database

```bash
# Update the vulnerability database manually
trivy image --download-db-only
```

## Jenkins Pipeline Integration

Trivy runs in the **CI — Build & Scan** stage, **after** the Docker image is built:

```groovy
stage('Trivy Scan') {
    steps {
        runTrivyScan(fullImage: env.BACKEND_IMAGE, reportName: 'backend-trivy-report.json')
    }
    post { always { archiveArtifacts artifacts: 'backend-trivy-report.json', allowEmptyArchive: true } }
}
```

The pipeline uses the shared library function `runTrivyScan()` which:
1. Runs `trivy image --format json --output <reportName> <image>`
2. Archives the JSON report as a build artifact
3. Fails the build if any **CRITICAL** severity vulnerabilities are found

## Ignore File

**Location:** `devsecops/trivy/.trivyignore`

Use this file to suppress false positives or temporarily accept known risks.
Each entry requires:
- A CVE identifier
- A clear reason for suppression
- A review-by date (policy: 90-day maximum)

## Severity Threshold

The pipeline fails the build if Trivy detects any **CRITICAL** severity vulnerabilities.
HIGH and lower severities are reported but do not fail the build.
