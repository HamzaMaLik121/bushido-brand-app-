import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'bushido-secret-key-2026')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'bushido-jwt-secret')
    JWT_EXPIRATION_HOURS = 24
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # ─── Database URL ────────────────────────────────────────────────────────
    # Priority:
    #   1. DATABASE_URL env var (explicit full URL)
    #   2. Build from individual MYSQL_* env vars (used by Helm chart on K8s)
    #   3. Fallback default for docker-compose
    _database_url = os.getenv('DATABASE_URL')
    if not _database_url:
        _host = os.getenv('MYSQL_HOST', 'db')
        _port = os.getenv('MYSQL_PORT', '3306')
        _db   = os.getenv('MYSQL_DATABASE', 'bushido_db')
        _user = os.getenv('MYSQL_USER', 'root')
        _pass = os.getenv('MYSQL_PASSWORD', os.getenv('MYSQL_ROOT_PASSWORD', 'rootpassword'))
        _database_url = f'mysql+pymysql://{_user}:{_pass}@{_host}:{_port}/{_db}'
    SQLALCHEMY_DATABASE_URI = _database_url
