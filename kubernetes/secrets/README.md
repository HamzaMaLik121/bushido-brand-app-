# Bushido Brand — K8s Secrets

## Quick Apply

```bash
# Create the bushido-brand namespace (if not already created)
kubectl create namespace bushido-brand --dry-run=client -o yaml | kubectl apply -f -

# Apply all secrets
kubectl apply -f kubernetes/secrets/mysql-secrets.yaml -n bushido-brand
kubectl apply -f kubernetes/secrets/backend-secrets.yaml -n bushido-brand

# Verify
kubectl get secrets -n bushido-brand
```

## Secrets Summary

| Secret Name | Key | Purpose | Referenced By |
|---|---|---|---|
| `mysql-root-password` | `password` | MySQL root password | `charts/db` StatefulSet |
| `mysql-user-password` | `password` | MySQL application user password | `charts/db` StatefulSet |
| `backend-database-url` | `database-url` | SQLAlchemy connection string | `charts/backend` Deployment |
| `backend-secret-key` | `secret-key` | Flask session signing | `charts/backend` Deployment |
| `backend-jwt-secret-key` | `jwt-secret-key` | JWT token signing | `charts/backend` Deployment |

## Credential Values

| User | Password |
|---|---|
| MySQL `root` | `olTnrtMcSV0s/8q8oeFVHLRyrC0fKA2BzYGqbeUlN5w=` |
| MySQL `bushido_user` | `5d30eeda4fc41abf15af94d418104455` |

## Regenerating Secrets (Production)

For production, regenerate these secrets:

```bash
# MySQL root password
openssl rand -base64 32

# MySQL application user password (hex to avoid URL encoding issues in connection string)
openssl rand -hex 16

# Flask secret key
openssl rand -base64 32

# JWT secret key
openssl rand -base64 16
```

Then update:
1. The password in both `mysql-user-password` and `backend-database-url` secrets
2. Run `kubectl apply -f ...` to update
3. Restart backend pods to pick up new values
