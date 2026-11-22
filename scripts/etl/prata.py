# ── PRATA: conversões, como no script original ────────────
# As expressões de cada tupla são as mesmas que estavam dentro do cur.execute(...)
# de cada bloco do importar.py original.
import pandas as pd
from datetime import datetime, timedelta


# ── Converte serial do Excel para data ─────────────────────
def excel_para_data(valor):
    if pd.isna(valor):
        return None
    if isinstance(valor, (pd.Timestamp, datetime)):      
        return valor.date()
    if isinstance(valor, (int, float)):                 
        return (datetime(1899, 12, 30) + timedelta(days=int(valor))).date()
    raise ValueError(f"data em formato inesperado: {valor!r}")


# 1. FORNECEDOR
def linha_fornecedor(row):
    return (
        str(row["idfornecedor"]).strip(),
        str(row["razao_social"]).strip()
    )


# 2. PRODUTOS_FILIAL
def linha_produtos_filial(row):
    return (
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        str(row["idproduto"]).strip(),
        str(row["descricao"]).strip(),
        float(row["estoque"]) if pd.notna(row["estoque"]) else 0,
        float(row["preco_unitario"]) if pd.notna(row["preco_unitario"]) else 0,
        float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
        float(row["preco_venda"]) if pd.notna(row["preco_venda"]) else 0,
        str(row["idfornecedor"]).strip() if pd.notna(row["idfornecedor"]) else None
    )


# 3. PEDIDO_COMPRA
def preparar_pedido_compra(df):
    df = df.iloc[:, :12]
    df.columns = ["pedido_id","data_pedido","item","produto_id","descricao_produto",
                  "ordem_compra","qtde_pedida","filial_id","data_entrega",
                  "qtde_entregue","preco_compra","fornecedor_id"]
    return df


def linha_pedido_compra(row):
    return (
        float(row["pedido_id"]),
        excel_para_data(row["data_pedido"]),
        float(row["item"]),
        str(row["produto_id"]).strip(),
        str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
        float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
        float(row["qtde_pedida"]) if pd.notna(row["qtde_pedida"]) else None,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        excel_para_data(row["data_entrega"]),
        float(row["qtde_entregue"]) if pd.notna(row["qtde_entregue"]) else 0,
        float(row["qtde_pedida"]) - float(row["qtde_entregue"])
            if pd.notna(row["qtde_pedida"]) and pd.notna(row["qtde_entregue"]) else 0,
        float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
        int(row["fornecedor_id"]) if pd.notna(row["fornecedor_id"]) else None
    )


# 4. ENTRADAS_MERCADORIA
def linha_entradas_mercadoria(row):
    return (
        excel_para_data(row["data_entrada"]),
        str(row["nro_nfe"]).strip(),
        float(row["item"]),
        str(row["produto_id"]).strip(),
        str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
        float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
        float(row["qtde_recebida"]) if pd.notna(row["qtde_recebida"]) else None,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        float(row["custo_unitario"]) if pd.notna(row["custo_unitario"]) else 0
    )


# 5. VENDA
def linha_venda(row):
    return (
        int(row["venda_id"]),
        excel_para_data(row["data_emissao"]),
        str(row["horariomov"]).strip() if pd.notna(row["horariomov"]) else "00:00:00",
        str(row["produto_id"]).strip(),
        float(row["qtde_vendida"]) if pd.notna(row["qtde_vendida"]) else None,
        float(row["valor_unitario"]) if pd.notna(row["valor_unitario"]) else 0,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
        int(row["item"]) if pd.notna(row["item"]) else 0,
        str(row["unidade_medida"]).strip() if pd.notna(row["unidade_medida"]) else None
    )
