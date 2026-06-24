# UNIVERSAL DEVSECOPS PIPELINE PROMPT
# ─────────────────────────────────────────────────────────────────────────────
# Drop this prompt into any AI assistant to generate a production-ready
# Jenkins + GitOps + DevSecOps pipeline for ANY project.
#
# BEFORE YOU PASTE THIS PROMPT:
# Fill in the USER VARIABLES section below. That's the only thing you touch.
# Everything else is generic and reusable across projects.
# ─────────────────────────────────────────────────────────────────────────────

---

## USER VARIABLES — FILL THESE IN BEFORE USING THIS PROMPT

```
PROJECT_NAME        = "my-app"
SERVICES            = ["api", "worker"]         # list every microservice/component
DOCKERHUB_USERNAME  = "myusername"
GITOPS_REPO_URL     = "github.com/MyOrg/my-app-gitops.git"
GITOPS_BRANCH       = "main"
K8S_NAMESPACE       = "my-app"
ARGO_PROJECT        = "my-app"
SLACK_CHANNEL       = "#deployments"
SERVICE_PORT        = 8080                      # default HTTP port your containers expose
```

> Every occurrence of a USER VARIABLE in the generated files must use the
> value provided above. Do not leave any variable unreplaced.

---

## ROLE

You are a senior DevSecOps engineer. Your task is to generate a complete,
production-ready CI/CD system for the project described in USER VARIABLES above.

Rules that apply to every single file you generate:

- Write every file in full. No placeholders, no TODOs, no pseudocode.
- Comments explain WHY, not WHAT.
- Fail fast: every error() or exit 1 must print a human-readable message
  that tells the user exactly what is wrong and how to fix it.
- Idempotent: every script must be safe to run twice without breaking.
- Security by default: all K8s manifests must include non-root user,
  readOnlyRootFilesystem, allowPrivilegeEscalation: false, drop ALL capabilities.
- Only generate files. Do not run, apply, or deploy anything.

---

## WHAT TO BUILD

Three self-contained parts, in this order:

```
PART 1 → Jenkins Shared Library  (vars/ + one Jenkinsfile template)
PART 2 → GitOps Repository       (Helm charts + ArgoCD manifests)
PART 3 → DevSecOps Configs       (SonarQube + OWASP + Trivy)
```

Final folder layout (use PROJECT_NAME where shown):

```
<PROJECT_NAME>-pipeline/
│
├── CREDENTIALS_SETUP.md                  ← credential reference (generate last)
│
├── jenkins-shared-lib/                   ← PART 1 — its own Git repo
│   ├── vars/
│   │   ├── buildPipeline.groovy          ← orchestrator
│   │   ├── runOwaspCheck.groovy
│   │   ├── runSonarScan.groovy
│   │   ├── buildDockerImage.groovy
│   │   ├── runTrivyScan.groovy
│   │   ├── pushToDockerHub.groovy
│   │   ├── updateGitOps.groovy
│   │   ├── syncArgoCD.groovy
│   │   └── notifySlack.groovy
│   ├── resources/
│   │   └── owasp-suppressions.xml
│   └── README.md
│
├── Jenkinsfile.template                  ← copy this into each service repo
│
├── gitops-repo/                          ← PART 2 — its own Git repo, ArgoCD watches it
│   ├── charts/
│   │   └── _service_/                   ← one folder per service in SERVICES list
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── deployment.yaml
│   │           ├── service.yaml
│   │           └── hpa.yaml
│   ├── argocd/
│   │   ├── project.yaml                 ← ArgoCD AppProject
│   │   ├── apps/
│   │   │   └── <service>-app.yaml       ← one per service
│   │   └── app-of-apps.yaml             ← root app that manages all others
│   └── README.md
│
└── devsecops/                            ← PART 3 — can live anywhere
    ├── sonarqube/
    │   ├── sonar-project.properties
    │   └── quality-gate-setup.md
    ├── owasp/
    │   ├── suppressions.xml
    │   └── setup.md
    ├── trivy/
    │   ├── .trivyignore
    │   └── setup.md
    └── README.md
```

Generate every file listed. Announce each file before writing it:
`### File: path/to/file`
Then write its complete content in a code block.
Do not stop until every file is generated.

---

## PART 1 — JENKINS SHARED LIBRARY

### `vars/buildPipeline.groovy` — ORCHESTRATOR

