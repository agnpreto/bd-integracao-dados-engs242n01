"""
Importa dados/base_teste.xlsx para o PostgreSQL ou para o MySQL.

Versão CORRIGIDA do script do estagiário (as correções estão listadas em
docs/parte1_importacao.md).

Uso (na raiz do repositório):

    # PostgreSQL (padrão)
    export DB_PASSWORD='sua_senha'        # nunca escreva a senha no código
    python scripts/importar.py

    # MySQL
    export DB_TIPO=mysql DB_PORT=3306 DB_USER=root DB_NAME=loja DB_PASSWORD='sua_senha'
    python scripts/importar.py

Variáveis de ambiente (todas opcionais, valores de exemplo entre parênteses):
    DB_TIPO (postgres | mysql)   DB_HOST (localhost)   DB_PORT (5432 ou 3306)
    DB_NAME (postgres)           DB_USER (postgres)    DB_PASSWORD (vazio)
    ARQUIVO_XLSX (dados/base_teste.xlsx)

Dependências: pip install pandas openpyxl psycopg2-binary pymysql
O script NÃO cria as tabelas: rode antes sql/01_ddl_postgres.sql (ou
sql/01_ddl_mysql.sql). Pode ser executado várias vezes: ele limpa as tabelas
antes de carregar, então não duplica linhas.
"""
import os
import re
import sys
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from pathlib import Path

import pandas as pd

# ── Configuração (sem senha no código) ─────────────────────────────────────
BASE = Path(__file__).resolve().parent.parent
ARQUIVO = os.environ.get("ARQUIVO_XLSX", str(BASE / "dados" / "base_teste.xlsx"))
TIPO = os.environ.get("DB_TIPO", "postgres").lower()
DB = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 5432 if TIPO == "postgres" else 3306)),
    "database": os.environ.get("DB_NAME", "postgres"),
    "user": os.environ.get("DB_USER", "postgres"),
    "password": os.environ.get("DB_PASSWORD", ""),
}


# ── Conversões (levantam erro em vez de devolver None em silêncio) ─────────
def para_data(valor):
    """Aceita Timestamp/datetime/date (o que o pandas entrega), texto ISO
    ou número serial do Excel. Qualquer outra coisa gera erro."""
    if isinstance(valor, pd.Timestamp):
        if pd.isna(valor):
            raise ValueError("data vazia")
        return valor.date()
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, (int, float)) and not pd.isna(valor):
        return (datetime(1899, 12, 30) + timedelta(days=int(valor))).date()
    if isinstance(valor, str) and valor.strip():
        return datetime.strptime(valor.strip(), "%Y-%m-%d").date()
    raise ValueError(f"data inválida: {valor!r}")


def para_hora(valor):
    if isinstance(valor, time):
        return valor
    if isinstance(valor, datetime):
        return valor.time()
    return datetime.strptime(str(valor).strip(), "%H:%M:%S").time()


def para_decimal(valor):
    if pd.isna(valor):
        raise ValueError("número vazio")
    return Decimal(str(valor))


def para_inteiro(valor):
    if pd.isna(valor):
        raise ValueError("inteiro vazio")
    numero = float(valor)
    if numero != int(numero):
        raise ValueError(f"esperava inteiro, veio {valor!r}")
    return int(numero)


def codigo_fornecedor(valor):
    """'F8' -> 8. O código numérico é o que o DDL corrigido usa nas 3 tabelas."""
    if isinstance(valor, str):
        achado = re.fullmatch(r"\s*[Ff]?\s*(\d+)\s*", valor)
        if not achado:
            raise ValueError(f"código de fornecedor inválido: {valor!r}")
        return int(achado.group(1))
    return para_inteiro(valor)


def texto(valor, obrigatorio=True):
    if pd.isna(valor) or str(valor).strip() == "":
        if obrigatorio:
            raise ValueError("texto vazio")
        return None
    return str(valor).strip()


