# Trivy Image Scanning Setup Guide

Trivy performs static scanning of container layers, blocking deployments that include packages with critical security issues.

## Installer Commands

### Debian/Ubuntu Linux Agent Setup:
```bash
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb \$(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
```

### macOS Local Verification Setup:
```bash
brew install aquasecurity/trivy/trivy
```

## Running Database Updates
Offline or private builders should download the vulnerability definitions before scanning:
```bash
trivy image --download-db-only
```

## Scanner Flag Mapping
* `--exit-code 1`: Signals failure to the pipeline if vulns matching severity limits exist.
* `--severity CRITICAL`: Target only Critical exposures for build abort limits.
* `--no-progress`: Suppresses download indicators to keep Jenkins log sizes small.
* `--format json --output trivy-report.json`: Saves output logs to file for compliance tracking.
