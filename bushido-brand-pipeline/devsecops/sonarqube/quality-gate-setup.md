# SonarQube Strict Quality Gate Setup Guide

To protect the production release from vulnerabilities, a strict quality gate must be registered in your SonarQube Console UI.

## Quality Gate Specifications
Name the gate: `strict-gate`

Configure the following metric parameters under the **New Code** analysis group:

| Metric | Operator | Failure Limit | Goal / Rationale |
|---|---|---|---|
| **Bugs** | `>` | `0` | Prevent general coding failures |
| **Vulnerabilities** | `>` | `0` | Block known code exploits (CWE check) |
| **Security Hotspots Reviewed** | `<` | `100%` | Enforce audits on security-sensitive code sections |
| **Code Smells** | `>` | `10` | Enforce clean coding standards |
| **Coverage** | `<` | `70%` | Warn/abort if test coverage drops below baseline |
| **Duplicated Lines (%)** | `>` | `3%` | Prevent redundant code replication |

## UI Configuration Workflow
1. Log in to SonarQube as Administrator.
2. Select **Quality Gates** from top navigation panel, click **Create**.
3. Input name: `strict-gate` and select **Save**.
4. Click **Add Condition**, select **On New Code**, then configure each condition based on the table above.
5. Select **Set as Default** to enforce these conditions globally on all scanning projects.

## Linking Webhooks
To notify the Jenkins runner when scans finish:
1. Navigate to **Administration** -> **Configuration** -> **Webhooks**.
2. Click **Create** and configure target endpoint:
   * **URL:** `http://<your-jenkins-server>/sonarqube-webhook/`