This is the ONLY file called from a project's Jenkinsfile.
It accepts a `Map config` and runs the full pipeline.

Required config keys (error immediately if any are missing):
- `appName`          → service name, used in image tags, commit messages, Slack
- `dockerHubRepo`    → full Docker Hub path: DOCKERHUB_USERNAME/IMAGE_NAME
- `gitOpsRepo`       → URL of the GitOps repo (without https://)
- `helmValuePath`    → relative path inside gitops repo to this service's values.yaml
- `sonarProjectKey`  → SonarQube project key
- `argoApp`          → ArgoCD Application name

Optional config keys with defaults:
- `gitOpsBranch`     → default 'main'
- `awsRegion`        → default 'us-east-1'   (kept for future ECR support)
- `argoAutoSync`     → default false
- `slackChannel`     → default '#deployments'
- `dockerfile`       → default 'Dockerfile'
- `buildContext`     → default '.'

Pipeline structure:

```
agent { label 'docker-agent' }
options: timestamps, ansiColor('xterm'), timeout(45m), disableConcurrentBuilds,
         buildDiscarder(logRotator(numToKeepStr:'10'))

environment block: declare all env vars from config

stages:
  1. Checkout
     - checkout scm
     - capture GIT_COMMIT_SHORT = first 7 chars of GIT_COMMIT
     - build FULL_IMAGE = "${dockerHubRepo}:${GIT_COMMIT_SHORT}"
     - echo the image name

  2. OWASP Dependency Check
     - call runOwaspCheck(appName: env.APP_NAME)
     - post always: dependencyCheckPublisher pattern: 'reports/dependency-check-report.xml'

  3. SonarQube Analysis
     - call runSonarScan(projectKey: env.SONAR_KEY)

  4. Quality Gate
     - timeout(5, MINUTES) { waitForQualityGate abortPipeline: true }

  5. Docker Build
     - call buildDockerImage(fullImage: env.FULL_IMAGE, dockerfile: config.dockerfile, context: config.buildContext)

  6. Trivy Image Scan
     - call runTrivyScan(fullImage: env.FULL_IMAGE)
     - post always: archiveArtifacts 'trivy-report.json'

  7. Push to Docker Hub
     - when: branch matches /^(main|master|release\/.*)$/
     - call pushToDockerHub(fullImage: env.FULL_IMAGE)

  8. Update GitOps Repo
     - when: same branch pattern
     - call updateGitOps(gitOpsRepo, helmValuePath, imageTag, appName, gitOpsBranch)

  9. ArgoCD Sync
     - when: same branch pattern
     - call syncArgoCD(argoApp, argoAutoSync)

post:
  success: notifySlack(status:'SUCCESS', appName, imageTag, channel)
  failure: notifySlack(status:'FAILURE', appName, imageTag, channel)
  always:  cleanWs()
```

### `vars/runOwaspCheck.groovy`

- Credential: `nvd-api-key` (Secret Text)
- Binary path: `/opt/dependency-check/bin/dependency-check.sh`
- Flags: `--project`, `--scan .`, `--format HTML`, `--format XML`,
  `--out reports/`, `--nvdApiKey`, `--failOnCVSS 8`, `--enableRetired`,
  `--suppression owasp-suppressions.xml`
- Create `reports/` dir before running
- Suppress missing suppression file warning with `2>/dev/null || true` on the
  suppression flag if file not present

### `vars/runSonarScan.groovy`

- Credentials: `sonar-token` (Secret Text), `sonar-url` (Secret Text)
- Wrap with `withSonarQubeEnv('SonarQube')` — name must match Jenkins global config
- Run `sonar-scanner` with:
  `-Dsonar.projectKey`, `-Dsonar.projectName`, `-Dsonar.sources=.`,
  `-Dsonar.host.url`, `-Dsonar.login`, `-Dsonar.qualitygate.wait=false`,
  `-Dsonar.exclusions=**/vendor/**,**/node_modules/**,**/*.test.*,**/test/**,**/__mocks__/**`

### `vars/buildDockerImage.groovy`

- Accept: `fullImage` (required), `dockerfile` (default 'Dockerfile'),
  `buildArgs` (optional string), `context` (default '.')
- Error if `fullImage` missing
- Add labels: `git.commit=${GIT_COMMIT_SHORT}`, `build.number=${BUILD_NUMBER}`, `app.name=${APP_NAME}`
- Print full image name before build

### `vars/runTrivyScan.groovy`

- Accept: `fullImage` (required), `failOnCritical` (default true)
- Command 1: `--exit-code [0|1] --severity CRITICAL --no-progress --format table`
  exit-code is 1 if failOnCritical else 0
- Command 2: `--exit-code 0 --severity HIGH,CRITICAL --no-progress --format json --output trivy-report.json`
- Print scan target before running

### `vars/pushToDockerHub.groovy`

- Credential: `dockerhub-creds` (Username + Password)
  username = Docker Hub username, password = Docker Hub Access Token
- `docker login -u ${DOCKER_USER} -p ${DOCKER_TOKEN}`
- Push `fullImage` (commit SHA tag)
- Tag and push `imageBase:latest` (strip tag from fullImage)
- `docker logout` after push — never leave credentials cached
- Print each step clearly

### `vars/updateGitOps.groovy`

- Credential: `github-gitops-creds` (Username + Password — PAT with repo scope)
- Clone: `https://${GIT_USER}:${GIT_TOKEN}@${gitOpsRepo}` into temp dir `gitops-tmp/`
- Verify `helmValuePath` exists — error with helpful message if not
- Update image tag using yq v4: `yq e '.image.tag = "TAG"' -i FILE`
- Print the updated image block after change for confirmation
- git config user.email and user.name before commit
- Commit message: `chore(APPNAME): bump image tag to TAG [ci skip]`
  — `[ci skip]` prevents GitOps push from triggering another pipeline build
- Skip commit if no diff (do not error — this is normal for reruns)
- Push to gitOpsBranch
- Clean up temp dir after push

### `vars/syncArgoCD.groovy`

- Credentials: `argocd-token` (Secret Text), `argocd-server` (Secret Text)
- If `argoAutoSync == false`: run `argocd app sync ARGOAPP --grpc-web --timeout 120`
- If `argoAutoSync == true`: skip sync, print info message
- Always run: `argocd app wait ARGOAPP --health --grpc-web --timeout 300`
- Accept optional `syncTimeout` and `waitTimeout` overrides from config

### `vars/notifySlack.groovy`

- Use Slack Notification plugin `slackSend()`
- color: 'good' for SUCCESS, 'danger' for FAILURE
- Message (multi-line):
  ```
  EMOJI [APP_NAME] Pipeline STATUS
  • Branch: `BRANCH`
  • Image Tag: `TAG`
  • Build: <URL|#NUMBER>
  • Duration: DURATION
  ```

### `resources/owasp-suppressions.xml`

Valid suppressions file with:
- XML declaration and suppressions root element with official schema URL
- Header comment block explaining: what this file is, how to add suppressions,
  where to find CVE details, and the review policy
- 4 suppression entries with inline comments:
    1. Suppress a CVE for a test-only dependency (never in production classpath)
    2. Suppress a CVE for a build tool false positive (affects different product)
    3. Suppress by file path pattern for auto-generated files
    4. Time-boxed suppression using `<until>DATE</until>` — expires in 90 days
       with a comment saying: "MUST be reviewed and removed or renewed by DATE"

### `README.md`

Include:
- ASCII pipeline flow diagram
- Full directory tree of the shared library
- Table: all 7 credentials with ID, type, and exact instructions on where to get the value
- All required Jenkins plugins (name + install path in UI)
- All required tools on the Jenkins agent with install commands for Ubuntu
- Step-by-step: how to register the shared library in Jenkins
- Step-by-step: how to generate the ArgoCD API token
- How to add a new service: "copy Jenkinsfile.template, change 6 values"

---

## Jenkinsfile.template

This file lives in each service's application repo. It is the ONLY file
a developer needs to add to onboard a new service to the pipeline.

```groovy
// Jenkinsfile
// ─────────────────────────────────────────────────────────────────────────────
// Change ONLY the values below. Do not modify anything else.
// All pipeline logic lives in the shared library.
// ─────────────────────────────────────────────────────────────────────────────

@Library('jenkins-shared-lib@main') _

buildPipeline(

  appName:         'YOUR_SERVICE_NAME',
  dockerHubRepo:   'DOCKERHUB_USERNAME/YOUR_IMAGE_NAME',
  gitOpsRepo:      'GITOPS_REPO_URL',
  helmValuePath:   'charts/YOUR_SERVICE_NAME/values.yaml',
  sonarProjectKey: 'YOUR_PROJECT_KEY',
  argoApp:         'YOUR_SERVICE_NAME',

  // Optional overrides — remove any line you don't need to change
  gitOpsBranch:    'main',
  argoAutoSync:    false,
  slackChannel:    '#deployments',
  dockerfile:      'Dockerfile',
  buildContext:    '.'

)
```

Add a comment block at the top of the template explaining each field in one line.

---

## PART 2 — GITOPS REPOSITORY

Generate one complete Helm chart per service in SERVICES list.
Generate one ArgoCD Application manifest per service.

### `charts/<service>/Chart.yaml`

```yaml
apiVersion: v2
name: <service>
description: <service> microservice — managed by Helm and deployed via ArgoCD
type: application
version: 0.1.0
appVersion: "latest"
maintainers:
  - name: DevSecOps Team
```

### `charts/<service>/values.yaml`

Must include these keys exactly as shown — `updateGitOps.groovy` writes to `.image.tag`:

```yaml
# ─── Replica & Scaling ────────────────────────────────────────────────────────
replicaCount: 2

# ─── Image ────────────────────────────────────────────────────────────────────
image:
  repository: DOCKERHUB_USERNAME/SERVICE_NAME   # updated by Jenkins via yq
  tag: latest                                    # ← bumped automatically on every main push
  pullPolicy: IfNotPresent

# ─── Service ──────────────────────────────────────────────────────────────────
service:
  type: ClusterIP
  port: 80
  targetPort: SERVICE_PORT

# ─── Resources ────────────────────────────────────────────────────────────────
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# ─── Autoscaling ──────────────────────────────────────────────────────────────
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

# ─── Health Checks ────────────────────────────────────────────────────────────
livenessProbe:
  httpGet:
    path: /health
    port: SERVICE_PORT
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: SERVICE_PORT
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

# ─── Security ─────────────────────────────────────────────────────────────────
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# ─── Misc ─────────────────────────────────────────────────────────────────────
podAnnotations: {}
nodeSelector: {}
tolerations: []
affinity: {}
```

### `charts/<service>/templates/_helpers.tpl`

Standard Helm helpers:
- `chart.name`          → `.Chart.Name`
- `chart.fullname`      → truncate to 63 chars using release name + chart name
- `chart.labels`        → standard K8s recommended labels block
- `chart.selectorLabels`→ `app.kubernetes.io/name` and `app.kubernetes.io/instance`
Include a comment explaining the 63-char limit and why it exists.

### `charts/<service>/templates/deployment.yaml`

- Use `chart.fullname` and `chart.labels` from helpers
- `strategy: RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0`
  (comment: zero-downtime — always have full replica count during rollout)
- Apply `podSecurityContext` from values
- Apply `containerSecurityContext` from values
- `image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"` — never hardcode
- Both `livenessProbe` and `readinessProbe` from values
- `resources` from values
- Standard K8s recommended labels on both Deployment and Pod template

### `charts/<service>/templates/service.yaml`

- ClusterIP
- Port and targetPort from values
- Selector uses `chart.selectorLabels`

### `charts/<service>/templates/hpa.yaml`

- Gated: `{{- if .Values.autoscaling.enabled }}`
- Targets the Deployment
- minReplicas, maxReplicas, targetCPUUtilizationPercentage all from values
- Use `autoscaling/v2` API version

### `argocd/project.yaml`

ArgoCD AppProject:
- name: ARGO_PROJECT
- description: "PROJECT_NAME — managed by ArgoCD"
- sourceRepos: [GITOPS_REPO_URL]
- destinations: server: https://kubernetes.default.svc, namespace: K8S_NAMESPACE
- clusterResourceWhitelist: [{group: '', kind: Namespace}]
- namespaceResourceWhitelist: Deployment, Service, HPA, ConfigMap, Secret, ServiceAccount
- orphanedResources: warn: true
  (comment: warns if resources exist in cluster but not in git — catches drift)
- roles:
    - name: pipeline
      description: Used by Jenkins ArgoCD token — sync only, no create/delete
      policies:
        - p, proj:ARGO_PROJECT:pipeline, applications, sync, ARGO_PROJECT/*, allow
        - p, proj:ARGO_PROJECT:pipeline, applications, get,  ARGO_PROJECT/*, allow

### `argocd/apps/<service>-app.yaml` — one per service

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <service>
  namespace: argocd
  labels:
    project: PROJECT_NAME
  finalizers:
    - resources-finalizer.argocd.argoproj.io
    # ↑ cascade delete: removing this Application also removes K8s resources
spec:
  project: ARGO_PROJECT
  source:
    repoURL: https://GITOPS_REPO_URL
    targetRevision: GITOPS_BRANCH
    path: charts/<service>
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: K8S_NAMESPACE
  syncPolicy:
    automated:
      prune: true       # remove resources deleted from git
      selfHeal: true    # revert manual kubectl changes — git is source of truth
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 3
```

### `argocd/app-of-apps.yaml`

Root Application pointing to `argocd/apps/` folder.
Managing this single resource bootstraps the entire system.
Add a comment block at the top explaining the App of Apps pattern:
"Apply this once with kubectl. ArgoCD then manages every other Application manifest
 in argocd/apps/ automatically. Adding a new service = adding a new file in argocd/apps/."
Same syncPolicy (automated, prune, selfHeal).

### `gitops-repo/README.md`

- App of Apps ASCII diagram
- Bootstrap command: `kubectl apply -f argocd/app-of-apps.yaml`
- Namespace setup: `kubectl create namespace K8S_NAMESPACE`
- How image tags get bumped (Jenkins → yq → git commit → ArgoCD detects diff)
- How to rollback: `argocd app rollback <service> <revision-number>`
- How to manually sync: `argocd app sync <service>`
- How to add a new service (add chart folder + add ArgoCD app manifest)
- Folder structure explanation

---

## PART 3 — DEVSECOPS CONFIGS

### `devsecops/sonarqube/sonar-project.properties`

```properties
# Base SonarQube config — copy to your project root or reference from CI
# Note: sonar.projectKey is overridden by -D flag in runSonarScan.groovy
#       so this file primarily sets exclusions and encoding defaults

sonar.sources=.
sonar.sourceEncoding=UTF-8

# Exclude generated, vendored, and test code from analysis
sonar.exclusions=\
  **/vendor/**,\
  **/node_modules/**,\
  **/*.test.*,\
  **/*.spec.*,\
  **/test/**,\
  **/tests/**,\
  **/__mocks__/**,\
  **/mock*/**,\
  **/generated/**,\
  **/*.pb.go

# Coverage reports — uncomment and set path when coverage is integrated
# sonar.go.coverage.reportPaths=coverage.out
# sonar.javascript.lcov.reportPaths=coverage/lcov.info
# sonar.python.coverage.reportPaths=coverage.xml
```

### `devsecops/sonarqube/quality-gate-setup.md`

Step-by-step guide to create a Quality Gate named `strict-gate` in SonarQube UI.
Conditions with exact values:

| Metric                        | Operator | Threshold | On        |
|-------------------------------|----------|-----------|-----------|
| Bugs                          | >        | 0         | New Code  |
| Vulnerabilities               | >        | 0         | New Code  |
| Security Hotspots Reviewed    | <        | 100%      | New Code  |
| Code Smells                   | >        | 10        | New Code  |
| Coverage                      | <        | 70%       | New Code  |
| Duplicated Lines (%)          | >        | 3%        | New Code  |

- How to set as default gate
- How to link a project to a specific gate
- What "New Code" period means and how to configure it (last 30 days recommended)
- How the Jenkins `waitForQualityGate` step receives the result (SonarQube webhook)
- How to configure the SonarQube webhook to Jenkins:
  `SonarQube → Administration → Webhooks → Create → URL: http://JENKINS_URL/sonarqube-webhook/`

### `devsecops/owasp/suppressions.xml`

Full valid XML. 5 suppressions:
1. Test-scope dep (JUnit/pytest/mocha) — never in production runtime
2. Build toolchain false positive (maven-wrapper, npm scripts)
3. CVE affecting a different product with the same package name — path-scoped
4. Time-boxed: expires 90 days from today — include `<until>` element with comment
   "MUST be reviewed and either renewed or removed by this date"
5. Suppress by SHA-1 fingerprint (most precise suppression method) with comment
   explaining why SHA fingerprint is preferred over CPE for accuracy

### `devsecops/owasp/setup.md`

- Download and install OWASP DC CLI to `/opt/dependency-check/`
- How to get NVD API key (URL: https://nvd.nist.gov/developers/request-an-api-key)
- How to add `nvd-api-key` to Jenkins Credentials Store (UI steps)
- Full annotated CLI command (every flag explained inline)
- What `--failOnCVSS 8` means (CVSS scale 0-10, 8+ = Critical/High)
- How to tune the threshold for your risk appetite
- Difference between HTML report (human review) and XML report (Jenkins plugin)

### `devsecops/trivy/.trivyignore`

5 entries. Each must have:
```
# CVE-XXXX-XXXXX
# Reason: <why it's not exploitable in this context>
# Review by: <date 90 days from now>
CVE-XXXX-XXXXX
```
Include a header comment block: what this file does, how Trivy reads it,
the review policy ("every entry must have a review date — no indefinite ignores").

### `devsecops/trivy/setup.md`

- Install Trivy on Ubuntu (apt repo method — full commands)
- Install Trivy on macOS (`brew install aquasecurity/trivy/trivy`)
- Update Trivy vulnerability DB: `trivy image --download-db-only`
- Explanation of every flag used in `runTrivyScan.groovy`
- CRITICAL vs HIGH: what they mean, how pipeline handles each
- How to read the JSON report: key fields (VulnerabilityID, PkgName, Severity, FixedVersion)
- What to do when Trivy blocks your build: check FixedVersion, update dep, or add to .trivyignore with justification

### `devsecops/README.md`

Table — DevSecOps tools overview:

| Tool             | Scans                          | Stage in Pipeline     | Failure behavior                        |
|------------------|--------------------------------|-----------------------|-----------------------------------------|
| OWASP DC         | Third-party dependency CVEs    | Before build          | Fails if CVSS ≥ 8 found                |
| SonarQube        | Source code (SAST)             | Before build          | Fails if Quality Gate not passed        |
| Trivy            | Container image layers         | After build           | Fails if CRITICAL CVE found in image   |

- Shift-left explanation: why security runs before the build, not after deployment
- How to suppress false positives in each tool (one paragraph each)
- Quick-reference commands: re-run each scan locally before pushing
- Links to official docs

---

## CREDENTIALS_SETUP.md (generate last)

One comprehensive file listing every credential the pipeline needs:

| Credential ID          | Jenkins Type            | How to get the value                                              |
|------------------------|-------------------------|-------------------------------------------------------------------|
| `dockerhub-creds`      | Username + Password     | Docker Hub → Account Settings → Security → New Access Token      |
| `nvd-api-key`          | Secret Text             | https://nvd.nist.gov/developers/request-an-api-key               |
| `sonar-token`          | Secret Text             | SonarQube → My Account → Security → Generate Token               |
| `sonar-url`            | Secret Text             | Your SonarQube server URL e.g. http://sonarqube.yourdomain.com   |
| `github-gitops-creds`  | Username + Password     | GitHub → Settings → Developer Settings → Personal Access Tokens  |
| `argocd-token`         | Secret Text             | `argocd account generate-token --account jenkins`                 |
| `argocd-server`        | Secret Text             | Your ArgoCD server hostname e.g. argocd.yourdomain.com            |

For each credential, include:
- The exact Jenkins UI path: Manage Jenkins → Credentials → System → Global → Add Credentials
- Which credential Type to select from the dropdown
- What to put in each field (ID, Description, Username, Password/Secret)

Also include: ArgoCD Jenkins account setup (add to argocd-cm ConfigMap, grant pipeline role).

---

## FINAL CHECK — after generating all files, print this table:

```
| File                                     | Purpose (one line)                              | Replace before use          |
|------------------------------------------|-------------------------------------------------|-----------------------------|
| Jenkinsfile.template                     | Copy into each service repo                     | 6 values at top             |
| jenkins-shared-lib/vars/buildPipeline..  | Pipeline orchestrator                           | Nothing — generic           |
| gitops-repo/charts/<svc>/values.yaml     | Per-service Helm values                         | image.repository            |
| gitops-repo/argocd/apps/<svc>-app.yaml   | ArgoCD Application                              | repoURL, namespace          |
| CREDENTIALS_SETUP.md                     | Credential setup guide                          | Your actual values          |
...
```

List every file. Mark anything that needs a `find-and-replace` before use.

---

## BEGIN

Start with PART 1. Announce each file:
`### File: path/to/filename`
Write the complete file in a fenced code block.
Do not summarize or skip. Write every file in full.
