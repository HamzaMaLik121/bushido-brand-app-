#!/bin/bash
set -e

# ─── Determine MySQL host ────────────────────────────────────────
# Supports:
#   docker-compose: service is named "db"
#   Kubernetes:     service is named "mysql" (per Helm chart)
#   Override via MYSQL_HOST env var
MYSQL_HOST="${MYSQL_HOST:-db}"     # default 'db' (Docker Compose); override to 'mysql' via Helm chart
MYSQL_PORT="${MYSQL_PORT:-3306}"

echo "Waiting for MySQL at ${MYSQL_HOST}:${MYSQL_PORT}..."
while ! nc -z "${MYSQL_HOST}" "${MYSQL_PORT}" 2>/dev/null; do
  sleep 1
done
echo "MySQL is up — starting Gunicorn"

# Start Gunicorn
exec gunicorn --bind 0.0.0.0:5000 --workers 4 --threads 2 app:app
