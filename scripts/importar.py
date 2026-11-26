"""Carrega as cinco abas do Excel e registra o resultado de cada linha no PostgreSQL ou MySQL."""

import argparse
from collections import Counter
from contextlib import closing
from datetime import date, datetime, time, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import json
import os
from pathlib import Path
import re
import unicodedata

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from openpyxl.utils.datetime import from_excel


ARQUIVO = Path(__file__).resolve().parent.parent / "dados" / "base_teste.xlsx"

# A ordem mantém as referências para fornecedor disponíveis durante a carga.
TABELAS = {
    "fornecedor": (
        "idfornecedor codigo_origem razao_social",
        "idfornecedor",
    ),
    "produtos_filial": (
        "filial_id produto_id descricao estoque preco_unitario preco_compra preco_venda idfornecedor",
        "filial_id produto_id",
    ),
    "pedido_compra": (
        "pedido_id data_pedido item produto_id descricao_produto ordem_compra qtde_pedida "
        "filial_id data_entrega qtde_entregue qtde_pendente preco_compra fornecedor_id",
        "pedido_id produto_id item",
    ),
    "entradas_mercadoria": (
        "data_entrada nro_nfe item produto_id descricao_produto ordem_compra "
        "qtde_recebida filial_id custo_unitario",
        "ordem_compra item produto_id nro_nfe",
    ),
    "venda": (
        "venda_id data_emissao horariomov produto_id qtde_vendida valor_unitario "
        "filial_id item unidade_medida",
        "filial_id venda_id data_emissao produto_id item horariomov",
    ),
}

ALIASES = {
    "produto_id": ("idproduto", "id_produto"),
    "descricao": ("decricao", "descricao_produto"),
    "descricao_produto": ("descricao", "decricao"),
    "idfornecedor": ("idforncedor", "idfonecedor", "id_fornecedor", "fornecedor_id"),
    "fornecedor_id": ("idfornecedor", "idforncedor", "idfonecedor", "id_fornecedor"),
    "horariomov": ("horario_mov", "horario_movimento"),
    "ordem_compra": ("ordem_de_compra",),
    "nro_nfe": ("numero_nfe", "nr_nfe"),
}
INTEIROS = {"filial_id", "pedido_id", "ordem_compra", "item", "venda_id"}
DECIMAIS = {
    "estoque", "preco_unitario", "preco_compra", "preco_venda", "qtde_pedida",
    "qtde_entregue", "qtde_pendente", "qtde_recebida", "custo_unitario",
    "qtde_vendida", "valor_unitario",
}
OBRIGATORIOS = {
    "fornecedor": {"razao_social"},
    "produtos_filial": {"descricao"},
    "pedido_compra": {"ordem_compra"},
}
COLUNAS_DERIVADAS = {"fornecedor": {"codigo_origem"}, "pedido_compra": {"qtde_pendente"}}


def vazio(valor):
    return valor is None or isinstance(valor, str) and not valor.strip()


def cabecalho(valor):
    texto = unicodedata.normalize("NFKD", str(valor).strip().lower())
    sem_acentos = "".join(letra for letra in texto if not unicodedata.combining(letra))
    return re.sub(r"[^a-z0-9]+", "_", sem_acentos).strip("_")


def mapear_colunas(nomes, colunas, tabela):
    mapa = {}
    for coluna in colunas:
        nomes_possiveis = (coluna, *ALIASES.get(coluna, ()))
        posicoes = [
            i for i, nome in enumerate(nomes)
            if not vazio(nome) and cabecalho(nome) in nomes_possiveis
        ]
        if len(posicoes) > 1:
            raise ValueError(f"{tabela}: coluna ambígua: {coluna}")
        if posicoes:
            mapa[coluna] = posicoes[0]
        elif coluna not in COLUNAS_DERIVADAS.get(tabela, set()):
            raise ValueError(f"{tabela}: coluna ausente: {coluna}")
    return mapa


def numero(valor):
    texto = str(valor).strip().replace("\u00a0", "").replace(" ", "")
    if "," in texto:
        texto = texto.replace(".", "").replace(",", ".")
    try:
        decimal = Decimal(texto)
    except InvalidOperation as erro:
        raise ValueError(f"número inválido: {valor!r}") from erro
    if not decimal.is_finite():
        raise ValueError(f"número inválido: {valor!r}")
    return decimal


def data_excel(valor, epoca):
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, str):
        texto = valor.strip()
        try:
            return date.fromisoformat(texto)
        except ValueError:
            for formato in ("%d/%m/%Y", "%Y-%m-%d %H:%M:%S", "%d/%m/%Y %H:%M:%S"):
                try:
                    return datetime.strptime(texto, formato).date()
                except ValueError:
                    continue
    serial = numero(valor)
    if serial < 1:
        raise ValueError("data inválida")
    resultado = from_excel(float(serial), epoca)
    if not isinstance(resultado, datetime):
        raise ValueError("data inválida")
    return resultado.date()