# ── Definição de cada aba: colunas, conversores e chave primária ───────────
# (coluna na planilha, coluna no banco, conversor)
TABELAS = [
    {
        "tabela": "fornecedor",
        "aba": "fornecedor",
        "pk": ["idfornecedor"],
        "colunas": [
            ("idfornecedor", "idfornecedor", codigo_fornecedor),
            ("razao_social", "razao_social", texto),
        ],
    },
    {
        "tabela": "produtos_filial",
        "aba": "produtos_filial",
        "pk": ["filial_id", "produto_id"],
        "colunas": [
            ("filial_id", "filial_id", para_inteiro),
            ("idproduto", "produto_id", texto),  # na planilha a coluna é "idproduto"
            ("descricao", "descricao", texto),
            ("estoque", "estoque", para_decimal),
            ("preco_unitario", "preco_unitario", para_decimal),
            ("preco_compra", "preco_compra", para_decimal),
            ("preco_venda", "preco_venda", para_decimal),
            ("idfornecedor", "idfornecedor", codigo_fornecedor),
        ],
    },
    {
        "tabela": "pedido_compra",
        "aba": "pedido_compra",
        "pk": ["pedido_id", "produto_id", "item"],
        # qtde_pendente NÃO é importada: no banco ela é calculada (pedida - entregue)
        "colunas": [
            ("pedido_id", "pedido_id", para_inteiro),
            ("data_pedido", "data_pedido", para_data),
            ("item", "item", para_inteiro),
            ("produto_id", "produto_id", texto),
            ("descricao_produto", "descricao_produto", lambda v: texto(v, False)),
            ("ordem_compra", "ordem_compra", para_inteiro),
            ("qtde_pedida", "qtde_pedida", para_decimal),
            ("filial_id", "filial_id", para_inteiro),
            ("data_entrega", "data_entrega", para_data),
            ("qtde_entregue", "qtde_entregue", para_decimal),
            ("preco_compra", "preco_compra", para_decimal),
            ("fornecedor_id", "fornecedor_id", para_inteiro),
        ],
    },
    {
        "tabela": "entradas_mercadoria",
        "aba": "entradas_mercadoria",
        "pk": ["ordem_compra", "item", "produto_id", "nro_nfe"],
        "colunas": [
            ("data_entrada", "data_entrada", para_data),
            ("nro_nfe", "nro_nfe", texto),
            ("item", "item", para_inteiro),
            ("produto_id", "produto_id", texto),
            ("descricao_produto", "descricao_produto", lambda v: texto(v, False)),
            ("ordem_compra", "ordem_compra", para_inteiro),
            ("qtde_recebida", "qtde_recebida", para_decimal),
            ("filial_id", "filial_id", para_inteiro),
            ("custo_unitario", "custo_unitario", para_decimal),
        ],
    },
    {
        "tabela": "venda",
        "aba": "venda",
        "pk": ["filial_id", "venda_id", "data_emissao", "produto_id", "item", "horariomov"],
        "colunas": [
            ("venda_id", "venda_id", para_inteiro),
            ("data_emissao", "data_emissao", para_data),
            ("horariomov", "horariomov", para_hora),
            ("produto_id", "produto_id", texto),
            ("qtde_vendida", "qtde_vendida", para_decimal),
            ("valor_unitario", "valor_unitario", para_decimal),
            ("filial_id", "filial_id", para_inteiro),
            ("item", "item", para_inteiro),
            ("unidade_medida", "unidade_medida", lambda v: texto(v, False)),
        ],
    },
]


def conectar():
    if TIPO == "postgres":
        import psycopg2
        return psycopg2.connect(**DB)
    if TIPO == "mysql":
        import pymysql
        return pymysql.connect(
            host=DB["host"], port=DB["port"], database=DB["database"],
            user=DB["user"], password=DB["password"], charset="utf8mb4",
        )
    sys.exit(f"DB_TIPO inválido: {TIPO!r} (use postgres ou mysql)")


