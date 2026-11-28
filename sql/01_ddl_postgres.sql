-- 01_ddl_postgres
-- DDL corrigido para PostgreSQL.
-- Não é necessário executar: este arquivo é a versão entregue da correção do DDL
-- do enunciado. A carga real foi feita no MySQL (sql/01_ddl_mysql.sql).

-- Correções aplicadas em relação ao DDL original:
--   * produtos_filial: "decricao" -> "descricao"; "idfonecedor" -> "idfornecedor";
--     a PK usava "idproduto", coluna inexistente -> PK (filial_id, produto_id).
--   * fornecedor: "idforncedor" -> "idfornecedor"; a PK usava "idproduto",
--     coluna inexistente -> PK apenas de idfornecedor.
--   * entradas_mercadoria: a PK referenciava "ordem_compra" sem a coluna existir
--     -> coluna ordem_compra adicionada.
--   * pedido_compra.fornecedor_id: int4 -> VARCHAR(25), pois os IDs são F1...F20.
--   * tipos do PostgreSQL mantidos/corrigidos: int8 -> BIGINT, int4 -> INTEGER,
--     float8 -> NUMERIC, "::character varying" -> VARCHAR.
--   * venda.horariomov: varchar(8) -> TIME.

DROP TABLE IF EXISTS public.entradas_mercadoria CASCADE;
DROP TABLE IF EXISTS public.pedido_compra CASCADE;
DROP TABLE IF EXISTS public.venda CASCADE;
DROP TABLE IF EXISTS public.produtos_filial CASCADE;
DROP TABLE IF EXISTS public.fornecedor CASCADE;

CREATE TABLE public.fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE public.produtos_filial (
    filial_id      INTEGER NOT NULL,
    produto_id     VARCHAR(25) NOT NULL,
    descricao      VARCHAR(255) NOT NULL,
    estoque        NUMERIC(14,3) NOT NULL DEFAULT 0,
    preco_unitario NUMERIC(12,4) NOT NULL DEFAULT 0,
    preco_compra   NUMERIC(12,4) NOT NULL DEFAULT 0,
    preco_venda    NUMERIC(12,4) NOT NULL DEFAULT 0,
    idfornecedor   VARCHAR(25),
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES public.fornecedor (idfornecedor)
);

CREATE TABLE public.venda (
    venda_id       BIGINT NOT NULL,
    data_emissao   DATE NOT NULL,
    horariomov     TIME NOT NULL DEFAULT '00:00:00',
    produto_id     VARCHAR(25) NOT NULL DEFAULT '',
    qtde_vendida   NUMERIC(14,3),
    valor_unitario NUMERIC(12,4) NOT NULL DEFAULT 0,
    filial_id      BIGINT NOT NULL DEFAULT 1,
    item           INTEGER NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3),
    CONSTRAINT pk_consumo PRIMARY KEY
        (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE public.pedido_compra (
    pedido_id         BIGINT NOT NULL DEFAULT 0,
    data_pedido       DATE,
    item              INTEGER NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    ordem_compra      BIGINT NOT NULL DEFAULT 0,
    qtde_pedida       NUMERIC(14,3),
    filial_id         INTEGER,
    data_entrega      DATE,
    qtde_entregue     NUMERIC(14,3) NOT NULL DEFAULT 0,
    qtde_pendente     NUMERIC(14,3) NOT NULL DEFAULT 0,
    preco_compra      NUMERIC(12,4) DEFAULT 0,
    fornecedor_id     VARCHAR(25) DEFAULT '0',
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE INDEX idx_pedido_ordem ON public.pedido_compra (ordem_compra);

CREATE TABLE public.entradas_mercadoria (
    ordem_compra      BIGINT NOT NULL DEFAULT 0,
    data_entrada      DATE,
    nro_nfe           VARCHAR(255) NOT NULL,
    item              INTEGER NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    qtde_recebida     NUMERIC(14,3),
    filial_id         INTEGER,
    custo_unitario    NUMERIC(12,4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey
        PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);