def converter(coluna, valor, epoca):
    if vazio(valor):
        return None
    if coluna.startswith("data_"):
        return data_excel(valor, epoca)
    if coluna == "horariomov":
        if isinstance(valor, datetime):
            return valor.time()
        if isinstance(valor, time):
            return valor
        if isinstance(valor, str):
            texto = valor.strip()
            try:
                return time.fromisoformat(texto)
            except ValueError:
                if re.fullmatch(r"\d{1,2}:\d{2}(?::\d{2})?", texto):
                    hora, resto = texto.split(":", 1)
                    return time.fromisoformat(f"{hora.zfill(2)}:{resto}")
        fracao = numero(valor)
        if not 0 <= fracao < 1:
            raise ValueError("horário inválido")
        resultado = from_excel(float(fracao), epoca)
        if not isinstance(resultado, time):
            raise ValueError("horário inválido")
        return resultado
    if coluna in {"idfornecedor", "fornecedor_id"}:
        texto = str(valor).strip()
        inteiro = numero(texto[1:] if re.fullmatch(r"[Ff][0-9]+", texto) else texto)
        if inteiro <= 0 or inteiro != inteiro.to_integral_value():
            raise ValueError("código de fornecedor deve identificar um inteiro positivo")
        return int(inteiro)
    if coluna in INTEIROS:
        decimal = numero(valor)
        if decimal != decimal.to_integral_value():
            raise ValueError("identificador inteiro possui parte fracionária")
        return int(decimal)
    if coluna in DECIMAIS:
        return numero(valor)
    if coluna in {"produto_id", "nro_nfe"}:
        if isinstance(valor, bool):
            raise ValueError("identificador booleano")
        if isinstance(valor, (int, float)):
            decimal = numero(valor)
            if decimal != decimal.to_integral_value():
                raise ValueError("identificador possui parte fracionária")
            return str(int(decimal))
    return str(valor).strip()


def preparar_linha(tabela, colunas, chave, origem, epoca):
    valores = {}
    ocorrencias = []
    for coluna in colunas:
        try:
            valor = converter(coluna, origem.get(coluna), epoca)
            if coluna in DECIMAIS and valor is not None:
                escala = Decimal("0.000001") if coluna.startswith("qtde_") or coluna == "estoque" else Decimal("0.0001")
                try:
                    convertido = valor.quantize(escala, rounding=ROUND_HALF_UP)
                except InvalidOperation as erro:
                    raise ValueError("valor fora da precisão esperada") from erro
                margem = Decimal(10) ** (18 + escala.as_tuple().exponent)
                if abs(convertido) >= margem:
                    raise ValueError("valor fora da precisão esperada")
                if convertido != valor:
                    ocorrencias.append(f"{coluna}: arredondado para a precisão da coluna")
                valor = convertido
            valores[coluna] = valor
        except (ValueError, TypeError, OverflowError) as erro:
            raise ValueError(f"{coluna}: {erro}") from erro
    for coluna in sorted(set(chave) | OBRIGATORIOS.get(tabela, set())):
        if valores[coluna] is None:
            raise ValueError(f"{coluna}: valor obrigatório ausente")

    if tabela == "fornecedor":
        valores["codigo_origem"] = str(origem["idfornecedor"]).strip()
    if tabela == "pedido_compra":
        if valores["qtde_entregue"] is None:
            valores["qtde_entregue"] = Decimal(0)
            ocorrencias.append("qtde_entregue vazia: adotado zero; confirmar com o cliente")
        pedida = valores["qtde_pedida"]
        if pedida is not None:
            saldo = pedida - valores["qtde_entregue"]
            informado = valores["qtde_pendente"]
            if informado is not None and informado != saldo:
                ocorrencias.append("qtde_pendente original divergente: recalculada")
            valores["qtde_pendente"] = saldo
    return valores, ocorrencias


