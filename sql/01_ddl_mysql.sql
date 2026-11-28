-- DDL corrigido para MySQL / MariaDB
-- Equipe: CoreData (Ana Júlia Pantoja Chagas e Rafaela da Silva Tavares)

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE fornecedor (
    idfornecedor INT AUTO_INCREMENT PRIMARY KEY,
    codigo_origem VARCHAR(25) UNIQUE,
    razao_social VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE produtos_filial (
    filial_id INT NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DECIMAL(12, 3) NOT NULL DEFAULT 0,
    preco_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_compra DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_venda DECIMAL(12, 4) NOT NULL DEFAULT 0,
    idfornecedor INT NULL,
    PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT chk_prod_estoque CHECK (estoque >= 0),
    CONSTRAINT chk_prod_precos CHECK (preco_unitario >= 0 AND preco_compra >= 0 AND preco_venda >= 0),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB;

CREATE TABLE pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE NULL,
    item INT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_pedida DECIMAL(12, 3) NULL,
    filial_id INT NULL,
    data_entrega DATE NULL,
    qtde_entregue DECIMAL(12, 3) NOT NULL DEFAULT 0,
    qtde_pendente DECIMAL(12, 3) GENERATED ALWAYS AS (COALESCE(qtde_pedida, 0) - qtde_entregue) STORED,
    preco_compra DECIMAL(12, 4) NOT NULL DEFAULT 0,
    fornecedor_id INT NULL,
    PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT chk_ped_qtdes CHECK (qtde_pedida >= 0 AND qtde_entregue >= 0 AND preco_compra >= 0),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB;

CREATE TABLE entradas_mercadoria (
    data_entrada DATE NULL,
    nro_nfe VARCHAR(255) NOT NULL,
    item INT NOT NULL DEFAULT 0,
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    qtde_recebida DECIMAL(12, 3) NULL,
    filial_id INT NULL,
    custo_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,
    PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe),
    CONSTRAINT chk_ent_qtdes CHECK (qtde_recebida >= 0 AND custo_unitario >= 0)
) ENGINE=InnoDB;

CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov TIME NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL,
    qtde_vendida DECIMAL(12, 3) NOT NULL,
    valor_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,
    filial_id INT NOT NULL DEFAULT 1,
    item INT NOT NULL DEFAULT 1,
    unidade_medida VARCHAR(3) NULL,
    PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    CONSTRAINT chk_venda_qtdes CHECK (qtde_vendida > 0 AND valor_unitario >= 0)
) ENGINE=InnoDB;