def ler_aba(xls, definicao):
    """Lê a aba pelo NOME das colunas (não pela posição) e ignora colunas extras."""
    df = pd.read_excel(xls, sheet_name=definicao["aba"])
    df.columns = [str(c).strip() for c in df.columns]
    esperadas = [c[0] for c in definicao["colunas"]]
    faltando = [c for c in esperadas if c not in df.columns]
    if faltando:
        raise SystemExit(f"Aba {definicao['aba']}: faltam colunas {faltando}")
    extras = [c for c in df.columns if c not in esperadas]
    extras_com_dado = [c for c in extras if df[c].notna().any()]
    if extras_com_dado:
        linhas = int(df[extras_com_dado].notna().any(axis=1).sum())
        print(f"  Aviso: {len(extras_com_dado)} coluna(s) extra(s) sem cabeçalho com dados "
              f"em {linhas} linha(s) foram IGNORADAS ({', '.join(extras_com_dado[:3])}...).")
    df = df.dropna(how="all", subset=esperadas)
    return df[esperadas]


def converter_linhas(df, definicao):
    """Converte linha a linha. Devolve (linhas_validas, erros)."""
    linhas, erros, vistos = [], [], set()
    nomes_banco = [c[1] for c in definicao["colunas"]]
    for i, (_, linha) in enumerate(df.iterrows(), start=2):  # 2 = 1ª linha de dados no Excel
        try:
            valores = [conv(linha[origem]) for origem, _, conv in definicao["colunas"]]
        except Exception as e:
            erros.append(f"linha {i} da planilha: {e}")
            continue
        registro = dict(zip(nomes_banco, valores))
        chave = tuple(registro[c] for c in definicao["pk"])
        if chave in vistos:
            erros.append(f"linha {i} da planilha: chave duplicada {chave}")
            continue
        vistos.add(chave)
        linhas.append(valores)
    return linhas, erros


def main():
    print(f"Arquivo : {ARQUIVO}")
    print(f"Banco   : {TIPO} em {DB['host']}:{DB['port']}/{DB['database']} (usuário {DB['user']})\n")
    xls = pd.ExcelFile(ARQUIVO)
    conn = conectar()
    cur = conn.cursor()

    # Limpa na ordem inversa das dependências para poder rodar o script de novo
    if TIPO == "mysql":
        cur.execute("SET FOREIGN_KEY_CHECKS = 0")
    for definicao in reversed(TABELAS):
        cur.execute(f"DELETE FROM {definicao['tabela']}")
    if TIPO == "mysql":
        cur.execute("SET FOREIGN_KEY_CHECKS = 1")
    conn.commit()

    resumo = []
    for definicao in TABELAS:
        nome = definicao["tabela"]
        print(f"Importando {nome}...")
        df = ler_aba(xls, definicao)
        linhas, erros = converter_linhas(df, definicao)
        colunas = ", ".join(c[1] for c in definicao["colunas"])
        marcadores = ", ".join(["%s"] * len(definicao["colunas"]))
        try:
            if linhas:
                cur.executemany(f"INSERT INTO {nome} ({colunas}) VALUES ({marcadores})", linhas)
            conn.commit()
        except Exception as e:
            conn.rollback()
            erros.append(f"falha no INSERT (tabela inteira desfeita): {e}")
        cur.execute(f"SELECT COUNT(*) FROM {nome}")
        no_banco = cur.fetchone()[0]
        resumo.append((nome, len(df), no_banco))
        for erro in erros:
            print(f"  ERRO: {erro}")
        print(f"  planilha: {len(df)} | banco: {no_banco}\n")

    # PostgreSQL: alinha a sequência do identity com os ids importados, para que
    # novos fornecedores (ex.: criados pela trigger) não repitam um id existente.
    if TIPO == "postgres":
        cur.execute(
            "SELECT setval(pg_get_serial_sequence('public.fornecedor', 'idfornecedor'), "
            "COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1))"
        )
        conn.commit()

    cur.close()
    conn.close()

    print("=" * 56)
    print(f"{'Tabela':<22}{'Planilha':>10}{'Banco':>10}   Situação")
    divergiu = False
    for nome, planilha, banco in resumo:
        ok = planilha == banco
        divergiu = divergiu or not ok
        print(f"{nome:<22}{planilha:>10}{banco:>10}   {'OK' if ok else 'DIVERGENTE'}")
    print("=" * 56)
    if divergiu:
        print("Importação INCOMPLETA: há tabelas com linhas faltando.")
        sys.exit(1)
    print("Importação concluída: todas as linhas da planilha estão no banco.")


if __name__ == "__main__":
    main()