def importar_aba(cur, planilha, tabela, epoca, erros_de_linha, esquema):
    # Os identificadores SQL abaixo vêm exclusivamente do mapa TABELAS.
    colunas, chave = (grupo.split() for grupo in TABELAS[tabela])
    linhas = iter(planilha.values)
    cabecalhos = next(linhas, ())
    posicoes = mapear_colunas(cabecalhos, colunas, tabela)
    campos = ", ".join(colunas)
    marcadores = ", ".join(["%s"] * len(colunas))
    inserir = f"INSERT INTO {esquema}{tabela} ({campos}) VALUES ({marcadores})"
    condicoes = " AND ".join(f"{campo} = %s" for campo in chave)
    consultar = f"SELECT {campos} FROM {esquema}{tabela} WHERE {condicoes}"
    contagem = Counter()
    chaves_na_aba = set()
    for linha_excel, linha in enumerate(linhas, 2):
        if all(vazio(valor) for valor in linha):
            continue
        valores_origem = {coluna: linha[i] for coluna, i in posicoes.items()}
        original = {
            f"{get_column_letter(i + 1)}: {nome or 'sem cabeçalho'}": valor
            for i, (nome, valor) in enumerate(zip(cabecalhos, linha))
            if not vazio(valor)
        }
        deslocadas = [
            get_column_letter(i + 1)
            for i, (nome, valor) in enumerate(zip(cabecalhos, linha))
            if vazio(nome) and not vazio(valor)
        ]
        ocorrencias = []
        if deslocadas:
            ocorrencias.append("Células sem cabeçalho: " + ", ".join(deslocadas))
        cur.execute("SAVEPOINT linha_excel")
        try:
            valores, tratamentos = preparar_linha(tabela, colunas, chave, valores_origem, epoca)
            ocorrencias.extend(tratamentos)
            chave_linha = tuple(valores[campo] for campo in chave)
            parametros = tuple(valores[coluna] for coluna in colunas)
            cur.execute(consultar, chave_linha)
            atual = cur.fetchone()
            if atual is None:
                cur.execute(inserir, parametros)
                status = "inserida"
            else:
                armazenados = dict(zip(colunas, atual))
                horario = armazenados.get("horariomov")
                if isinstance(horario, timedelta):
                    armazenados["horariomov"] = (datetime(2000, 1, 1) + horario).time()
                if tuple(armazenados[coluna] for coluna in colunas) != parametros:
                    raise ValueError("chave repetida com conteúdo diferente do registro no banco")
                if chave_linha in chaves_na_aba:
                    ocorrencias.append("chave duplicada na planilha: mesmo conteúdo")
                status = "existente"
            chaves_na_aba.add(chave_linha)
        except (ValueError, *erros_de_linha) as erro:
            cur.execute("ROLLBACK TO SAVEPOINT linha_excel")
            ocorrencias.append(getattr(getattr(erro, "diag", None), "message_primary", None) or str(erro))
            status = "rejeitada"
        cur.execute("RELEASE SAVEPOINT linha_excel")
        cur.execute(
            f"INSERT INTO {esquema}importacao_linhas (aba, linha_excel, status, ocorrencias, dados_origem) "
            "VALUES (%s, %s, %s, %s, %s)",
            (tabela, linha_excel, status, json.dumps(ocorrencias, ensure_ascii=False),
             json.dumps(original, default=str, ensure_ascii=False)),
        )
        contagem[status] += 1
    return contagem


def conectar(sgbd):
    if sgbd == "postgres":
        import psycopg2

        conexao = psycopg2.connect("")
        return conexao, (psycopg2.DataError, psycopg2.IntegrityError), "public."

    import mysql.connector

    conexao = mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "localhost"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.environ["MYSQL_USER"],
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.environ["MYSQL_DATABASE"],
        autocommit=False,
    )
    return conexao, (mysql.connector.DataError, mysql.connector.IntegrityError), ""


def carregar(cur, livro, sgbd, erros_de_linha, esquema):
    if sgbd == "postgres":
        cur.execute("LOCK TABLE public.importacao_linhas IN SHARE ROW EXCLUSIVE MODE")
    else:
        cur.execute("SELECT GET_LOCK(CONCAT('importacao:', LEFT(DATABASE(), 53)), 30)")
        if cur.fetchone()[0] != 1:
            raise RuntimeError("não foi possível obter a trava de importação do MySQL")

    cur.execute(f"DELETE FROM {esquema}importacao_linhas")
    resumo = []
    for tabela in TABELAS:
        contagem = importar_aba(cur, livro[tabela], tabela, livro.epoch, erros_de_linha, esquema)
        cur.execute(f"SELECT COUNT(*) FROM {esquema}{tabela}")
        resumo.append((tabela, contagem, cur.fetchone()[0]))
    return resumo


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arquivo", type=Path, default=ARQUIVO)
    parser.add_argument("--sgbd", choices=("postgres", "mysql"), default="postgres")
    args = parser.parse_args()

    with closing(load_workbook(args.arquivo, read_only=True, data_only=True)) as livro:
        conexao, erros_de_linha, esquema = conectar(args.sgbd)
        with closing(conexao):
            try:
                with closing(conexao.cursor()) as cur:
                    resumo = carregar(cur, livro, args.sgbd, erros_de_linha, esquema)
                conexao.commit()
            except Exception:
                conexao.rollback()
                raise
    for tabela, contagem, total in resumo:
        print(f"{tabela}: planilha={sum(contagem.values())}, inseridas={contagem['inserida']}, "
              f"existentes={contagem['existente']}, rejeitadas={contagem['rejeitada']}, banco={total}")


if __name__ == "__main__":
    main()
