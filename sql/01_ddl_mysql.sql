-- =====================================================================
-- DDL CORRIGIDO - MySQL (8.x)
-- Disciplina: Banco de Dados (ENGS242N01) - Integração de Dados
--
-- Mesmas correções do sql/01_ddl_postgres.sql (veja a lista no topo daquele
-- arquivo), mais as adaptações de sintaxe que o PostgreSQL aceita e o MySQL não:
--  - "public." (schema do PostgreSQL) não existe no MySQL;
--  - "::character varying" (cast do PostgreSQL) é erro de sintaxe no MySQL;
--  - GENERATED ... AS IDENTITY vira AUTO_INCREMENT;
--  - int8/float8 viram BIGINT/DECIMAL (int8 e float8 até existem como apelido, mas
--    float8 não serve para dinheiro).
-- Uso:  CREATE DATABASE loja CHARACTER SET utf8mb4;  USE loja;  e rode este arquivo.
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE fornecedor (
    idfornecedor  INT           NOT NULL AUTO_INCREMENT,
    razao_social  VARCHAR(255)  NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produtos_filial (
    filial_id       INT            NOT NULL,
    produto_id      VARCHAR(25)    NOT NULL,
    descricao       VARCHAR(255)   NOT NULL,
    estoque         DECIMAL(14, 4) NOT NULL DEFAULT 0,
    preco_unitario  DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_compra    DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12, 4) NOT NULL DEFAULT 0,
    idfornecedor    INT            NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor
        FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id          BIGINT         NOT NULL,
    data_pedido        DATE           NOT NULL,
    item               INT            NOT NULL,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    ordem_compra       BIGINT         NOT NULL DEFAULT 0,   -- 0 = pedido sem ordem de compra
    qtde_pedida        DECIMAL(14, 4) NOT NULL,
    filial_id          INT            NOT NULL,
    data_entrega       DATE           NULL,
    qtde_entregue      DECIMAL(14, 4) NOT NULL DEFAULT 0,
    qtde_pendente      DECIMAL(14, 4) GENERATED ALWAYS AS (qtde_pedida - qtde_entregue) STORED,
    preco_compra       DECIMAL(12, 4) NOT NULL DEFAULT 0,
    fornecedor_id      INT            NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_compra_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (idfornecedor),
    CONSTRAINT fk_pedido_compra_produto
        FOREIGN KEY (filial_id, produto_id) REFERENCES produtos_filial (filial_id, produto_id),
    INDEX idx_pedido_ordem (ordem_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada       DATE           NOT NULL,
    nro_nfe            VARCHAR(255)   NOT NULL,
    item               INT            NOT NULL,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    ordem_compra       BIGINT         NOT NULL,             -- coluna que faltava no DDL original
    qtde_recebida      DECIMAL(14, 4) NOT NULL,
    filial_id          INT            NOT NULL,
    custo_unitario     DECIMAL(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe),
    CONSTRAINT fk_entradas_produto
        FOREIGN KEY (filial_id, produto_id) REFERENCES produtos_filial (filial_id, produto_id),
    INDEX idx_entradas_ordem (ordem_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venda (
    venda_id        BIGINT         NOT NULL,
    data_emissao    DATE           NOT NULL,
    horariomov      TIME           NOT NULL DEFAULT '00:00:00',
    produto_id      VARCHAR(25)    NOT NULL,
    qtde_vendida    DECIMAL(14, 4) NOT NULL,
    valor_unitario  DECIMAL(12, 4) NOT NULL DEFAULT 0,
    filial_id       INT            NOT NULL DEFAULT 1,
    item            INT            NOT NULL DEFAULT 0,
    unidade_medida  VARCHAR(3)     NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX idx_venda_data (data_emissao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
