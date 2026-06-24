#!/bin/bash

echo "Waiting for MySQL..."
while ! nc -z db 3306; do
  sleep 1
done
echo "MySQL is up"

# Start Gunicorn
exec gunicorn --bind 0.0.0.0:5000 --workers 4 --threads 2 app:app
