# ── Configurações (topo do importar.py original) ──────────
import os
from pathlib import Path

from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parents[2]   # scripts/etl/config.py -> raiz do projeto
load_dotenv(RAIZ / ".env")

ARQUIVO = RAIZ / "dados" / "base_teste.xlsx"
SCHEMA = os.getenv("DB_SCHEMA", "integracao")
DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "postgres"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}
