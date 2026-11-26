-- MySQL 8. Execute com a base de destino selecionada.

CREATE TABLE fornecedor (
    idfornecedor BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo_origem VARCHAR(25) UNIQUE,
    razao_social VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE produtos_filial (
    filial_id BIGINT NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DECIMAL(18, 6) DEFAULT 0,
    preco_unitario DECIMAL(18, 4) DEFAULT 0,
    preco_compra DECIMAL(18, 4) DEFAULT 0,
    preco_venda DECIMAL(18, 4) DEFAULT 0,
    idfornecedor BIGINT,
    PRIMARY KEY (filial_id, produto_id),
    FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE,
    item INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL,
    qtde_pedida DECIMAL(18, 6),
    filial_id BIGINT,
    data_entrega DATE,
    qtde_entregue DECIMAL(18, 6) DEFAULT 0 NOT NULL,
    qtde_pendente DECIMAL(18, 6),
    preco_compra DECIMAL(18, 4),
    fornecedor_id BIGINT,
    PRIMARY KEY (pedido_id, produto_id, item),
    FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL,
    qtde_recebida DECIMAL(18, 6),
    filial_id BIGINT,
    custo_unitario DECIMAL(18, 4),
    PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov TIME(6) NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    qtde_vendida DECIMAL(18, 6),
    valor_unitario DECIMAL(18, 4),
    filial_id BIGINT NOT NULL,
    item INTEGER NOT NULL,
    unidade_medida VARCHAR(3),
    PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE importacao_linhas (
    aba VARCHAR(30) NOT NULL,
    linha_excel INTEGER NOT NULL,
    status VARCHAR(10) NOT NULL CHECK (status IN ('inserida', 'existente', 'rejeitada')),
    ocorrencias JSON NOT NULL,
    dados_origem JSON NOT NULL,
    PRIMARY KEY (aba, linha_excel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
