# Importa dados/base_teste.xlsx para o PostgreSQL em camadas (arquitetura medalhão).
# O código é o do script original, repartido em scripts/etl/ sem mudança de lógica:
#   bronze.py -> leitura   |   prata.py -> conversões   |   carga.py -> INSERT
#
# Uso (na raiz do projeto):  .venv\Scripts\python.exe scripts\importar.py
import psycopg2

from etl.config import DB
from etl import bronze, prata, carga

# ── Conecta no banco ───────────────────────────────────────
print("Conectando no PostgreSQL...")
conn = psycopg2.connect(**DB)
cur = conn.cursor()
print("Conectado!\n")


# 1. FORNECEDOR
print("Importando fornecedor...")
df = bronze.ler_fornecedor()
carga.carregar_fornecedor(conn, cur, df)


# 2. PRODUTOS_FILIAL
print("Importando produtos_filial...")
df = bronze.ler_produtos_filial()
carga.carregar_produtos_filial(conn, cur, df)


# 3. PEDIDO_COMPRA
print("Importando pedido_compra...")
df = bronze.ler_pedido_compra()
df = prata.preparar_pedido_compra(df)
carga.carregar_pedido_compra(conn, cur, df)


# 4. ENTRADAS_MERCADORIA
print("Importando entradas_mercadoria...")
df = bronze.ler_entradas_mercadoria()
carga.carregar_entradas_mercadoria(conn, cur, df)


# 5. VENDA
print("Importando venda...")
df = bronze.ler_venda()
carga.carregar_venda(conn, cur, df)


cur.close()
conn.close()
print("=" * 40)
print("Importação concluída com sucesso! ")
print("=" * 40)
