# ── BRONZE: leitura das abas, como no script original ─────
import pandas as pd

from .config import ARQUIVO


# 1. FORNECEDOR
def ler_fornecedor():
    df = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
    df.columns = df.columns.str.strip()
    return df


# 2. PRODUTOS_FILIAL
def ler_produtos_filial():
    df = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
    df.columns = df.columns.str.strip()
    return df


# 3. PEDIDO_COMPRA
def ler_pedido_compra():
    df = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
    df.columns = df.columns.str.strip()
    return df


# 4. ENTRADAS_MERCADORIA
def ler_entradas_mercadoria():
    df = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
    df.columns = df.columns.str.strip()
    return df


# 5. VENDA
def ler_venda():
    df = pd.read_excel(ARQUIVO, sheet_name="venda")
    df.columns = df.columns.str.strip()
    return df
