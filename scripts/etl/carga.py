# ── CARGA: INSERT no banco, como no script original ───────
# Os laços for/try/rollback e os prints são os mesmos de cada bloco do
# importar.py original; os valores de cada linha vêm das funções da prata.
from .config import SCHEMA
from .prata import (linha_fornecedor, linha_produtos_filial, linha_pedido_compra,
                    linha_entradas_mercadoria, linha_venda)


# 1. FORNECEDOR
def carregar_fornecedor(conn, cur, df):
    for _, row in df.iterrows():
        try:
            cur.execute(f"""
                INSERT INTO {SCHEMA}.fornecedor (idfornecedor, razao_social)
                VALUES (%s, %s)
                ON CONFLICT (idfornecedor) DO NOTHING
            """, linha_fornecedor(row))
        except Exception as e:
            print(f"  Erro fornecedor: {e}")
            conn.rollback()
            continue

    conn.commit()
    print(f"  {len(df)} registros inseridos em fornecedor \n")


# 2. PRODUTOS_FILIAL
def carregar_produtos_filial(conn, cur, df):
    for _, row in df.iterrows():
        try:
            cur.execute(f"""
                INSERT INTO {SCHEMA}.produtos_filial
                    (filial_id, produto_id, descricao, estoque,
                     preco_unitario, preco_compra, preco_venda, idfornecedor)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (filial_id, produto_id) DO NOTHING
            """, linha_produtos_filial(row))
        except Exception as e:
            print(f"  Erro produtos_filial linha {_}: {e}")
            conn.rollback()
            continue

    conn.commit()
    print(f"  {len(df)} registros inseridos em produtos_filial \n")


# 3. PEDIDO_COMPRA
def carregar_pedido_compra(conn, cur, df):
    inseridos = 0
    for _, row in df.iterrows():
        try:
            cur.execute(f"""
                INSERT INTO {SCHEMA}.pedido_compra
                    (pedido_id, data_pedido, item, produto_id, descricao_produto,
                     ordem_compra, qtde_pedida, filial_id, data_entrega,
                     qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
            """, linha_pedido_compra(row))
            inseridos += 1
        except Exception as e:
            print(f"  Erro pedido_compra linha {_}: {e}")
            conn.rollback()
            continue

    conn.commit()
    print(f"  {inseridos} registros inseridos em pedido_compra \n")


# 4. ENTRADAS_MERCADORIA
def carregar_entradas_mercadoria(conn, cur, df):
    for _, row in df.iterrows():
        try:
            cur.execute(f"""
                INSERT INTO {SCHEMA}.entradas_mercadoria
                    (data_entrada, nro_nfe, item, produto_id, descricao_produto,
                     ordem_compra, qtde_recebida, filial_id, custo_unitario)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
            """, linha_entradas_mercadoria(row))
        except Exception as e:
            print(f"  Erro entradas_mercadoria linha {_}: {e}")
            conn.rollback()
            continue

    conn.commit()
    print(f"  {len(df)} registros inseridos em entradas_mercadoria \n")


# 5. VENDA
def carregar_venda(conn, cur, df):
    for _, row in df.iterrows():
        try:
            cur.execute(f"""
                INSERT INTO {SCHEMA}.venda
                    (venda_id, data_emissao, horariomov, produto_id,
                     qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
            """, linha_venda(row))
        except Exception as e:
            print(f"  Erro venda linha {_}: {e}")
            conn.rollback()
            continue

    conn.commit()
    print(f"  {len(df)} registros inseridos em venda \n")
