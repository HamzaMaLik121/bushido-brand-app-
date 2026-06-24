# OWASP Dependency-Check Configuration Guide

This outlines installation steps for the software package scanner inside the pipeline builder environments.

## Manual Agent Setup Steps
The Jenkins scanning runner requires OWASP CLI installed at `/opt/dependency-check/`.

```bash
# Retrieve latest binary release package
wget https://github.com/jeremylong/DependencyCheck/releases/download/v9.0.9/dependency-check-9.0.9-release.zip

# Create destination and extract
sudo mkdir -p /opt/dependency-check
sudo unzip dependency-check-9.0.9-release.zip -d /opt/
sudo chmod +x /opt/dependency-check/bin/dependency-check.sh
```

## NVD Database Access Configuration
The scanner pulls CVE details from the NIST National Vulnerability Database. Since they throttle anonymous clients, you should register an API key.

1. Obtain a query token: https://nvd.nist.gov/developers/request-an-api-key
2. Navigate to **Manage Jenkins** -> **Credentials** -> **Add Credentials**.
3. Configure:
   * **Type:** Secret Text
   * **ID:** `nvd-api-key`
   * **Secret:** `<your-nvd-api-token>`

## Scanning Commands
The scanner compiles package details using the following parameters:
```bash
/opt/dependency-check/bin/dependency-check.sh \
    --project "bushido-brand" \
    --scan . \
    --format HTML \
    --format XML \
    --out reports/ \
    --nvdApiKey "$NVD_API_KEY" \
    --failOnCVSS 8 \
    --suppression owasp-suppressions.xml
```

### Argument Explanations:
* `--failOnCVSS 8`: Enforce builds failures if vulnerabilities scoring 8.0 (High/Critical) or higher are found.
* `--suppression`: Exclude false positive CVE indicators registered in local configs.
* `--enableRetired`: Also scan retired (deprecated) CVEs for completeness.
