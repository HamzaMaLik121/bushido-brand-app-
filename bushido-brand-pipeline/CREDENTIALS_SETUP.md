# Jenkins and ArgoCD Credential Provisioning Guide — bushido-brand

Use this guide to register credentials inside your Jenkins credentials store and ArgoCD namespace before launching the build pipelines.

## Credentials Registry Mapping

| Credential ID | Jenkins Credentials Type | Intended Value and Origin |
|---|---|---|
| `dockerhub-creds` | Username with Password | Docker Hub Account Username + Access Token (generate at Docker Hub -> Account Settings -> Security -> New Access Token) |
| `OWASP` | Secret Text | NVD query token for OWASP Dependency-Check (generate at `nvd.nist.gov/developers/request-an-api-key`) |
| `SONAR` | Secret Text | SonarQube server URL (e.g. `http://sonarqube.internal:9000`). The SonarQube access token is configured globally in Jenkins under Manage Jenkins -> Configure System -> SonarQube servers -> Server authentication token. |
| `Github-cred` | Username with Password | GitHub Account Username + Personal Access Token (PAT) containing `repo` write scope |
| `argocd-token` | Secret Text | ArgoCD CLI authentication token (run `argocd account generate-token`) |
| `argocd-server` | Secret Text | Connection hostname endpoint of the ArgoCD server (e.g., `argocd.internal`) |

## Step-by-Step Jenkins UI Entry Process
To add any credential to the Jenkins system:
1. Log in to Jenkins as Administrator.
2. Select **Manage Jenkins** -> **Credentials**.
3. Under **Stores scoped to Jenkins**, click the **(global)** domains link.
4. Select **Add Credentials** on the top right.
5. In the **Kind** dropdown, select the target type mapping from the table above.
6. Populate the **ID** field with the exact identifier string.
7. Fill in the credentials secrets and descriptions, then save.

## Enforcing ArgoCD Pipeline Permissions
Allow Jenkins to sync applications by updating ArgoCD's config map and creating the service token:

1. Update the `argocd-cm` ConfigMap to register the service account:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-cm
     namespace: argocd
   data:
     accounts.jenkins: apiKey
   ```
2. Apply the configuration.
3. Grant access role permissions inside the `argocd-rbac-cm` ConfigMap:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-rbac-cm
     namespace: argocd
   data:
     policy.csv: |
       g, jenkins, role:pipeline
   ```
4. Authenticate via ArgoCD CLI to extract the token:
   ```bash
   argocd login <argocd-server> --username admin --password <password>
   argocd account generate-token --account jenkins
   ```
5. Place the returned token string inside Jenkins under the `argocd-token` credentials entry.
