# OWASP Dependency-Check — Setup Guide

> **Version installed:** 12.2.2 (via Homebrew)
> **Jenkins plugin:** `dependency-check-jenkins-plugin` (auto-installed in Jenkins)

## Overview

[OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/) is a Software Composition Analysis (SCA) tool that identifies publicly known vulnerabilities (CVEs) in project dependencies. It is executed during the **CI — Backend: OWASP & SonarQube** stage of the Jenkins pipeline.

## Local Installation (macOS)

```bash
# Install via Homebrew (already done on this machine)
brew install dependency-check

# Verify installation
dependency-check --version
# → Dependency-Check Core version 12.2.2
```

## Usage

### Scan a project locally

```bash
# Scan a Python project (requirements.txt)
dependency-check --scan backend/requirements.txt \
  --format HTML \
  --out reports/ \
  --suppression devsecops/owasp/suppressions.xml

# Scan a Node.js project
dependency-check --scan frontend/package.json \
  --format HTML \
  --out reports/ \
  --suppression devsecops/owasp/suppressions.xml

# Scan from the project root (uses the pipeline's suppression file)
dependency-check --scan backend \
  --format HTML --format XML \
  --out reports/ \
  --suppression devsecops/owasp/suppressions.xml
```

### Update the NVD database

OWASP DC uses the NVD (National Vulnerability Database). The first scan downloads the database,
which can take a long time. Subsequent scans use the cached data.

```bash
# Force update the database
dependency-check --updateonly
```

> **Note:** An NVD API key is pre-configured in Jenkins (`OWASP` credential) to avoid
> rate limiting. For local scans without an API key, the tool falls back to the unauthenticated
> feed which is slower but functional.

## Jenkins Pipeline Integration

The Jenkins pipeline runs OWASP DC in the **CI — Backend: OWASP & SonarQube** stage:

```groovy
stage('OWASP Dependency Check') {
    steps {
        dir('backend') {
            runOwaspCheck(
                appName: 'bushido-brand-backend',
                suppressionPath: '../devsecops/owasp/suppressions.xml'
            )
        }
    }
    post { always { dependencyCheckPublisher pattern: 'backend/reports/dependency-check-report.xml' } }
}
```

The pipeline uses the shared library function `runOwaspCheck()` which:
1. Runs `dependency-check --scan . --format HTML --format XML --out reports/`
2. Applies the project suppression file
3. Publishes the HTML report via the `dependencyCheckPublisher` post-build action

## Suppression File

**Location:** `devsecops/owasp/suppressions.xml`

Use this file to suppress false positives or temporarily accept known risks.
Each suppression must include a justification comment and, where possible, an expiry date.

See the file itself for annotated examples.

## CVSS Threshold

The pipeline fails the build if any dependency has a CVSS score exceeding **8.0**.
This threshold is configurable in the Jenkins shared library.
