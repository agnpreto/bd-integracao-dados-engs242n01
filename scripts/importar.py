import os
import re
from datetime import time
import pandas as pd

# ── Configurações via variáveis de ambiente (sem senha fixa no código) ──
DB_TIPO = os.getenv("DB_TIPO", "postgres").lower()
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432" if DB_TIPO == "postgres" else "3306"))
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "senha_exemplo")

ARQUIVO = os.path.join(os.path.dirname(__file__), "..", "dados", "base_teste.xlsx")


def conectar():
    if DB_TIPO == "mysql":
        import pymysql
        return pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            autocommit=False,
        )
    import psycopg2
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )


def limpar_texto(valor):
    if pd.isna(valor):
        return None
    texto = str(valor).strip()
    return texto if texto != "" else None


def para_data(valor):
    if pd.isna(valor):
        return None
    return pd.Timestamp(valor).date()


def para_hora(valor):
    if pd.isna(valor):
        return time(0, 0, 0)
    if isinstance(valor, time):
        return valor
    texto = str(valor).strip()
    partes = [int(p) for p in texto.split(":")]
    return time(partes[0], partes[1], partes[2] if len(partes) > 2 else 0)


def id_fornecedor(valor):
    if pd.isna(valor):
        return None
    digitos = re.sub(r"\D", "", str(valor))
    return int(digitos) if digitos else None


def importar():
    conn = conectar()
    cur = conn.cursor()
    contagens_planilha = {}

    try:
        # 1. FORNECEDOR
        print("Importando fornecedor...")
        df_forn = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
        df_forn.columns = df_forn.columns.str.strip()
        contagens_planilha["fornecedor"] = len(df_forn)

        for _, row in df_forn.iterrows():
            cod = limpar_texto(row["idfornecedor"])
            fid = id_fornecedor(cod)
            razao = limpar_texto(row["razao_social"])
            cur.execute(
                "INSERT INTO fornecedor (idfornecedor, codigo_origem, razao_social) VALUES (%s, %s, %s)",
                (fid, cod, razao),
            )

        # 2. PRODUTOS_FILIAL
        print("Importando produtos_filial...")
        df_prod = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
        df_prod.columns = df_prod.columns.str.strip()
        contagens_planilha["produtos_filial"] = len(df_prod)

        for _, row in df_prod.iterrows():
            cur.execute(
                """INSERT INTO produtos_filial
                    (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    limpar_texto(row["idproduto"]),
                    limpar_texto(row["descricao"]),
                    float(row["estoque"]) if pd.notna(row["estoque"]) else 0,
                    float(row["preco_unitario"]) if pd.notna(row["preco_unitario"]) else 0,
                    float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
                    float(row["preco_venda"]) if pd.notna(row["preco_venda"]) else 0,
                    id_fornecedor(row["idfornecedor"]),
                ),
            )

        # 3. PEDIDO_COMPRA (ignora colunas sem cabeçalho M a W)
        print("Importando pedido_compra...")
        df_ped = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
        df_ped.columns = df_ped.columns.str.strip()
        colunas_validas = [c for c in df_ped.columns if not str(c).startswith("Unnamed")]
        descartadas = len(df_ped.columns) - len(colunas_validas)
        if descartadas > 0:
            print(f"  Aviso: {descartadas} colunas sem cabeçalho ignoradas em pedido_compra.")
        df_ped = df_ped[colunas_validas]
        contagens_planilha["pedido_compra"] = len(df_ped)

        for _, row in df_ped.iterrows():
            ordem = 0 if pd.isna(row["ordem_compra"]) else int(row["ordem_compra"])
            cur.execute(
                """INSERT INTO pedido_compra
                    (pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra,
                     qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    int(row["pedido_id"]),
                    para_data(row["data_pedido"]),
                    int(row["item"]),
                    limpar_texto(row["produto_id"]),
                    limpar_texto(row["descricao_produto"]),
                    ordem,
                    float(row["qtde_pedida"]) if pd.notna(row["qtde_pedida"]) else None,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    para_data(row["data_entrega"]),
                    float(row["qtde_entregue"]) if pd.notna(row["qtde_entregue"]) else 0,
                    float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
                    id_fornecedor(row["fornecedor_id"]),
                ),
            )

        # 4. ENTRADAS_MERCADORIA
        print("Importando entradas_mercadoria...")
        df_ent = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
        df_ent.columns = df_ent.columns.str.strip()
        contagens_planilha["entradas_mercadoria"] = len(df_ent)

        for _, row in df_ent.iterrows():
            cur.execute(
                """INSERT INTO entradas_mercadoria
                    (data_entrada, nro_nfe, item, ordem_compra, produto_id, descricao_produto,
                     qtde_recebida, filial_id, custo_unitario)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    para_data(row["data_entrada"]),
                    limpar_texto(row["nro_nfe"]),
                    int(row["item"]),
                    int(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
                    limpar_texto(row["produto_id"]),
                    limpar_texto(row["descricao_produto"]),
                    float(row["qtde_recebida"]) if pd.notna(row["qtde_recebida"]) else None,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    float(row["custo_unitario"]) if pd.notna(row["custo_unitario"]) else 0,
                ),
            )

        # 5. VENDA
        print("Importando venda...")
        df_venda = pd.read_excel(ARQUIVO, sheet_name="venda")
        df_venda.columns = df_venda.columns.str.strip()
        contagens_planilha["venda"] = len(df_venda)

        for _, row in df_venda.iterrows():
            cur.execute(
                """INSERT INTO venda
                    (venda_id, data_emissao, horariomov, produto_id, qtde_vendida,
                     valor_unitario, filial_id, item, unidade_medida)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    int(row["venda_id"]),
                    para_data(row["data_emissao"]),
                    para_hora(row["horariomov"]),
                    limpar_texto(row["produto_id"]),
                    float(row["qtde_vendida"]) if pd.notna(row["qtde_vendida"]) else None,
                    float(row["valor_unitario"]) if pd.notna(row["valor_unitario"]) else 0,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
                    int(row["item"]) if pd.notna(row["item"]) else 1,
                    limpar_texto(row["unidade_medida"]),
                ),
            )

        # Sincroniza a sequência do IDENTITY no PostgreSQL após inserção manual dos IDs 1..20
        if DB_TIPO == "postgres":
            cur.execute(
                "SELECT setval(pg_get_serial_sequence('fornecedor', 'idfornecedor'), COALESCE(MAX(idfornecedor), 1)) FROM fornecedor"
            )

        conn.commit()
        print("\n========================================")
        print("Importação concluída em transação única!")
        print("========================================")
        for tabela, qtd_planilha in contagens_planilha.items():
            cur.execute(f"SELECT COUNT(*) FROM {tabela}")
            qtd_banco = cur.fetchone()[0]
            status = "OK" if qtd_planilha == qtd_banco else "DIVERGENTE"
            print(f" - {tabela}: planilha={qtd_planilha} | banco={qtd_banco} [{status}]")

    except Exception as erro:
        conn.rollback()
        print(f"Erro na importação. Transação desfeita: {erro}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    importar()